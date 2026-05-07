import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../core/swe_service.dart';

/// Body A selection.
final diffBodyAProvider = StateProvider<int>((ref) => seSun);

/// Body B selection.
final diffBodyBProvider = StateProvider<int>((ref) => seMoon);

/// Display format for this tab.
final diffFormatProvider = StateProvider<DisplayFormat>((ref) => DisplayFormat.dms);

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

/// Computes the differential between Body A and Body B.
final diffResultProvider = Provider<DiffResult?>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('differential')) return null;

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  runner.setTabTag('differential');
  final swe = ref.read(sweProvider);
  final bodyA = ref.watch(diffBodyAProvider);
  final bodyB = ref.watch(diffBodyBProvider);
  final overrideJd = ref.watch(diffOverrideJdProvider);
  final jdUt = overrideJd ?? ectx.jdUt;

  final flags = ectx.iflag | seFlgSpeed;

  try {
    final rA = runner.run(globals, (eph) => eph.calcUt(jdUt, bodyA, flags));
    final rB = runner.run(globals, (eph) => eph.calcUt(jdUt, bodyB, flags));

    final lonA = rA.longitude;
    final lonB = rB.longitude;

    // Shorter arc: normalise A-B to 0–360, then fold > 180.
    var diff = swe.degnorm(lonA - lonB);
    if (diff > 180.0) diff = 360.0 - diff;

    final complement = 360.0 - diff;
    final midpoint = swe.degMidp(lonA, lonB);

    return DiffResult(
      nameA: swe.getPlanetName(bodyA),
      nameB: swe.getPlanetName(bodyB),
      lonA: lonA,
      lonB: lonB,
      difference: diff,
      complement: complement,
      midpoint: midpoint,
      returnFlagA: rA.returnFlag,
      returnFlagB: rB.returnFlag,
    );
  } on SweException {
    return null;
  }
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
