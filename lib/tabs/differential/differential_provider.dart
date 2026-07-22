// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_service.dart';
import '../../layout/tab_definitions.dart';

/// Body A selection.
final diffBodyAProvider = StateProvider<int>((ref) => seSun);

/// Body B selection.
final diffBodyBProvider = StateProvider<int>((ref) => seMoon);

/// Display format for this tab.
final diffFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Optional override JD — when non-null, use this instead of the context bar JD.
final diffOverrideJdProvider = StateProvider<double?>((ref) => null);

/// Result of a differential calculation between two bodies.
class DiffResult {
  const DiffResult({
    required this.nameA,
    required this.nameB,
    required this.lonA,
    required this.lonB,
    required this.difference,
    required this.complement,
    required this.midpoint,
    required this.returnFlagA,
    required this.returnFlagB,
  });

  final String nameA;
  final String nameB;
  final double lonA;
  final double lonB;

  /// Shorter arc between the two longitudes (0–180°).
  final double difference;

  /// Longer arc = 360 - difference (180–360°).
  final double complement;

  /// Zodiacal midpoint via swe.degMidp.
  final double midpoint;

  final int returnFlagA;
  final int returnFlagB;
}

DiffResult computeDifferential({
  required Ephemeris eph,
  required double jdUt,
  required int iflag,
  required int bodyA,
  required int bodyB,
  required String nameA,
  required String nameB,
  required double Function(double) degnorm,
  required double Function(double, double) degMidp,
}) {
  final rA = eph.calcUt(jdUt, bodyA, iflag | seFlgSpeed);
  final rB = eph.calcUt(jdUt, bodyB, iflag | seFlgSpeed);

  final lonA = rA.longitude;
  final lonB = rB.longitude;

  var diff = degnorm(lonA - lonB);
  if (diff > 180.0) diff = 360.0 - diff;

  return DiffResult(
    nameA: nameA,
    nameB: nameB,
    lonA: lonA,
    lonB: lonB,
    difference: diff,
    complement: 360.0 - diff,
    midpoint: degMidp(lonA, lonB),
    returnFlagA: rA.returnFlag,
    returnFlagB: rB.returnFlag,
  );
}

DiffResult Function(Ephemeris, Moment) _diffCompute(
  Ref ref, {
  double? overrideJd,
}) {
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final bodyA = ref.watch(diffBodyAProvider);
  final bodyB = ref.watch(diffBodyBProvider);

  return (eph, moment) => computeDifferential(
    eph: eph,
    jdUt: overrideJd ?? moment.ut,
    iflag: flags.iflag,
    bodyA: bodyA,
    bodyB: bodyB,
    nameA: safeGetName(swe, bodyA),
    nameB: safeGetName(swe, bodyB),
    degnorm: swe.degnorm,
    degMidp: swe.degMidp,
  );
}

final _diffCalcProvider = Provider<CalcOutcome<DiffResult>>((ref) {
  final overrideJd = ref.watch(diffOverrideJdProvider);
  return runTabCalc(ref, compute: _diffCompute(ref, overrideJd: overrideJd));
});

final diffResultProvider = Provider<CalcOutcome<DiffResult>>((ref) {
  return ref.watch(_diffCalcProvider);
});

final diffSeriesProvider = Provider<List<(Moment, CalcOutcome<DiffResult>)>>((
  ref,
) {
  ref.watch(
    seriesSettingsProvider(
      AppTab.differential.name,
    ).select((s) => (s.enabled, s.stepValue, s.stepUnit, s.rowCount)),
  );
  final settings = ref.read(seriesSettingsProvider(AppTab.differential.name));
  if (!settings.enabled) return const [];

  // Series mode ignores the override JD — each step uses the series Moment.
  return runTabCalcSeries(ref, compute: _diffCompute(ref), settings: settings);
});

/// Convert a DiffResult to export rows.
List<ExportRow> diffToExportRows(DiffResult result, DisplayFormat fmt) {
  return [
    ExportRow(
      header: '${result.nameA} / ${result.nameB}',
      fields: [
        ('Longitude ${result.nameA}', formatAngle(result.lonA, fmt)),
        ('Longitude ${result.nameB}', formatAngle(result.lonB, fmt)),
        ('Difference (short arc)', formatAngle(result.difference, fmt)),
        ('Complement (long arc)', formatAngle(result.complement, fmt)),
        ('Midpoint', formatAngle(result.midpoint, fmt)),
      ],
    ),
  ];
}
