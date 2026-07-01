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
  seSun,
  seMercury,
  seVenus,
  seEarth,
  seMars,
  seJupiter,
  seSaturn,
  seUranus,
  seNeptune,
  sePluto,
];

/// Default target bodies.
final defaultTargetBodies = [
  seSun,
  seMoon,
  seMercury,
  seVenus,
  seMars,
  seJupiter,
  seSaturn,
  seUranus,
  seNeptune,
  sePluto,
];

/// Extra target bodies (progressive disclosure).
final extraTargetBodies = [
  seEarth,
  seChiron,
  sePholus,
  seCeres,
  sePallas,
  seJuno,
  seVesta,
  seMeanNode,
  seTrueNode,
  seMeanApog,
  seOscuApog,
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

List<PlanetoCentricResult> computePlanetocentric({
  required Ephemeris eph,
  required double jdEt,
  required int iflag,
  required int centerBody,
  required String centerName,
  required List<int> targetBodies,
  required String Function(int) getName,
}) {
  final flags = iflag | seFlgSpeed;
  final results = <PlanetoCentricResult>[];
  for (final body in targetBodies) {
    if (body == centerBody) continue;
    try {
      final r = eph.calcPctr(jdEt, body, centerBody, flags);
      results.add(
        PlanetoCentricResult(
          body: body,
          bodyName: getName(body),
          centerBody: centerBody,
          centerName: centerName,
          longitude: r.longitude,
          latitude: r.latitude,
          distance: r.distance,
          speedLon: r.longitudeSpeed,
          speedLat: r.latitudeSpeed,
          speedDist: r.distanceSpeed,
          returnFlag: r.returnFlag,
        ),
      );
    } on SweException {
      results.add(
        PlanetoCentricResult(
          body: body,
          bodyName: getName(body),
          centerBody: centerBody,
          centerName: centerName,
          longitude: double.nan,
          latitude: double.nan,
          distance: double.nan,
          speedLon: double.nan,
          speedLat: double.nan,
          speedDist: double.nan,
          returnFlag: -1,
        ),
      );
    }
  }
  return results;
}

final _planetocentricCalcProvider =
    Provider<
      ({CalcOutcome<List<PlanetoCentricResult>> outcome, CallTrace trace})
    >((ref) {
      final ctx = ref.watch(contextBarProvider);
      final flags = ref.watch(flagBarProvider);
      final swe = ref.read(sweProvider);
      final centerBody = ref.watch(planetocentricCenterProvider);
      final bodies = ref.watch(planetocentricBodiesProvider);

      final jdEt = ctx.jdUt + swe.deltat(ctx.jdUt);

      return runTabCalc(
        ref,
        tabTag: 'planetocentric',
        compute: (eph) => computePlanetocentric(
          eph: eph,
          jdEt: jdEt,
          iflag: flags.iflag,
          centerBody: centerBody,
          centerName: safeGetName(swe, centerBody),
          targetBodies: bodies,
          getName: (body) => safeGetName(swe, body),
        ),
      );
    });

final planetocentricResultsProvider =
    Provider<CalcOutcome<List<PlanetoCentricResult>>>((ref) {
      return ref.watch(_planetocentricCalcProvider.select((c) => c.outcome));
    });

final planetocentricTraceProvider = Provider<CallTrace>((ref) {
  return ref.watch(_planetocentricCalcProvider.select((c) => c.trace));
});

List<ExportRow> planetocentricToExportRows(
  List<PlanetoCentricResult> results,
  DisplayFormat fmt,
) {
  return results
      .map(
        (r) => ExportRow(
          header: '${r.bodyName} from ${r.centerName}',
          fields: [
            ('Longitude', formatAngle(r.longitude, fmt)),
            ('Latitude', formatAngle(r.latitude, fmt)),
            ('Distance', formatDistance(r.distance, fmt)),
            ('Spd Lon', formatSpeed(r.speedLon, fmt)),
            ('Spd Lat', formatSpeed(r.speedLat, fmt)),
            ('Spd Dist', formatSpeed(r.speedDist, fmt)),
          ],
        ),
      )
      .toList();
}
