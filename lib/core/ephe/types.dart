const Object _sentinel = Object();

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
    this.ephemerisNumber,
    this.downloadProgress,
  });

  /// e.g. 'sepl_18.se1', 'de431.eph', 'sefstars.txt'.
  final String filename;
  final BodyFamily family;
  final double startJd;
  final double endJd;
  final int startYear; // proleptic Gregorian; negative = BCE
  final int endYear;
  final int? ephemerisNumber; // from getCurrentFileData; null until probed
  final int sizeBytes;
  final EpheFileStatus status;
  final double? downloadProgress; // 0.0–1.0 when status == downloading

  EpheFile copyWith({
    String? filename,
    BodyFamily? family,
    double? startJd,
    double? endJd,
    int? startYear,
    int? endYear,
    int? sizeBytes,
    EpheFileStatus? status,
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
      sizeBytes: sizeBytes ?? this.sizeBytes,
      status: status ?? this.status,
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
        sizeBytes,
        status,
        ephemerisNumber,
        downloadProgress,
      );
}
