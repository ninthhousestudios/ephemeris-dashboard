// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_selection.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/body_utils.dart';
import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_service.dart';
import '../../layout/tab_definitions.dart';

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
    this.rascension = double.nan,
    this.declination = double.nan,
    this.dmin,
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
  final double rascension;
  final double declination;
  final double? dmin;
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
  seMeanNode,
  seTrueNode,
  seMeanApog,
  seOscuApog,
];

/// Presets for quick selection from the default set.
final bodyPresets = [
  BodyPreset('Classical', [
    seSun,
    seMoon,
    seMercury,
    seVenus,
    seMars,
    seJupiter,
    seSaturn,
  ]),
  BodyPreset('Full', defaultBodies),
  BodyPreset('Outers', [seUranus, seNeptune, sePluto]),
  BodyPreset('Nodes', [seMeanNode, seTrueNode, seMeanApog, seOscuApog]),
];

// ── Extra bodies (progressive disclosure, second row) ──

/// Chiron, Pholus, main-belt asteroids, Earth, interpolated apogee/perigee.
final extraBodies = [
  seChiron,
  sePholus,
  seCeres,
  sePallas,
  seJuno,
  seVesta,
  seEarth,
  seIntpApog,
  seIntpPerg,
];

/// Uranian / Hamburg School fictitious bodies.
final uranianBodies = [
  seCupido,
  seHades,
  seZeus,
  seKronos,
  seApollon,
  seAdmetos,
  seVulkanus,
  sePoseidon,
];

// ── Asteroid access (third level) ──

/// Offset for numbered asteroids: body ID = seAstOffset + MPC number.
const int asteroidOffset = seAstOffset; // 10000

/// Common named asteroids by MPC number.
final namedAsteroids = <int, String>{
  1: 'Ceres', // also seCeres (17), but MPC route works too
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
  2060: 'Chiron', // also seChiron (15)
  5145: 'Pholus', // also sePholus (16)
  7066: 'Nessus',
  136199: 'Eris',
  136472: 'Makemake',
  136108: 'Haumea',
  225088: 'Gonggong',
  50000: 'Quaoar',
  90377: 'Sedna',
  90482: 'Orcus',
};

/// Pure compute step: runs calcUt for each body, capturing per-body
/// SweExceptions as an `errorMessage` instead of failing the whole batch.
List<PlanetResult> computePlanets({
  required Ephemeris eph,
  required Moment moment,
  required int iflag,
  required Origin origin,
  required List<int> bodies,
  required String Function(int body) getName,
}) {
  var effectiveBodies = bodies;
  if ((origin == Origin.heliocentric || origin == Origin.barycentric) &&
      !bodies.contains(seEarth)) {
    effectiveBodies = [...bodies, seEarth];
  }

  return effectiveBodies.map((body) {
    try {
      final r = eph.calcUt(moment.ut, body, iflag | seFlgSpeed);

      var ra = double.nan;
      var dec = double.nan;
      try {
        final eq = eph.calcUt(
          moment.ut,
          body,
          (iflag | seFlgEquatorial) & ~seFlgXyz,
        );
        ra = eq.longitude;
        dec = eq.latitude;
      } catch (_) {
        // equatorial calc failed — leave NaN
      }

      double? dmin;
      try {
        final od = eph.orbitMaxMinTrueDistance(moment.et, body, iflag);
        dmin = od.minDist;
      } catch (_) {
        // not available for this body
      }

      return PlanetResult(
        body: body,
        bodyName: getName(body),
        longitude: r.longitude,
        latitude: r.latitude,
        distance: r.distance,
        speedLon: r.longitudeSpeed,
        speedLat: r.latitudeSpeed,
        speedDist: r.distanceSpeed,
        returnFlag: r.returnFlag,
        rascension: ra,
        declination: dec,
        dmin: dmin,
      );
    } on SweException catch (e) {
      return PlanetResult(
        body: body,
        bodyName: getName(body),
        longitude: double.nan,
        latitude: double.nan,
        distance: double.nan,
        speedLon: double.nan,
        speedLat: double.nan,
        speedDist: double.nan,
        returnFlag: -1,
        errorMessage: _describeBodyError(body, e.message),
      );
    }
  }).toList();
}

