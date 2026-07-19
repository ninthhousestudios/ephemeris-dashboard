// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../context_state.dart';
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

/// Scan [dir] for Swiss Ephemeris + JPL files and return the resulting
/// [EphemerisScan]. Files smaller than 16 KB are flagged corrupt; the rest
/// trust filename-derived metadata.
Future<EphemerisScan> scanEphemerisDirectory(String dir) async {
  if (kIsWeb) {
    return _scanWebMemfs(dir);
  }
  final directory = Directory(dir);
  if (!directory.existsSync()) {
    return EphemerisScan(const [], DateTime.now(), dir);
  }

  final entries = <EpheFile>[];
  _scanOneDir(dir, '', directory, entries);

  for (final sub in directory.listSync()) {
    if (sub is! Directory) continue;
    final subName = p.basename(sub.path);
    if (!RegExp(r'^ast\d+$').hasMatch(subName)) continue;
    _scanOneDir(dir, subName, sub, entries);
  }
  return EphemerisScan(entries, DateTime.now(), dir);
}

EphemerisScan _scanWebMemfs(String dir) {
  final entries = <EpheFile>[];
  for (final name in webEpheFilenames) {
    final parsed = parseEpheFilename(name, 0);
    if (parsed == null) continue;
    entries.add(parsed.copyWith(status: EpheFileStatus.installed));
  }
  return EphemerisScan(entries, DateTime.now(), dir);
}

void _scanOneDir(
  String rootDir,
  String relSubdir,
  Directory directory,
  List<EpheFile> entries,
) {
  for (final entity in directory.listSync()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    final size = entity.lengthSync();

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

    if (parsed.family == BodyFamily.jpl) {
      entries.add(_enrichJplFromCatalog(parsedWithSubdir));
    } else {
      entries.add(_probeSeFile(rootDir, parsedWithSubdir));
    }
  }
}

/// SE1 files begin with the ASCII magic `SWISSEPH`.
const _se1Magic = [0x53, 0x57, 0x49, 0x53, 0x53, 0x45, 0x50, 0x48]; // SWISSEPH

EpheFile _probeSeFile(String rootDir, EpheFile parsed) {
  const minPlausibleBytes = 16 * 1024;
  if (parsed.sizeBytes > 0 && parsed.sizeBytes < minPlausibleBytes) {
    return parsed.copyWith(status: EpheFileStatus.corrupt);
  }
  if (parsed.filename.endsWith('.se1')) {
    final filePath = p.join(rootDir, parsed.relativePath);
    try {
      final file = File(filePath);
      final raf = file.openSync();
      try {
        final header = raf.readSync(8);
        if (header.length < 8 || !_matchesMagic(header)) {
          return parsed.copyWith(status: EpheFileStatus.corrupt);
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return parsed.copyWith(status: EpheFileStatus.corrupt);
    }
  }
  return parsed.copyWith(status: EpheFileStatus.installed);
}

bool _matchesMagic(List<int> header) {
  for (var i = 0; i < _se1Magic.length; i++) {
    if (header[i] != _se1Magic[i]) return false;
  }
  return true;
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
  final path = ref.watch(resolvedEphePathProvider);
  if (path == null) {
    return EphemerisScan(const [], DateTime.now(), '');
  }
  return scanEphemerisDirectory(path);
});

Set<EpheSource> availableEpheSources(EphemerisScan scan) {
  final sources = {EpheSource.moshier};
  final installed = scan.files.where(
    (f) => f.status == EpheFileStatus.installed,
  );
  if (installed.any(
    (f) => f.family == BodyFamily.planets || f.family == BodyFamily.moon,
  )) {
    sources.add(EpheSource.swissEph);
  }
  // JPL excluded on web (300 MB+, no upstream support).
  // On native, only expose JPL when a concrete .eph file is installed.
  if (!kIsWeb && installed.any((f) => f.family == BodyFamily.jpl)) {
    sources.add(EpheSource.jpl);
  }
  return sources;
}

final availableEpheSourcesProvider = Provider<Set<EpheSource>>((ref) {
  final scan = ref.watch(ephemerisScanProvider);
  return scan.when(
    data: availableEpheSources,
    loading: () => EpheSource.values.toSet(),
    error: (_, _) => {EpheSource.moshier},
  );
});
