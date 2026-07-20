// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/body_utils.dart';
import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/ephemeris/trace_model.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_service.dart';

// ── Planetary moon body IDs (SE_PLMOON_OFFSET + planet*100 + moon) ──

class MoonGroup {
  const MoonGroup(this.parent, this.moons);
  final String parent;
  final List<({int bodyId, String name})> moons;
}

final planetaryMoonGroups = <MoonGroup>[
  MoonGroup('Mars', [
    (bodyId: 9401, name: 'Phobos'),
    (bodyId: 9402, name: 'Deimos'),
  ]),
  MoonGroup('Jupiter', [
    (bodyId: 9501, name: 'Io'),
    (bodyId: 9502, name: 'Europa'),
    (bodyId: 9503, name: 'Ganymede'),
    (bodyId: 9504, name: 'Callisto'),
    (bodyId: 9599, name: 'Jupiter COB'),
  ]),
  MoonGroup('Saturn', [
    (bodyId: 9601, name: 'Mimas'),
    (bodyId: 9602, name: 'Enceladus'),
    (bodyId: 9603, name: 'Tethys'),
    (bodyId: 9604, name: 'Dione'),
    (bodyId: 9605, name: 'Rhea'),
    (bodyId: 9606, name: 'Titan'),
    (bodyId: 9607, name: 'Hyperion'),
    (bodyId: 9608, name: 'Iapetus'),
    (bodyId: 9699, name: 'Saturn COB'),
  ]),
  MoonGroup('Uranus', [
    (bodyId: 9701, name: 'Ariel'),
    (bodyId: 9702, name: 'Umbriel'),
    (bodyId: 9703, name: 'Titania'),
    (bodyId: 9704, name: 'Oberon'),
    (bodyId: 9705, name: 'Miranda'),
    (bodyId: 9799, name: 'Uranus COB'),
  ]),
  MoonGroup('Neptune', [
    (bodyId: 9801, name: 'Triton'),
    (bodyId: 9802, name: 'Nereid'),
    (bodyId: 9808, name: 'Proteus'),
    (bodyId: 9899, name: 'Neptune COB'),
  ]),
  MoonGroup('Pluto', [
    (bodyId: 9901, name: 'Charon'),
    (bodyId: 9902, name: 'Nix'),
    (bodyId: 9903, name: 'Hydra'),
    (bodyId: 9904, name: 'Kerberos'),
    (bodyId: 9905, name: 'Styx'),
    (bodyId: 9999, name: 'Pluto COB'),
  ]),
];

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

// ── Named comets (pseudo-MPC numbers) ──

const namedComets = <int, String>{
  999032: '67P/Churyumov-Ger.',
  999043: 'C/2020 F3 (NEOWISE)',
  999044: '1P/Halley',
  999045: "1I/'Oumuamua",
  999046: 'Hale-Bopp',
  999047: 'West',
};

// ── Selection state ──

final otherBodiesSelectionProvider = StateProvider<List<int>>((ref) => <int>[]);

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
        errorMessage: _describeError(body, e.message),
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

String _describeError(int body, String rawMessage) {
  if (body >= sePlmoonOffset && body < seAstOffset) {
    return 'Missing satellite file sepm$body.se1 (sat/). '
        'Open the Ephemeris tab to download. '
        'SE error: $rawMessage';
  }
  if (body >= seAstOffset) {
    final mpc = body - seAstOffset;
    final sub = mpc ~/ 1000;
    final prefix = mpc >= 100000 ? 's' : 'se';
    final digits = mpc >= 100000 ? 6 : 5;
    final fname = '$prefix${mpc.toString().padLeft(digits, '0')}s.se1';
    return 'Missing file $fname (ast$sub/). '
        'Open the Ephemeris tab to download. '
        'SE error: $rawMessage';
  }
  return rawMessage;
}

// ── Providers ──

final _otherBodiesCalcProvider =
    Provider<({CalcOutcome<List<OtherBodyResult>> outcome, CallTrace trace})>((
      ref,
    ) {
      final ctx = ref.watch(contextBarProvider);
      final flags = ref.watch(flagBarProvider);
      final swe = ref.read(sweProvider);
      final bodies = ref.watch(otherBodiesSelectionProvider);

      return runTabCalc(
        ref,
        tabTag: 'other_bodies',
        compute: (eph) => computeOtherBodies(
          eph: eph,
          jdUt: ctx.jdUt,
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
    return ref.watch(_otherBodiesCalcProvider.select((c) => c.outcome));
  },
);

final otherBodiesTraceProvider = Provider<CallTrace>((ref) {
  return ref.watch(_otherBodiesCalcProvider.select((c) => c.trace));
});

final otherBodiesFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

List<ExportRow> otherBodiesToExportRows(
  List<OtherBodyResult> results,
  DisplayFormat fmt,
) {
  return results
      .map(
        (r) => ExportRow(
          header: r.bodyName,
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
