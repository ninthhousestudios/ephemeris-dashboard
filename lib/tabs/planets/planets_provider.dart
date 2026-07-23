// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_selection.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/house_pos.dart';
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
import '../../core/house_systems.dart';
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
    this.azimuth = double.nan,
    this.trueAltitude = double.nan,
    this.apparentAltitude = double.nan,
    this.zenithDistance = double.nan,
    this.meridianDistance = double.nan,
    this.housePos = double.nan,
    this.houseRequested = false,
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
  final double azimuth;
  final double trueAltitude;
  final double apparentAltitude;
  final double zenithDistance;
  final double meridianDistance;

  /// Raw `swe_house_pos` value (swetest `j`), NaN when house position was not
  /// requested, does not apply (helio/barycentric), or the body could not be
  /// placed. See [houseNumberOf] and [housePositionDegrees].
  final double housePos;

  /// Whether house position was requested and the house frame was available
  /// (geo/topocentric). True with a NaN [housePos] means the body could not be
  /// placed — surfaced as `—` rather than dropping the column.
  final bool houseRequested;
  final String? errorMessage;
}

/// Whether the Planets card view shows each body's house position (swetest
/// `-fGgj`, swe-dashboard/58). Default off to keep cards compact; the
/// house-system dropdown appears only while this is on.
final planetsShowHousePosProvider = StateProvider<bool>((ref) => false);

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
  required double geolon,
  required double geolat,
  required double geoalt,
  bool includeHousePos = false,
  int hsys = 0x50,
}) {
  var effectiveBodies = bodies;
  if ((origin == Origin.heliocentric || origin == Origin.barycentric) &&
      !bodies.contains(seEarth)) {
    effectiveBodies = [...bodies, seEarth];
  }

  final doHorizontal =
      origin == Origin.geocentric || origin == Origin.topocentric;
  double? gmstHours;
  if (doHorizontal) {
    try {
      gmstHours = eph.sidTime(moment.ut);
    } catch (_) {}
  }

  // House position is a geocentric-observer quantity — only meaningful for the
  // geo/topocentric origins, and computed once per Moment (ARMC + obliquity)
  // then reused for every body.
  final doHousePos = includeHousePos && doHorizontal;
  HousePosInputs? hpInputs;
  if (doHousePos) {
    try {
      hpInputs = housePosInputs(
        eph,
        jdUt: moment.ut,
        lat: geolat,
        lon: geolon,
        hsys: hsys,
        iflag: iflag,
      );
    } catch (_) {}
  }
  // House position is "requested" once the frame is in hand, even for bodies
  // that then fail to place — so the column stays stable (`—`) instead of
  // vanishing from the series picker.
  final houseRequested = hpInputs != null;

  final needTropicalCalc =
      doHorizontal && (iflag & (seFlgXyz | seFlgSidereal)) != 0;

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
      } catch (_) {}

      double? dmin;
      try {
        final od = eph.orbitMaxMinTrueDistance(moment.et, body, iflag);
        dmin = od.minDist;
      } catch (_) {}

      var az = double.nan;
      var trueAlt = double.nan;
      var appAlt = double.nan;
      var zenith = double.nan;
      var meridian = double.nan;
      if (doHorizontal) {
        try {
          double eclLon, eclLat, eclDist;
          if (needTropicalCalc) {
            final trop = eph.calcUt(
              moment.ut,
              body,
              iflag & ~seFlgXyz & ~seFlgSidereal,
            );
            eclLon = trop.longitude;
            eclLat = trop.latitude;
            eclDist = trop.distance;
          } else {
            eclLon = r.longitude;
            eclLat = r.latitude;
            eclDist = r.distance;
          }
          final hz = eph.azAlt(
            moment.ut,
            seEcl2hor,
            geolon: geolon,
            geolat: geolat,
            geoalt: geoalt,
            bodyLon: eclLon,
            bodyLat: eclLat,
            bodyDist: eclDist,
          );
          az = hz.azimuth;
          trueAlt = hz.trueAltitude;
          appAlt = hz.apparentAltitude;
          zenith = 90.0 - trueAlt;
          if (gmstHours != null && !ra.isNaN) {
            meridian =
                ((gmstHours * 15.0 + geolon - ra) % 360.0 + 540.0) % 360.0 -
                180.0;
          }
        } catch (_) {}
      }

      var housePos = double.nan;
      if (hpInputs != null) {
        try {
          // A dedicated tropical ecliptic calc: swe_house_pos is handle-free
          // and cannot honour a sidereal/XYZ config, so `r` can't be reused.
          final trop = eph.calcUt(moment.ut, body, housePosCalcFlag(iflag));
          housePos = housePosOf(eph, hpInputs, trop.longitude, trop.latitude);
        } catch (_) {}
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
        azimuth: az,
        trueAltitude: trueAlt,
        apparentAltitude: appAlt,
        zenithDistance: zenith,
        meridianDistance: meridian,
        housePos: housePos,
        houseRequested: houseRequested,
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
        houseRequested: houseRequested,
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

  // House position is computed when the card toggle asks for it, or always in
  // series mode where it is a default quantity (swe-dashboard/58). The single
  // app-wide house system drives it.
  final seriesEnabled = ref.watch(
    seriesSettingsProvider(AppTab.planets.name).select((s) => s.enabled),
  );
  final includeHousePos =
      ref.watch(planetsShowHousePosProvider) || seriesEnabled;
  final hsys = ref.watch(selectedHouseSystemProvider);

  return (eph, moment) => computePlanets(
    eph: eph,
    moment: moment,
    iflag: flags.iflag,
    origin: ctx.origin,
    bodies: bodies,
    getName: (body) => safeGetName(swe, body),
    geolon: ctx.longitude,
    geolat: ctx.latitude,
    geoalt: ctx.altitude,
    includeHousePos: includeHousePos,
    hsys: hsys,
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
      ref.watch(
        seriesSettingsProvider(
          AppTab.planets.name,
        ).select((s) => (s.enabled, s.stepValue, s.stepUnit, s.rowCount)),
      );
      final settings = ref.read(seriesSettingsProvider(AppTab.planets.name));
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
          // Mirror the card view: a body that failed at this step shows its
          // error string, not quantities formatted from NaN fields.
          fields: r.errorMessage != null
              ? [('Error', r.errorMessage!)]
              : [
                  (
                    lbl.c1,
                    isXyz
                        ? formatAu(r.longitude, fmt)
                        : formatAngle(r.longitude, fmt),
                  ),
                  (
                    lbl.c2,
                    isXyz
                        ? formatAu(r.latitude, fmt)
                        : formatAngle(r.latitude, fmt),
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
                    (
                      'Dist (rel)',
                      formatRelativeDistance(r.distance, r.dmin!, fmt),
                    ),
                  if (!isXyz) ...[
                    ('U ecl', formatUnitVector(r.longitude, r.latitude, fmt)),
                    if (!r.rascension.isNaN)
                      (
                        'U equ',
                        formatUnitVector(r.rascension, r.declination, fmt),
                      ),
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
                  if (!r.azimuth.isNaN) ...[
                    ('Azimuth', formatAngle(r.azimuth, fmt)),
                    ('True Alt', formatAngle(r.trueAltitude, fmt)),
                    ('App. Alt', formatAngle(r.apparentAltitude, fmt)),
                    ('Zenith Dist', formatAngle(r.zenithDistance, fmt)),
                  ],
                  if (!r.meridianDistance.isNaN)
                    ('Meridian Dist', formatAngle(r.meridianDistance, fmt)),
                  if (r.houseRequested) ...[
                    (
                      'House',
                      r.housePos.isNaN ? '—' : '${houseNumberOf(r.housePos)}',
                    ),
                    (
                      'House Pos',
                      r.housePos.isNaN
                          ? '—'
                          : formatAngle(housePositionDegrees(r.housePos), fmt),
                    ),
                  ],
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
