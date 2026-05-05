import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../core/swe_service.dart';

class PlanetoCentricResult {
  const PlanetoCentricResult({
    required this.body,
    required this.bodyName,
    required this.centerBody,
    required this.centerName,
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.speedLon,
    required this.speedLat,
    required this.speedDist,
    required this.returnFlag,
  });

  final int body;
  final String bodyName;
  final int centerBody;
  final String centerName;
  final double longitude;
  final double latitude;
  final double distance;
  final double speedLon;
  final double speedLat;
  final double speedDist;
  final int returnFlag;
}

/// Bodies available as center (observer).
final centerBodies = [
  seSun, seMercury, seVenus, seEarth, seMars,
  seJupiter, seSaturn, seUranus, seNeptune, sePluto,
];

/// Default target bodies.
final defaultTargetBodies = [
  seSun, seMoon, seMercury, seVenus, seMars,
  seJupiter, seSaturn, seUranus, seNeptune, sePluto,
];

/// Extra target bodies (progressive disclosure).
final extraTargetBodies = [
  seEarth, seChiron, sePholus, seCeres, sePallas, seJuno, seVesta,
  seMeanNode, seTrueNode, seMeanApog, seOscuApog,
];

/// Selected center body (observer).
final planetocentricCenterProvider = StateProvider<int>((ref) => seSun);

/// Selected target bodies.
final planetocentricBodiesProvider = StateProvider<List<int>>(
  (ref) => [seMoon, seMercury, seVenus, seEarth, seMars, seJupiter, seSaturn],
);

/// Display format for this tab.
final planetocentricFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Planetocentric calculation results.
final planetocentricResultsProvider =
    Provider<List<PlanetoCentricResult>>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('planetocentric')) return const [];

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final swe = ref.read(sweProvider);
  final centerBody = ref.watch(planetocentricCenterProvider);
  final bodies = ref.watch(planetocentricBodiesProvider);

  // calcPctr takes ET, not UT.
  final jdEt = ectx.jdUt + swe.deltat(ectx.jdUt);
  final flags = ectx.iflag | seFlgSpeed;
  final centerName = swe.getPlanetName(centerBody);

  final results = <PlanetoCentricResult>[];
  for (final body in bodies) {
    if (body == centerBody) continue;
    try {
      final r = runner.run(
        globals, (eph) => eph.calcPctr(jdEt, body, centerBody, flags));
      results.add(PlanetoCentricResult(
        body: body,
        bodyName: swe.getPlanetName(body),
        centerBody: centerBody,
        centerName: centerName,
        longitude: r.longitude,
        latitude: r.latitude,
        distance: r.distance,
        speedLon: r.longitudeSpeed,
        speedLat: r.latitudeSpeed,
        speedDist: r.distanceSpeed,
        returnFlag: r.returnFlag,
      ));
    } on SweException {
      results.add(PlanetoCentricResult(
        body: body,
        bodyName: _safeGetName(swe, body),
        centerBody: centerBody,
        centerName: centerName,
        longitude: double.nan,
        latitude: double.nan,
        distance: double.nan,
        speedLon: double.nan,
        speedLat: double.nan,
        speedDist: double.nan,
        returnFlag: -1,
      ));
    }
  }

  return results;
});

List<ExportRow> planetocentricToExportRows(
    List<PlanetoCentricResult> results, DisplayFormat fmt) {
  return results
      .map((r) => ExportRow(
            header: '${r.bodyName} from ${r.centerName}',
            fields: [
              ('Longitude', formatAngle(r.longitude, fmt)),
              ('Latitude', formatAngle(r.latitude, fmt)),
              ('Distance', formatDistance(r.distance, fmt)),
              ('Spd Lon', formatSpeed(r.speedLon, fmt)),
              ('Spd Lat', formatSpeed(r.speedLat, fmt)),
              ('Spd Dist', formatSpeed(r.speedDist, fmt)),
            ],
          ))
      .toList();
}

String _safeGetName(SwissEph swe, int body) {
  try {
    return swe.getPlanetName(body);
  } catch (_) {
    return 'Body $body';
  }
}
