import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
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

/// Phenomena calculation results.
final phenomenaResultsProvider = Provider<List<PhenomenaResult>>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('phenomena')) return const [];

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  runner.setTabTag('phenomena');
  final swe = ref.read(sweProvider);
  final bodies = ref.watch(phenomenaBodiesProvider);

  final results = <PhenomenaResult>[];
  for (final body in bodies) {
    try {
      final r = runner.run(
        globals,
        (eph) => eph.phenoUt(ectx.jdUt, body, ectx.iflag),
      );
      results.add(
        PhenomenaResult(
          body: body,
          bodyName: _safeGetName(swe, body),
          phaseAngle: r.phaseAngle,
          phase: r.phase,
          elongation: r.elongation,
          apparentDiameter: r.apparentDiameter,
          apparentMagnitude: r.apparentMagnitude,
        ),
      );
    } on SweException {
      results.add(
        PhenomenaResult(
          body: body,
          bodyName: _safeGetName(swe, body),
          phaseAngle: double.nan,
          phase: double.nan,
          elongation: double.nan,
          apparentDiameter: double.nan,
          apparentMagnitude: double.nan,
        ),
      );
    }
  }

  return results;
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

String _safeGetName(SwissEph swe, int body) {
  try {
    return swe.getPlanetName(body);
  } catch (_) {
    return 'Body $body';
  }
}
