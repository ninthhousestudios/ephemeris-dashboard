import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../swe_service.dart';
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
  for (final entity in directory.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    final size = entity.lengthSync();
    if (!_looksLikeEpheFile(name)) continue;

    final parsed = parseEpheFilename(name, size);
    if (parsed == null) continue;

    if (parsed.family == BodyFamily.planets ||
        parsed.family == BodyFamily.moon ||
        parsed.family == BodyFamily.mainAsteroids) {
      entries.add(_probeSeFile(swe, dir, parsed));
    } else {
      entries.add(parsed);
    }
  }
  return EphemerisScan(entries, DateTime.now(), dir);
}

/// Fill [ephemerisNumber] and verify on-disk range matches filename range.
/// Returns a [EpheFile] with status set to either installed or corrupt.
EpheFile _probeSeFile(SwissEph swe, String dir, EpheFile parsed) {
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
    final probeJd = parsed.startJd + 100.0;
    swe.calcUt(probeJd, body, 2); // SEFLG_SWIEPH
  } catch (_) {
    // Non-fatal — probe may throw for benign reasons (edge-of-range, flag
    // fallback message). Fall through to getCurrentFileData; trust that.
  }
  try {
    final fd = swe.getCurrentFileData(fileNum);
    // A file is really loaded only if getCurrentFileData returns a path
    // AND a plausible start date. Trust file metadata over the filename.
    if (fd.path == null || fd.startDate <= 0) {
      return parsed.copyWith(status: EpheFileStatus.corrupt);
    }
    return parsed.copyWith(
      startJd: fd.startDate,
      endJd: fd.endDate,
      ephemerisNumber: fd.ephemerisNumber,
      status: EpheFileStatus.installed,
    );
  } catch (_) {
    return parsed.copyWith(status: EpheFileStatus.corrupt);
  }
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
