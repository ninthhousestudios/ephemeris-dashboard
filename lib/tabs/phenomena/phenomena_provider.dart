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

/// Display format for Phenomena tab.
final phenomenaFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.decimal,
);

/// Result for a single body's phenomena calculation.
class PhenomenaResult {
  const PhenomenaResult({
    required this.body,
    required this.bodyName,
    required this.phaseAngle,
    required this.elongation,
    required this.apparentDiameter,
    required this.apparentMagnitude,
    required this.phase,
    this.errorMessage,
  });

  final int body;
  final String bodyName;
  final double phaseAngle;
  final double phase;
  final double elongation;
  final double apparentDiameter;
  final double apparentMagnitude;
  final String? errorMessage;
}

List<PhenomenaResult> computePhenomena({
  required Ephemeris eph,
  required double jdUt,
  required int iflag,
  required List<int> bodies,
  required String Function(int) getName,
}) {
  return bodies.map((body) {
    try {
      final r = eph.phenoUt(jdUt, body, iflag);
      return PhenomenaResult(
        body: body,
        bodyName: getName(body),
        phaseAngle: r.phaseAngle,
        phase: r.phase,
        elongation: r.elongation,
        apparentDiameter: r.apparentDiameter,
        apparentMagnitude: r.apparentMagnitude,
      );
    } on SweException catch (e) {
      return PhenomenaResult(
        body: body,
        bodyName: getName(body),
        phaseAngle: double.nan,
        phase: double.nan,
        elongation: double.nan,
        apparentDiameter: double.nan,
        apparentMagnitude: double.nan,
        errorMessage: describeBodyError(body, e.message),
      );
    }
  }).toList();
}

List<PhenomenaResult> Function(Ephemeris, Moment) _phenomenaCompute(Ref ref) {
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final bodies = ref.watch(
    bodySelectionProvider(BodySelection.phenomenaBodies),
  );

  return (eph, moment) => computePhenomena(
    eph: eph,
    jdUt: moment.ut,
    iflag: flags.iflag,
    bodies: bodies,
    getName: (body) => safeGetName(swe, body),
  );
}

final _phenomenaCalcProvider = Provider<CalcOutcome<List<PhenomenaResult>>>((
  ref,
) {
  return runTabCalc(ref, compute: _phenomenaCompute(ref));
});

final phenomenaResultsProvider = Provider<CalcOutcome<List<PhenomenaResult>>>((
  ref,
) {
  return ref.watch(_phenomenaCalcProvider);
});

final phenomenaSeriesProvider =
    Provider<List<(Moment, CalcOutcome<List<PhenomenaResult>>)>>((ref) {
      return seriesSteps(
        ref,
        AppTab.phenomena.name,
        compute: () => _phenomenaCompute(ref),
      );
    });

/// The Results as card sections — the one encoding of this tab's labels,
/// order and formatted values. The cards render these; [phenomenaToExportRows]
/// projects the same list, so a per-field NaN or a relabeling cannot land on
/// one side only (yojana swe-dashboard/91).
List<ResultSection> phenomenaSections(
  List<PhenomenaResult> results,
  DisplayFormat fmt,
) {
  return [
    for (final r in results)
      ResultSection(
        title: r.bodyName,
        subtitle: 'phenoUt(${r.body})',
        fields: r.errorMessage != null
            ? [
                ResultField(
                  label: 'Error',
                  value: r.errorMessage!,
                  rawValue: double.nan,
                ),
              ]
            : [
                ResultField(
                  label: 'Phase Angle',
                  value: formatAngle(r.phaseAngle, fmt),
                  rawValue: r.phaseAngle,
                ),
                ResultField(
                  label: 'Elongation',
                  value: formatAngle(r.elongation, fmt),
                  rawValue: r.elongation,
                ),
                ResultField(
                  label: 'App. Diameter',
                  value: formatAngle(r.apparentDiameter, fmt),
                  rawValue: r.apparentDiameter,
                ),
                ResultField(
                  label: 'Phase (Illum.)',
                  value: r.phase.isNaN ? 'n/a' : r.phase.toStringAsFixed(6),
                  rawValue: r.phase,
                ),
                ResultField(
                  label: 'App. Magnitude',
                  value: r.apparentMagnitude.isNaN
                      ? 'n/a'
                      : r.apparentMagnitude.toStringAsFixed(4),
                  rawValue: r.apparentMagnitude,
                ),
              ],
      ),
  ];
}

/// Convert phenomena results to export rows.
List<ExportRow> phenomenaToExportRows(
  List<PhenomenaResult> results,
  DisplayFormat fmt,
) => sectionsToExportRows(phenomenaSections(results, fmt));
