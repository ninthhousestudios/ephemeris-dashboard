// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

const Object _sentinel = Object();

/// Whether [name] is a file this app treats as ephemeris data — Swiss
/// Ephemeris chunks, JPL binaries, or the fixed-star catalogue.
///
/// Shared by the directory scanner and the managed-directory seeder so the
/// two cannot drift on what counts as an ephemeris file.
bool isEpheArtifact(String name) =>
    name.endsWith('.se1') || name.endsWith('.eph') || name == 'sefstars.txt';

/// Types for the ephemeris file manager.
///
/// BCE year convention: we use the astronomical proleptic Gregorian
/// calendar where year 0 = 1 BCE, year -1 = 2 BCE, etc. Parser emits
/// startYear/endYear on this scale. For Swiss Ephemeris BCE chunks
/// named `seplmNN.se1`, NN counts 100-year offsets behind year 1 CE:
///   seplm06 → [-599, 0)   (i.e. 600 BCE through 1 BCE)
///   seplm12 → [-1199, -600)
///   … and so on in 600-year steps.
/// The filename-derived range is verified against `getCurrentFileData`
/// during a scan (B4); a mismatch marks the file `corrupt`.
enum BodyFamily {
  planets,
  moon,
  mainAsteroids,

  /// Per-asteroid files (`seNNNNs.se1`) in `astX/` subdirs (X = mpc ~/ 1000).
  numberedAsteroid,

  /// Planetary moon / COB files (`sepm9NNN.se1`) in the `sat/` subdir.
  satellite,
  fixedStars,
  jpl,
  unknown,
}

enum EpheFileStatus {
  installed,
  missing,
  corrupt,
  downloading,
  // Orphan .part file on disk — a prior download was interrupted. The
  // manager offers Resume (HTTP Range) or Delete.
  partial,
}

class EpheFile {
  const EpheFile({
    required this.filename,
    required this.family,
    required this.startJd,
    required this.endJd,
    required this.startYear,
    required this.endYear,
    required this.sizeBytes,
    required this.status,
    this.subdir = '',
    this.mpcNumber,
    this.ephemerisNumber,
    this.downloadProgress,
  });

  /// e.g. 'sepl_18.se1', 'de431.eph', 'sefstars.txt', 'se00433s.se1'.
  final String filename;
  final BodyFamily family;
  final double startJd;
  final double endJd;
  final int startYear; // proleptic Gregorian; negative = BCE
  final int endYear;

  /// Subdirectory relative to the ephe root (e.g. 'ast0'). Empty string
  /// means the file lives directly in the ephe root. Scanner and
  /// downloader both honor this for path-joining.
  final String subdir;

  /// For [BodyFamily.numberedAsteroid], the MPC number (e.g. 433 = Eros).
  final int? mpcNumber;
  final int? ephemerisNumber; // from getCurrentFileData; null until probed
  final int sizeBytes;
  final EpheFileStatus status;
  final double? downloadProgress; // 0.0–1.0 when status == downloading

  /// Path relative to the ephe root, joining [subdir] + [filename].
  String get relativePath => subdir.isEmpty ? filename : '$subdir/$filename';

  EpheFile copyWith({
    String? filename,
    BodyFamily? family,
    double? startJd,
    double? endJd,
    int? startYear,
    int? endYear,
    String? subdir,
    int? sizeBytes,
    EpheFileStatus? status,
    Object? mpcNumber = _sentinel,
    Object? ephemerisNumber = _sentinel,
    Object? downloadProgress = _sentinel,
  }) {
    return EpheFile(
      filename: filename ?? this.filename,
      family: family ?? this.family,
      startJd: startJd ?? this.startJd,
      endJd: endJd ?? this.endJd,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
      subdir: subdir ?? this.subdir,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      status: status ?? this.status,
      mpcNumber: identical(mpcNumber, _sentinel)
          ? this.mpcNumber
          : mpcNumber as int?,
      ephemerisNumber: identical(ephemerisNumber, _sentinel)
          ? this.ephemerisNumber
          : ephemerisNumber as int?,
      downloadProgress: identical(downloadProgress, _sentinel)
          ? this.downloadProgress
          : downloadProgress as double?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpheFile &&
          filename == other.filename &&
          family == other.family &&
          startJd == other.startJd &&
          endJd == other.endJd &&
          startYear == other.startYear &&
          endYear == other.endYear &&
          subdir == other.subdir &&
          mpcNumber == other.mpcNumber &&
          sizeBytes == other.sizeBytes &&
          status == other.status &&
          ephemerisNumber == other.ephemerisNumber &&
          downloadProgress == other.downloadProgress;

  @override
  int get hashCode => Object.hash(
    filename,
    family,
    startJd,
    endJd,
    startYear,
    endYear,
    subdir,
    mpcNumber,
    sizeBytes,
    status,
    ephemerisNumber,
    downloadProgress,
  );
}
