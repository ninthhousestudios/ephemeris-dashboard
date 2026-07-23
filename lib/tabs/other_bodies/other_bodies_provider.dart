// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_selection.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/horizontal_coords.dart';
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
import '../../core/ephe/catalog.dart';
import '../../core/house_systems.dart';
import '../../core/swe_service.dart';
import '../../layout/tab_definitions.dart';

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
    this.rascension = double.nan,
    this.declination = double.nan,
    this.dmin,
    this.horizontal = HorizontalCoords.nan,
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

  /// Position in the observer's horizontal frame (azimuth, altitude, zenith,
  /// meridian distance). [HorizontalCoords.nan] for helio/barycentric origins
  /// or when the card toggle is off (swe-dashboard/69).
  final HorizontalCoords horizontal;

  /// Raw `swe_house_pos` value (swetest `j`), NaN when not requested, not
  /// applicable (helio/barycentric), or the body could not be placed. See
  /// [houseNumberOf], [housePositionDegrees].
  final double housePos;

  /// Whether house position was requested and the frame was available; true
  /// with a NaN [housePos] surfaces as `—` instead of dropping the column.
  final bool houseRequested;
  final String? errorMessage;
}

/// Whether the Other Bodies card view shows each body's house position
/// (swe-dashboard/58). Default off; the house-system dropdown appears only when
/// on.
final otherBodiesShowHousePosProvider = StateProvider<bool>((ref) => false);

/// Whether the Other Bodies card view shows each body's horizontal coordinates
/// (azimuth, altitude, zenith, meridian distance — swe-dashboard/69). Default
/// off; the quantities are always present in series mode.
final otherBodiesShowHorizontalProvider = StateProvider<bool>((ref) => false);

// ── Computation ──

List<OtherBodyResult> computeOtherBodies({
  required Ephemeris eph,
  required Moment moment,
  required int iflag,
  required Origin origin,
  required List<int> bodies,
  required String Function(int body) getName,
  double geolon = 0,
  double geolat = 0,
  double geoalt = 0,
  bool includeHorizontal = false,
  bool includeHousePos = false,
  int hsys = 0x50,
}) {
  final isHorizonOrigin =
      origin == Origin.geocentric || origin == Origin.topocentric;

  // Horizontal coordinates are a geocentric-observer quantity: only the
  // geo/topocentric origins. GMST is per-Moment, reused for every body.
  final doHorizontal = includeHorizontal && isHorizonOrigin;
  double? gmstHours;
  if (doHorizontal) {
    try {
      gmstHours = eph.sidTime(moment.ut);
    } catch (_) {}
  }
  // The main `r` is a tropical ecliptic lon/lat only when none of these bits
  // are set; otherwise the horizontal feed needs a dedicated tropical calc.
  // Equatorial matters most: without it, RA/Dec would reach SE_ECL2HOR.
  final needTropicalCalc =
      doHorizontal &&
      (iflag & (seFlgXyz | seFlgSidereal | seFlgEquatorial)) != 0;

  // House position is a geocentric-observer quantity: only the geo/topocentric
  // origins, computed once per Moment then reused for every body.
  final doHousePos = includeHousePos && isHorizonOrigin;
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
  // Requested once the frame is in hand — bodies that then fail to place show
  // `—` rather than dropping the House column from the series picker.
  final houseRequested = hpInputs != null;

  return bodies.map((body) {
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

      var horizontal = HorizontalCoords.nan;
      if (doHorizontal) {
        double eclLon = r.longitude, eclLat = r.latitude, eclDist = r.distance;
        if (needTropicalCalc) {
          try {
            final trop = eph.calcUt(
              moment.ut,
              body,
              tropicalEclipticFlag(iflag),
            );
            eclLon = trop.longitude;
            eclLat = trop.latitude;
            eclDist = trop.distance;
          } catch (_) {
            eclLon = eclLat = eclDist = double.nan;
          }
        }
        horizontal = horizontalCoordsOf(
          eph,
          jdUt: moment.ut,
          geolon: geolon,
          geolat: geolat,
          geoalt: geoalt,
          eclLon: eclLon,
          eclLat: eclLat,
          eclDist: eclDist,
          ra: ra,
          gmstHours: gmstHours,
        );
      }

      var housePos = double.nan;
      if (hpInputs != null) {
        try {
          // Dedicated tropical ecliptic calc — swe_house_pos can't honour a
          // sidereal/XYZ config, so `r` can't be reused.
          final trop = eph.calcUt(moment.ut, body, tropicalEclipticFlag(iflag));
          housePos = housePosOf(eph, hpInputs, trop.longitude, trop.latitude);
        } catch (_) {}
      }

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
        rascension: ra,
        declination: dec,
        dmin: dmin,
        horizontal: horizontal,
        housePos: housePos,
        houseRequested: houseRequested,
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
        houseRequested: houseRequested,
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

List<OtherBodyResult> Function(Ephemeris, Moment) _otherBodiesCompute(Ref ref) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final bodies = ref.watch(otherBodiesSelectionProvider);

  // House position: computed on card-toggle, or always in series mode where it
  // is a default quantity (swe-dashboard/58); one app-wide house system.
  final seriesEnabled = ref.watch(
    seriesSettingsProvider(AppTab.otherBodies.name).select((s) => s.enabled),
  );
  final includeHousePos =
      ref.watch(otherBodiesShowHousePosProvider) || seriesEnabled;
  // Horizontal coordinates: on the card toggle, or always in series mode where
  // they are default quantities (swe-dashboard/69).
  final includeHorizontal =
      ref.watch(otherBodiesShowHorizontalProvider) || seriesEnabled;
  final hsys = ref.watch(selectedHouseSystemProvider);

  return (eph, moment) => computeOtherBodies(
    eph: eph,
    moment: moment,
    iflag: flags.iflag,
    origin: ctx.origin,
    bodies: bodies,
    getName: (body) {
      final local = otherBodyName(body);
      if (local != 'Body $body') return local;
      return safeGetName(swe, body);
    },
    geolon: ctx.longitude,
    geolat: ctx.latitude,
    geoalt: ctx.altitude,
    includeHorizontal: includeHorizontal,
    includeHousePos: includeHousePos,
    hsys: hsys,
  );
}

final _otherBodiesCalcProvider = Provider<CalcOutcome<List<OtherBodyResult>>>((
  ref,
) {
  return runTabCalc(ref, compute: _otherBodiesCompute(ref));
});

final otherBodiesResultsProvider = Provider<CalcOutcome<List<OtherBodyResult>>>(
  (ref) {
    return ref.watch(_otherBodiesCalcProvider);
  },
);

final otherBodiesSeriesProvider =
    Provider<List<(Moment, CalcOutcome<List<OtherBodyResult>>)>>((ref) {
      ref.watch(
        seriesSettingsProvider(
          AppTab.otherBodies.name,
        ).select((s) => (s.enabled, s.stepValue, s.stepUnit, s.rowCount)),
      );
      final settings = ref.read(
        seriesSettingsProvider(AppTab.otherBodies.name),
      );
      if (!settings.enabled) return const [];

      return runTabCalcSeries(
        ref,
        compute: _otherBodiesCompute(ref),
        settings: settings,
      );
    });

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
                  ...horizontalExportRows(r.horizontal, fmt),
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
