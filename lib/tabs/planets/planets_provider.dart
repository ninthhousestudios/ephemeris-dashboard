import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/context_state.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/export_service.dart';
import '../../core/swe_service.dart';

/// Result for a single planet calculation.
class PlanetResult {
  const PlanetResult({
    required this.body,
    required this.bodyName,
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.speedLon,
    required this.speedLat,
    required this.speedDist,
    required this.returnFlag,
    this.errorMessage,
  });

  final int body;
  final String bodyName;
  final double longitude;
  final double latitude;
  final double distance;
  final double speedLon;
  final double speedLat;
  final double speedDist;
  final int returnFlag;
  /// When non-null, the SE call failed for this body. UI shows this in
  /// place of the numeric fields (typically a missing-ephemeris-file
  /// message with a pointer to the Ephemeris tab).
  final String? errorMessage;
}

/// Body presets for quick selection.
class BodyPreset {
  const BodyPreset(this.label, this.bodies);
  final String label;
  final List<int> bodies;
}

// ── Default bodies (always visible) ──

/// Classical 7 + outers + nodes + Lilith variants.
final defaultBodies = [
  seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn,
  seUranus, seNeptune, sePluto,
  seMeanNode, seTrueNode, seMeanApog, seOscuApog,
];

/// Presets for quick selection from the default set.
final bodyPresets = [
  BodyPreset('Classical', [seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn]),
  BodyPreset('Full', defaultBodies),
  BodyPreset('Outers', [seUranus, seNeptune, sePluto]),
  BodyPreset('Nodes', [seMeanNode, seTrueNode, seMeanApog, seOscuApog]),
];

// ── Extra bodies (progressive disclosure, second row) ──

/// Chiron, Pholus, main-belt asteroids, Earth, interpolated apogee/perigee.
final extraBodies = [
  seChiron, sePholus, seCeres, sePallas, seJuno, seVesta,
  seEarth, seIntpApog, seIntpPerg,
];

/// Uranian / Hamburg School fictitious bodies.
final uranianBodies = [
  seCupido, seHades, seZeus, seKronos,
  seApollon, seAdmetos, seVulkanus, sePoseidon,
];

// ── Asteroid access (third level) ──

/// Offset for numbered asteroids: body ID = seAstOffset + MPC number.
const int asteroidOffset = seAstOffset; // 10000

/// Common named asteroids by MPC number.
final namedAsteroids = <int, String>{
  1: 'Ceres',       // also seCeres (17), but MPC route works too
  2: 'Pallas',
  3: 'Juno',
  4: 'Vesta',
  5: 'Astraea',
  6: 'Hebe',
  7: 'Iris',
  8: 'Flora',
  9: 'Metis',
  10: 'Hygiea',
  16: 'Psyche',
  433: 'Eros',
  1221: 'Amor',
  2060: 'Chiron',    // also seChiron (15)
  5145: 'Pholus',    // also sePholus (16)
  7066: 'Nessus',
  136199: 'Eris',
  136472: 'Makemake',
  136108: 'Haumea',
  225088: 'Gonggong',
  50000: 'Quaoar',
  90377: 'Sedna',
  90482: 'Orcus',
};

/// Currently selected bodies.
final selectedBodiesProvider = StateProvider<List<int>>(
  (ref) => [seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn],
);

/// Planets calculation results.
final planetsResultsProvider = Provider<List<PlanetResult>>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('planets')) return const [];

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  runner.setTabTag('planets');
  final swe = ref.read(sweProvider);
  var bodies = ref.watch(selectedBodiesProvider);

  // Auto-add Earth for heliocentric/barycentric calculations.
  if ((ectx.origin == Origin.heliocentric ||
          ectx.origin == Origin.barycentric) &&
      !bodies.contains(seEarth)) {
    bodies = [...bodies, seEarth];
  }

  final results = <PlanetResult>[];
  for (final body in bodies) {
    try {
      final flags = ectx.iflag | seFlgSpeed;
      final r = runner.run(
        globals,
        (eph) => eph.calcUt(ectx.jdUt, body, flags),
      );
      results.add(PlanetResult(
        body: body,
        bodyName: swe.getPlanetName(body),
        longitude: r.longitude,
        latitude: r.latitude,
        distance: r.distance,
        speedLon: r.longitudeSpeed,
        speedLat: r.latitudeSpeed,
        speedDist: r.distanceSpeed,
        returnFlag: r.returnFlag,
      ));
    } on SweException catch (e) {
      results.add(PlanetResult(
        body: body,
        bodyName: _safeGetName(swe, body),
        longitude: double.nan,
        latitude: double.nan,
        distance: double.nan,
        speedLon: double.nan,
        speedLat: double.nan,
        speedDist: double.nan,
        returnFlag: -1,
        errorMessage: _describeBodyError(body, e.message),
      ));
    }
  }

  return results;
});

/// Convert planet results to export rows.
List<ExportRow> planetsToExportRows(List<PlanetResult> results, DisplayFormat fmt) {
  return results.map((r) => ExportRow(
    header: r.bodyName,
    fields: [
      ('Longitude', formatAngle(r.longitude, fmt)),
      ('Latitude', formatAngle(r.latitude, fmt)),
      ('Distance', formatDistance(r.distance, fmt)),
      ('Spd Lon', formatSpeed(r.speedLon, fmt)),
      ('Spd Lat', formatSpeed(r.speedLat, fmt)),
      ('Spd Dist', formatSpeed(r.speedDist, fmt)),
    ],
  )).toList();
}

String _safeGetName(SwissEph swe, int body) {
  try {
    return swe.getPlanetName(body);
  } catch (_) {
    return 'Body $body';
  }
}

/// Turn a raw SE error into something the user can act on. For numbered
/// asteroids we append the exact filename to look for (`seNNNNNs.se1`
/// in `astX/`) so the user can either download it from the Ephemeris
/// tab or drop it in manually.
String _describeBodyError(int body, String rawMessage) {
  if (body >= seAstOffset) {
    final mpc = body - seAstOffset;
    final sub = mpc ~/ 1000;
    final fname = 'se${mpc.toString().padLeft(6, '0')}s.se1';
    return 'Missing asteroid file $fname (ast$sub/). '
        'Open the Ephemeris tab to download or drop it in. '
        'SE error: $rawMessage';
  }
  return rawMessage;
}
