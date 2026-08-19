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
import '../../core/sign_names.dart';
import '../../core/swe_utils_provider.dart';
import '../../core/swe_utils.dart';
import '../../core/true_sidereal.dart';

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
    required this.jdFieldLabel,
    required this.jdFieldValue,
    required this.jdOnScale,
  });

  /// Canonical UT1 Julian Day of the crossing (NaN when no event was found).
  final double crossingJd;

  /// Human-readable date/time string, on the Context's Scale/Calendar/clock.
  final String crossingDate;

  /// For moonNode: the longitude at which the crossing occurs; else null.
  final double? crossingLongitude;

  /// Short description of what was computed.
  final String description;

  /// The bare-JD field's label (`JD UT1` / `JD TT`) and value, both on the
  /// Context's Scale so the number matches [crossingDate] beside it rather than
  /// sitting on UT1 while the date-time reads in TT. Built once here (the sole
  /// site with the Scale + engine) so the card and the export cannot drift.
  final String jdFieldLabel;
  final String jdFieldValue;

  /// The scale-shifted JD as a number, for a [ResultField.rawValue].
  final double? jdOnScale;
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

  CrossingResult build(
    double jd, {
    double? crossingLongitude,
    required String description,
  }) {
    final f = jdScaleField(swe, jd, scale: view.scale, digits: 6);
    return CrossingResult(
      crossingJd: jd,
      crossingDate: formatJdDateTime(swe, jd, view: view),
      crossingLongitude: crossingLongitude,
      description: description,
      jdFieldLabel: f.label,
      jdFieldValue: f.value,
      jdOnScale: f.onScale,
    );
  }

  switch (type) {
    case CrossingType.sunCross:
      return build(
        eph.solCrossUt(longitude, jdUt, iflag),
        description: 'Sun crosses ${longitude.toStringAsFixed(4)}°',
      );

    case CrossingType.moonCross:
      return build(
        eph.moonCrossUt(longitude, jdUt, iflag),
        description: 'Moon crosses ${longitude.toStringAsFixed(4)}°',
      );

    case CrossingType.moonNode:
      final r = eph.moonCrossNodeUt(jdUt, iflag);
      return build(
        r.jdUt,
        crossingLongitude: r.longitude,
        description: 'Moon crosses node',
      );

    case CrossingType.helioCross:
      return build(
        eph.helioCrossUt(helioBody, longitude, jdUt, iflag, helioDir),
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

List<ExportRow> crossingToExportRows(
  CrossingResult result, {
  SignScheme scheme = SignScheme.none,
  UserSignSet? signSet,
  TrueSiderealBinning? binning,
}) {
  final lon = result.crossingLongitude;
  // No display-format selector on this tab: longitude is fixed decimal degrees,
  // and the in-sign line matches ([DisplayFormat.decimal]).
  final signField = lon == null
      ? null
      : inSignField(lon, 0, scheme, signSet, DisplayFormat.decimal, binning);
  return [
    ExportRow(
      header: result.description,
      fields: [
        (result.jdFieldLabel, result.jdFieldValue),
        ('Date/Time', result.crossingDate),
        if (lon != null) ('Node Longitude', '${lon.toStringAsFixed(6)}°'),
        ?signField,
      ],
    ),
  ];
}
