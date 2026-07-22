// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_selection.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/body_utils.dart';
import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/ephe/catalog.dart';
import '../../core/swe_service.dart';

final _allMoonBodyIds = <int, String>{
  for (final g in planetaryMoonGroups)
    for (final m in g.moons) m.bodyId: m.name,
};

// ── Named asteroids (same seed as planets tab + extras) ──

const otherBodiesNamedAsteroids = <int, String>{
  1: 'Ceres',
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
  2060: 'Chiron',
  5145: 'Pholus',
  7066: 'Nessus',
  50000: 'Quaoar',
  90377: 'Sedna',
  90482: 'Orcus',
  136108: 'Haumea',
  136199: 'Eris',
  136472: 'Makemake',
  225088: 'Gonggong',
};

// ── Named comets (pseudo-MPC numbers, derived from catalog) ──

final namedComets = <int, String>{
  for (final (mpc, name) in cometSeed) mpc: name,
};

// ── Result type (shared with planets) ──

class OtherBodyResult {
  const OtherBodyResult({
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
  final String? errorMessage;
}

// ── Computation ──

List<OtherBodyResult> computeOtherBodies({
  required Ephemeris eph,
  required double jdUt,
  required int iflag,
  required Origin origin,
  required List<int> bodies,
  required String Function(int body) getName,
}) {
  return bodies.map((body) {
    try {
      final r = eph.calcUt(jdUt, body, iflag | seFlgSpeed);
      return OtherBodyResult(
        body: body,
        bodyName: getName(body),
        longitude: r.longitude,
        latitude: r.latitude,
        distance: r.distance,
        speedLon: r.longitudeSpeed,
        speedLat: r.latitudeSpeed,
        speedDist: r.distanceSpeed,
        returnFlag: r.returnFlag,
      );
    } on SweException catch (e) {
      return OtherBodyResult(
        body: body,
        bodyName: getName(body),
        longitude: double.nan,
        latitude: double.nan,
        distance: double.nan,
        speedLon: double.nan,
        speedLat: double.nan,
        speedDist: double.nan,
        returnFlag: -1,
        errorMessage: describeBodyError(body, e.message),
      );
    }
  }).toList();
}

String otherBodyName(int body) {
  if (_allMoonBodyIds.containsKey(body)) return _allMoonBodyIds[body]!;
  if (body >= seAstOffset) {
    final mpc = body - seAstOffset;
    if (namedComets.containsKey(mpc)) return namedComets[mpc]!;
    if (otherBodiesNamedAsteroids.containsKey(mpc)) {
      return otherBodiesNamedAsteroids[mpc]!;
    }
    return '#$mpc';
  }
  return 'Body $body';
}

// ── Providers ──

final _otherBodiesCalcProvider = Provider<CalcOutcome<List<OtherBodyResult>>>((
  ref,
) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final bodies = ref.watch(otherBodiesSelectionProvider);

  return runTabCalc(
    ref,
    compute: (eph, moment) => computeOtherBodies(
      eph: eph,
      jdUt: moment.ut,
      iflag: flags.iflag,
      origin: ctx.origin,
      bodies: bodies,
      getName: (body) {
        final local = otherBodyName(body);
        if (local != 'Body $body') return local;
        return safeGetName(swe, body);
      },
    ),
  );
});

final otherBodiesResultsProvider = Provider<CalcOutcome<List<OtherBodyResult>>>(
  (ref) {
    return ref.watch(_otherBodiesCalcProvider);
  },
);

final otherBodiesFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

List<ExportRow> otherBodiesToExportRows(
  List<OtherBodyResult> results,
  DisplayFormat fmt, {
  bool isXyz = false,
  int coordValue = 0,
}) {
  final lbl = coordLabels(coordValue);
  return results
      .map(
        (r) => ExportRow(
          header: r.bodyName,
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
