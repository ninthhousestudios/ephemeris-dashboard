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
import '../../core/swe_utils_provider.dart';
import '../../layout/tab_definitions.dart';

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
/// Only real physical bodies — mathematical points (nodes, apogees) have no
/// heliocentric position and cannot be used with calcPctr.
final extraTargetBodies = [
  seEarth,
  seChiron,
  sePholus,
  seCeres,
  sePallas,
  seJuno,
  seVesta,
  seCupido,
  seHades,
  seZeus,
  seKronos,
  seApollon,
  seAdmetos,
  seVulkanus,
  sePoseidon,
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
      if (results.isEmpty) rethrow;
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

List<PlanetoCentricResult> Function(Ephemeris, Moment) _planetocentricCompute(
  Ref ref,
) {
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final centerBody = ref.watch(planetocentricCenterProvider);
  final bodies = ref.watch(planetocentricBodiesProvider);

  return (eph, moment) => computePlanetocentric(
    eph: eph,
    jdEt: moment.et,
    iflag: flags.iflag,
    centerBody: centerBody,
    centerName: safeGetName(swe, centerBody),
    targetBodies: bodies,
    getName: (body) => safeGetName(swe, body),
  );
}

final _planetocentricCalcProvider =
    Provider<CalcOutcome<List<PlanetoCentricResult>>>((ref) {
      return runTabCalc(ref, compute: _planetocentricCompute(ref));
    });

final planetocentricResultsProvider =
    Provider<CalcOutcome<List<PlanetoCentricResult>>>((ref) {
      return ref.watch(_planetocentricCalcProvider);
    });

final planetocentricSeriesProvider =
    Provider<List<(Moment, CalcOutcome<List<PlanetoCentricResult>>)>>((ref) {
      ref.watch(
        seriesSettingsProvider(
          AppTab.planetocentric.name,
        ).select((s) => (s.enabled, s.stepValue, s.stepUnit, s.rowCount)),
      );
      final settings = ref.read(
        seriesSettingsProvider(AppTab.planetocentric.name),
      );
      if (!settings.enabled) return const [];

      return runTabCalcSeries(
        ref,
        compute: _planetocentricCompute(ref),
        settings: settings,
      );
    });

List<ExportRow> planetocentricToExportRows(
  List<PlanetoCentricResult> results,
  DisplayFormat fmt, {
  bool isXyz = false,
  int coordValue = 0,
}) {
  final lbl = coordLabels(coordValue);
  return results
      .map(
        (r) => ExportRow(
          header: '${r.bodyName} from ${r.centerName}',
          fields: [
            (
              lbl.c1,
              isXyz
                  ? formatAu(r.longitude, fmt)
                  : formatAngle(r.longitude, fmt),
            ),
            (
              lbl.c2,
              isXyz ? formatAu(r.latitude, fmt) : formatAngle(r.latitude, fmt),
            ),
            (
              lbl.c3,
              isXyz
                  ? formatAu(r.distance, fmt)
                  : formatDistance(r.distance, fmt),
            ),
            if (isXyz)
              (
                'Distance',
                formatEuclidean(r.longitude, r.latitude, r.distance, fmt),
              ),
            (
              lbl.sc1,
              isXyz
                  ? formatAuSpeed(r.speedLon, fmt)
                  : formatSpeed(r.speedLon, fmt),
            ),
            (
              lbl.sc2,
              isXyz
                  ? formatAuSpeed(r.speedLat, fmt)
                  : formatSpeed(r.speedLat, fmt),
            ),
            (
              lbl.sc3,
              isXyz
                  ? formatAuSpeed(r.speedDist, fmt)
                  : formatSpeed(r.speedDist, fmt),
            ),
          ],
        ),
      )
      .toList();
}
