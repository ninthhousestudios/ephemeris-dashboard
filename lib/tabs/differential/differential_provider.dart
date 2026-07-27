// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';
import '../../core/body_selection.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_utils_provider.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/result_card.dart';
import '../../widgets/result_section.dart';

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
  final bodyA = ref.watch(singleBodyProvider(BodySelection.differentialBodyA));
  final bodyB = ref.watch(singleBodyProvider(BodySelection.differentialBodyB));

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
  // Series mode ignores the override JD — each step uses the series Moment.
  return seriesSteps(
    ref,
    AppTab.differential.name,
    compute: () => _diffCompute(ref),
  );
});

/// The Result as card sections — the one encoding of this tab's labels and
/// formatters. The card renders these; [diffToExportRows] projects the same
/// list, so a rename cannot land on one side only (yojana swe-dashboard/91).
List<ResultSection> diffSections(DiffResult result, DisplayFormat fmt) {
  return [
    ResultSection(
      title: '${result.nameA} — ${result.nameB}',
      subtitle: 'Differential',
      flagHex:
          '0x${result.returnFlagA.toRadixString(16).toUpperCase()} / '
          '0x${result.returnFlagB.toRadixString(16).toUpperCase()}',
      fields: [
        ResultField(
          label: 'Longitude ${result.nameA}',
          value: formatAngle(result.lonA, fmt),
          rawValue: result.lonA,
        ),
        ResultField(
          label: 'Longitude ${result.nameB}',
          value: formatAngle(result.lonB, fmt),
          rawValue: result.lonB,
        ),
        ResultField(
          label: 'Difference (short arc)',
          value: formatAngle(result.difference, fmt),
          rawValue: result.difference,
        ),
        ResultField(
          label: 'Complement (long arc)',
          value: formatAngle(result.complement, fmt),
          rawValue: result.complement,
        ),
        ResultField(
          label: 'Midpoint',
          value: formatAngle(result.midpoint, fmt),
          rawValue: result.midpoint,
        ),
      ],
    ),
  ];
}

/// Convert a DiffResult to export rows.
List<ExportRow> diffToExportRows(DiffResult result, DisplayFormat fmt) =>
    sectionsToExportRows(diffSections(result, fmt));