/// The tab's compute, bound to everything except the Moment.
///
/// Shared by the single-Moment and series providers so the two modes cannot
/// drift apart: series mode is the same calculation at N Moments, and nothing
/// about it is allowed to differ.
List<PlanetResult> Function(Ephemeris, Moment) _planetsCompute(Ref ref) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final bodies = ref.watch(selectedBodiesProvider);

  return (eph, moment) => computePlanets(
    eph: eph,
    moment: moment,
    iflag: flags.iflag,
    origin: ctx.origin,
    bodies: bodies,
    getName: (body) => safeGetName(swe, body),
  );
}

/// Runs the kernel once per recompute, so the native calc only runs a single
/// time per Context/Flags/selection change.
final _planetsCalcProvider = Provider<CalcOutcome<List<PlanetResult>>>((ref) {
  return runTabCalc(ref, compute: _planetsCompute(ref));
});

/// Planets calculation results.
final planetsResultsProvider = Provider<CalcOutcome<List<PlanetResult>>>((ref) {
  return ref.watch(_planetsCalcProvider);
});

/// The Planets series: this tab's own typed result at each step, each step
/// carrying its own [CalcOutcome].
///
/// Empty when the tab is not in series mode. Recompute is synchronous
/// (ADR-0001), so a series left running behind a switched-off toggle would tax
/// every Context change with N engine calls nobody asked for.
///
/// The typed result is kept rather than projected to `ExportRow`s here: the
/// grid is one consumer of the series, and discarding the typed result would
/// force the next one to re-derive it.
final planetsSeriesProvider =
    Provider<List<(Moment, CalcOutcome<List<PlanetResult>>)>>((ref) {
      final settings = ref.watch(seriesSettingsProvider(AppTab.planets.name));
      if (!settings.enabled) return const [];

      return runTabCalcSeries(
        ref,
        compute: _planetsCompute(ref),
        settings: settings,
      );
    });

/// Convert planet results to export rows.
List<ExportRow> planetsToExportRows(
  List<PlanetResult> results,
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
            ('Dist (ly)', formatDistanceLy(r.distance, fmt)),
            ('Dist (km)', formatDistanceKm(r.distance, fmt)),
            if (r.body == seMoon)
              ('Parallax', formatParallax(r.distance, fmt))
            else
              ('Dist (AU)', formatDistance(r.distance, fmt)),
            if (r.dmin != null)
              ('Dist (rel)', formatRelativeDistance(r.distance, r.dmin!, fmt)),
            if (!isXyz) ...[
              ('U ecl', formatUnitVector(r.longitude, r.latitude, fmt)),
              if (!r.rascension.isNaN)
                ('U equ', formatUnitVector(r.rascension, r.declination, fmt)),
            ],
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

/// Turn a raw SE error into something the user can act on. For numbered
/// asteroids we append the exact filename to look for (`seNNNNNs.se1`
/// in `astX/`) so the user can either download it from the Ephemeris
/// tab or drop it in manually.
String _describeBodyError(int body, String rawMessage) {
  if (body >= seAstOffset) {
    final mpc = body - seAstOffset;
    final sub = mpc ~/ 1000;
    final prefix = mpc >= 100000 ? 's' : 'se';
    final digits = mpc >= 100000 ? 6 : 5;
    final fname = '$prefix${mpc.toString().padLeft(digits, '0')}s.se1';
    return 'Missing asteroid file $fname (ast$sub/). '
        'Open the Ephemeris tab to download or drop it in. '
        'SE error: $rawMessage';
  }
  return rawMessage;
}
