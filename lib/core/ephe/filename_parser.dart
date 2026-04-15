import 'types.dart';

/// Parse a Swiss Ephemeris filename into an [EpheFile] (with status
/// defaulting to [EpheFileStatus.installed]). Returns `unknown`-family
/// entry for files that don't match any recognized pattern.
///
/// Recognized:
///   * `sepl_NN.se1`  — planets, AD chunk [NN*100, NN*100 + 600)
///   * `seplmNN.se1`  — planets, BCE chunk [-(NN*100 - 1), -(NN*100 - 1) + 599]
///   * `semo_NN.se1` / `semomNN.se1` — moon (same numbering as planets)
///   * `seas_NN.se1` / `seasmNN.se1` — main asteroids
///   * `deNNN.eph`, `deNNNe.eph`, `deNNNt.eph` — JPL DE files
///     (date range left at 0/0 here; filled from catalog by scanner)
///   * `sefstars.txt` — fixed-star catalog (no range)
EpheFile? parseEpheFilename(String filename, int sizeBytes) {
  // Fixed stars catalog.
  if (filename == 'sefstars.txt') {
    return EpheFile(
      filename: filename,
      family: BodyFamily.fixedStars,
      startJd: 0,
      endJd: 0,
      startYear: 0,
      endYear: 0,
      sizeBytes: sizeBytes,
      status: EpheFileStatus.installed,
    );
  }

  // JPL DE files: de<digits>[letter]*.eph
  final jplMatch = RegExp(r'^de(\d+)[a-z]*\.eph$').firstMatch(filename);
  if (jplMatch != null) {
    return EpheFile(
      filename: filename,
      family: BodyFamily.jpl,
      startJd: 0,
      endJd: 0,
      startYear: 0,
      endYear: 0,
      sizeBytes: sizeBytes,
      status: EpheFileStatus.installed,
    );
  }

  // SE files: (sepl|semo|seas)(_|m)NN.se1 — NN is 2 or 3 digits (step-of-6
  // chunks from aloistr/swisseph/ephe: …,_48,_54,…,_96,_102,_108,…).
  final seMatch = RegExp(r'^(sepl|semo|seas)(_|m)(\d{2,3})\.se1$').firstMatch(filename);
  if (seMatch != null) {
    final prefix = seMatch.group(1)!;
    final bceMarker = seMatch.group(2)!; // '_' = AD, 'm' = BCE
    final nn = int.parse(seMatch.group(3)!);

    // The BCE offset math -(nn*100 - 1) is only verified for 2-digit nn in
    // aloistr/swisseph. A 3-digit BCE chunk is a filename we've never seen
    // — punt to `unknown` rather than emit a fabricated range.
    if (bceMarker == 'm' && nn >= 100) {
      return EpheFile(
        filename: filename,
        family: BodyFamily.unknown,
        startJd: 0,
        endJd: 0,
        startYear: 0,
        endYear: 0,
        sizeBytes: sizeBytes,
        status: EpheFileStatus.installed,
      );
    }

    final family = switch (prefix) {
      'sepl' => BodyFamily.planets,
      'semo' => BodyFamily.moon,
      'seas' => BodyFamily.mainAsteroids,
      _ => BodyFamily.unknown,
    };

    final (int startYear, int endYear) = bceMarker == '_'
        ? (nn * 100, nn * 100 + 600)
        : (-(nn * 100 - 1), -(nn * 100 - 1) + 599);

    final startJd = gregorianYearStartJd(startYear);
    final endJd = gregorianYearStartJd(endYear);

    return EpheFile(
      filename: filename,
      family: family,
      startJd: startJd,
      endJd: endJd,
      startYear: startYear,
      endYear: endYear,
      sizeBytes: sizeBytes,
      status: EpheFileStatus.installed,
    );
  }

  return EpheFile(
    filename: filename,
    family: BodyFamily.unknown,
    startJd: 0,
    endJd: 0,
    startYear: 0,
    endYear: 0,
    sizeBytes: sizeBytes,
    status: EpheFileStatus.installed,
  );
}

/// Julian Day (UT midnight) at January 1 of the given proleptic Gregorian
/// year. Uses astronomical year numbering (year 0 = 1 BCE, year -1 = 2 BCE).
///
/// Pure-Dart formula so the parser stays FFI-free for unit testing.
double gregorianYearStartJd(int year) {
  const month = 1;
  const day = 1;
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  // Fliegel–Van Flandern Gregorian JD (noon TT).
  final jdn = day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;
  // Midnight UT = JD noon - 0.5.
  return jdn - 0.5;
}
