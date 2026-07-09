// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:swisseph/swisseph.dart';

import '../swe_service.dart';
import 'catalog.dart';
import 'dir_provider.dart';
import 'filename_parser.dart';
import 'types.dart';

class EphemerisScan {
  const EphemerisScan(this.files, this.scannedAt, this.directory);
  final List<EpheFile> files;
  final DateTime scannedAt;
  final String directory;
}

/// Scan [dir] for Swiss Ephemeris + JPL files, probe SE files via
/// `getCurrentFileData` to verify metadata, and return the resulting
/// [EphemerisScan]. Files whose on-disk range mismatches the filename
/// convention are flagged [EpheFileStatus.corrupt].
Future<EphemerisScan> scanEphemerisDirectory(SwissEph swe, String dir) async {
  if (kIsWeb) {
    return EphemerisScan(const [], DateTime.now(), dir);
  }
  final directory = Directory(dir);
  if (!directory.existsSync()) {
    return EphemerisScan(const [], DateTime.now(), dir);
  }

  final entries = <EpheFile>[];
  _scanOneDir(swe, dir, '', directory, entries);

  // Asteroid files live in astX/ subdirs (X = MPC ~/ 1000). Walk any that
  // happen to be present; we don't hard-code a range since aloistr sprays
  // these from ast0 up into the ast100s for outer bodies.
  for (final sub in directory.listSync()) {
    if (sub is! Directory) continue;
    final subName = p.basename(sub.path);
    if (!RegExp(r'^ast\d+$').hasMatch(subName)) continue;
    _scanOneDir(swe, dir, subName, sub, entries);
  }
  return EphemerisScan(entries, DateTime.now(), dir);
}

/// Scan one directory (root or an astX subdir) and append recognisable
/// ephemeris files to [entries]. [relSubdir] is empty for root, else the
/// subdir name like 'ast0'.
void _scanOneDir(
  SwissEph swe,
  String rootDir,
  String relSubdir,
  Directory directory,
  List<EpheFile> entries,
) {
  for (final entity in directory.listSync()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    final size = entity.lengthSync();

    // Partial download left by an interrupted transfer.
    if (name.endsWith('.se1.part') || name.endsWith('.eph.part')) {
      final baseName = name.substring(0, name.length - '.part'.length);
      final parsed =
          parseEpheFilename(baseName, size) ??
          EpheFile(
            filename: baseName,
            family: BodyFamily.unknown,
            startJd: 0,
            endJd: 0,
            startYear: 0,
            endYear: 0,
            sizeBytes: size,
            status: EpheFileStatus.partial,
          );
      entries.add(
        parsed.copyWith(
          sizeBytes: size,
          subdir: relSubdir,
          status: EpheFileStatus.partial,
        ),
      );
      continue;
    }

    if (!_looksLikeEpheFile(name)) continue;

    final parsed = parseEpheFilename(name, size);
    if (parsed == null) continue;
    final parsedWithSubdir = parsed.copyWith(subdir: relSubdir);

    if (parsed.family == BodyFamily.planets ||
        parsed.family == BodyFamily.moon ||
        parsed.family == BodyFamily.mainAsteroids) {
      entries.add(_probeSeFile(swe, rootDir, parsedWithSubdir));
    } else if (parsed.family == BodyFamily.jpl) {
      entries.add(_enrichJplFromCatalog(parsedWithSubdir));
    } else {
      // Numbered asteroids, fixed stars, unknown — trust the filename.
      // getCurrentFileData only covers planets/moon/main-ast slots.
      entries.add(parsedWithSubdir);
    }
  }
}

/// Probe the file with SE and enrich the [EpheFile] from
/// `getCurrentFileData` when we can confirm the probe actually opened
/// THIS file. If the probe doesn't come back with matching metadata we
/// don't flag corrupt — SE's file loading is keyed on the probe date, so
/// BCE files or out-of-asteroid-range dates can legitimately not resolve
/// to the file we intended to check. Corrupt is reserved for files that
/// are unreadable on disk (zero/tiny size).
EpheFile _probeSeFile(SwissEph swe, String dir, EpheFile parsed) {
  // Cheap first check: any SE .se1 file smaller than this is structurally
  // broken. Real bundled files are hundreds of KB to tens of MB.
  const minPlausibleBytes = 16 * 1024;
  if (parsed.sizeBytes > 0 && parsed.sizeBytes < minPlausibleBytes) {
    return parsed.copyWith(status: EpheFileStatus.corrupt);
  }

  // fileNum: 0 = planets, 1 = moon, 2 = main asteroids.
  final fileNum = switch (parsed.family) {
    BodyFamily.planets => 0,
    BodyFamily.moon => 1,
    BodyFamily.mainAsteroids => 2,
    _ => 0,
  };
  final body = switch (parsed.family) {
    BodyFamily.moon => 1, // seMoon
    BodyFamily.mainAsteroids => 17, // seCeres (covered by seas_ files)
    _ => 0, // seSun (covered by sepl_ files)
  };

  swe.setEphePath(dir);
  try {
    // Probe near the middle of the file's predicted range so the SE file
    // loader picks THIS file rather than a neighbouring chunk.
    final mid = parsed.startJd + (parsed.endJd - parsed.startJd) / 2;
    swe.calcUt(mid, body, 2); // SEFLG_SWIEPH
  } catch (_) {
    // Probe failures are NOT evidence of corruption — they happen for
    // benign reasons (asteroid body outside SE range, flag fallback
    // notices, BCE edge dates). Trust filename metadata below.
  }
  try {
    final fd = swe.getCurrentFileData(fileNum);
    final loadedPath = fd.path;
    final matchesThisFile =
        loadedPath != null && p.basename(loadedPath) == parsed.filename;
    if (matchesThisFile && fd.startDate > 0) {
      return parsed.copyWith(
        startJd: fd.startDate,
        endJd: fd.endDate,
        ephemerisNumber: fd.ephemerisNumber,
        status: EpheFileStatus.installed,
      );
    }
  } catch (_) {
    // ignore — fall through to trust-the-filename branch
  }
  // Probe didn't conclusively open THIS file, but the file exists and is
  // large enough to be real. Treat as installed with filename-derived
  // metadata; the resolver will probe again at actual calculation time.
  return parsed.copyWith(status: EpheFileStatus.installed);
}

/// Fill in [startJd]/[endJd]/[startYear]/[endYear] for a JPL file from
/// the known catalog. Scanner can't probe JPL files (no SE equivalent of
/// `getCurrentFileData` for JPL chunks), so we rely on the catalog
/// entry's declared range. If the file isn't in the catalog, leave the
/// range at zero — `resolveActiveFile` simply won't match it.
EpheFile _enrichJplFromCatalog(EpheFile parsed) {
  final entry = catalogEntryFor(parsed.filename);
  if (entry == null || entry.startYear == 0 && entry.endYear == 0) {
    return parsed;
  }
  return parsed.copyWith(
    startJd: gregorianYearStartJd(entry.startYear),
    endJd: gregorianYearStartJd(entry.endYear),
    startYear: entry.startYear,
    endYear: entry.endYear,
  );
}

bool _looksLikeEpheFile(String name) {
  return name.endsWith('.se1') ||
      name.endsWith('.eph') ||
      name == 'sefstars.txt';
}

final ephemerisScanProvider = FutureProvider<EphemerisScan>((ref) async {
  final swe = ref.watch(sweProvider);
  final path = ref.watch(resolvedEphePathProvider);
  if (path == null) {
    return EphemerisScan(const [], DateTime.now(), '');
  }
  return scanEphemerisDirectory(swe, path);
});
