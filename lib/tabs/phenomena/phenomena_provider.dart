import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/ephemeris/trace_model.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_service.dart';

/// Selected bodies for phenomena calculation.
final phenomenaBodiesProvider = StateProvider<List<int>>(
  (ref) => [seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn],
);

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
  });

  final int body;
  final String bodyName;
  final double phaseAngle;
  final double phase;
  final double elongation;
  final double apparentDiameter;
  final double apparentMagnitude;
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
    } on SweException {
      return PhenomenaResult(
        body: body,
        bodyName: getName(body),
        phaseAngle: double.nan,
        phase: double.nan,
        elongation: double.nan,
        apparentDiameter: double.nan,
        apparentMagnitude: double.nan,
      );
    }
  }).toList();
}

final _phenomenaCalcProvider =
    Provider<({CalcOutcome<List<PhenomenaResult>> outcome, CallTrace trace})>((
      ref,
    ) {
      final ctx = ref.watch(contextBarProvider);
      final flags = ref.watch(flagBarProvider);
      final swe = ref.read(sweProvider);
      final bodies = ref.watch(phenomenaBodiesProvider);

      return runTabCalc(
        ref,
        tabTag: 'phenomena',
        compute: (eph) => computePhenomena(
          eph: eph,
          jdUt: ctx.jdUt,
          iflag: flags.iflag,
          bodies: bodies,
          getName: (body) => safeGetName(swe, body),
        ),
      );
    });

final phenomenaResultsProvider = Provider<CalcOutcome<List<PhenomenaResult>>>((
  ref,
) {
  return ref.watch(_phenomenaCalcProvider.select((c) => c.outcome));
});

final phenomenaTraceProvider = Provider<CallTrace>((ref) {
  return ref.watch(_phenomenaCalcProvider.select((c) => c.trace));
});

/// Convert phenomena results to export rows.
List<ExportRow> phenomenaToExportRows(
  List<PhenomenaResult> results,
  DisplayFormat fmt,
) {
  return results
      .map(
        (r) => ExportRow(
          header: r.bodyName,
          fields: [
            ('Phase Angle', formatAngle(r.phaseAngle, fmt)),
            ('Phase (Illum.)', r.phase.toStringAsFixed(6)),
            ('Elongation', formatAngle(r.elongation, fmt)),
            ('App. Diameter', formatAngle(r.apparentDiameter, fmt)),
            ('App. Magnitude', r.apparentMagnitude.toStringAsFixed(4)),
          ],
        ),
      )
      .toList();
}
