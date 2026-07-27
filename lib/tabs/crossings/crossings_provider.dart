// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';
import '../../core/body_selection.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/jd_utils.dart';
import '../../core/output_clock.dart';
import '../../core/swe_utils_provider.dart';
import '../../core/swe_utils.dart';

enum CrossingType {
  sunCross('Sun crosses longitude'),
  moonCross('Moon crosses longitude'),
  moonNode('Moon node crossing'),
  helioCross('Heliocentric crossing');

  const CrossingType(this.label);
  final String label;
}

/// Which crossing type to compute.
final crossingTypeProvider = StateProvider<CrossingType>(
  (ref) => CrossingType.sunCross,
);

/// Target longitude in degrees (0–360).
final crossingLonProvider = StateProvider<double>((ref) => 0.0);

/// Direction: 1 = forward, -1 = backward (helioCross only).
final crossingDirProvider = StateProvider<int>((ref) => 1);

class CrossingResult {
  const CrossingResult({
    required this.crossingJd,
    required this.crossingDate,
    required this.crossingLongitude,
    required this.description,
  });

  /// Julian Day of the crossing.
  final double crossingJd;

  /// Human-readable date/time string.
  final String crossingDate;

  /// For moonNode: the longitude at which the crossing occurs; else null.
  final double? crossingLongitude;

  /// Short description of what was computed.
  final String description;
}

CrossingResult computeCrossing({
  required Ephemeris eph,
  required SweUtils swe,
  required double jdUt,
  required int iflag,
  required CrossingType type,
  required double longitude,
  required int helioBody,
  required int helioDir,
  required String helioBodyName,
  required ClockView view,
}) {
  if (type != CrossingType.helioCross &&
      iflag & (seFlgHelCtr | seFlgBaryCtr) != 0) {
    throw const InvalidArgException(
      'Crossings require geocentric or topocentric origin',
    );
  }

  switch (type) {
    case CrossingType.sunCross:
      final jd = eph.solCrossUt(longitude, jdUt, iflag);
      return CrossingResult(
        crossingJd: jd,
        crossingDate: formatJdDateTime(swe, jd, view: view),
        crossingLongitude: null,
        description: 'Sun crosses ${longitude.toStringAsFixed(4)}°',
      );

    case CrossingType.moonCross:
      final jd = eph.moonCrossUt(longitude, jdUt, iflag);
      return CrossingResult(
        crossingJd: jd,
        crossingDate: formatJdDateTime(swe, jd, view: view),
        crossingLongitude: null,
        description: 'Moon crosses ${longitude.toStringAsFixed(4)}°',
      );

    case CrossingType.moonNode:
      final r = eph.moonCrossNodeUt(jdUt, iflag);
      return CrossingResult(
        crossingJd: r.jdUt,
        crossingDate: formatJdDateTime(swe, r.jdUt, view: view),
        crossingLongitude: r.longitude,
        description: 'Moon crosses node',
      );

    case CrossingType.helioCross:
      final jd = eph.helioCrossUt(helioBody, longitude, jdUt, iflag, helioDir);
      return CrossingResult(
        crossingJd: jd,
        crossingDate: formatJdDateTime(swe, jd, view: view),
        crossingLongitude: null,
        description:
            '$helioBodyName helio crosses ${longitude.toStringAsFixed(4)}° '
            '(${helioDir == 1 ? 'forward' : 'backward'})',
      );
  }
}

final _crossingCalcProvider = Provider<CalcOutcome<CrossingResult>>((ref) {
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final view = ref.watch(clockViewProvider);
  final type = ref.watch(crossingTypeProvider);
  final lon = ref.watch(crossingLonProvider);
  final helioBody = ref.watch(
    singleBodyProvider(BodySelection.crossingsHelioBody),
  );
  final dir = ref.watch(crossingDirProvider);

  return runTabCalc(
    ref,
    compute: (eph, moment) => computeCrossing(
      eph: eph,
      jdUt: moment.ut,
      iflag: flags.iflag,
      type: type,
      longitude: lon,
      helioBody: helioBody,
      helioDir: dir,
      helioBodyName: safeGetName(swe, helioBody),
      swe: swe,
      view: view,
    ),
  );
});

final crossingResultProvider = Provider<CalcOutcome<CrossingResult>>((ref) {
  return ref.watch(_crossingCalcProvider);
});

List<ExportRow> crossingToExportRows(CrossingResult result) {
  return [
    ExportRow(
      header: result.description,
      fields: [
        (
          'JD (UT)',
          result.crossingJd.isNaN
              ? 'NaN'
              : result.crossingJd.toStringAsFixed(6),
        ),
        ('Date/Time', result.crossingDate),
        if (result.crossingLongitude != null)
          (
            'Node Longitude',
            '${result.crossingLongitude!.toStringAsFixed(6)}°',
          ),
      ],
    ),
  ];
}
