// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/flag_masks.dart';
import '../../core/calculation/horizontal_coords.dart';
import '../../core/calculation/house_pos.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/display_format.dart';
import '../../core/ephe/dir_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/house_systems.dart';
import '../../core/swe_utils_provider.dart';
import '../../layout/tab_definitions.dart';

/// Common star names for quick-select chips.
const commonStars = [
  'Aldebaran',
  'Regulus',
  'Spica',
  'Antares',
  'Fomalhaut',
  'Algol',
  'Sirius',
  'Canopus',
  'Arcturus',
  'Vega',
  'Capella',
  'Rigel',
  'Betelgeuse',
  'Pollux',
];

/// Star catalog entry for autocomplete search.
class StarCatalogEntry {
  const StarCatalogEntry(this.commonName, this.bayerDesig);
  final String commonName;
  final String bayerDesig;

  /// The search term to pass to fixstar2Ut for Bayer lookup.
  String get bayerSearch => ',$bayerDesig';
}

List<StarCatalogEntry> _parseSefstars(String contents) {
  final entries = <StarCatalogEntry>[];
  for (final line in contents.split('\n')) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final fields = line.split(',');
    if (fields.length < 2) continue;
    entries.add(StarCatalogEntry(fields[0].trim(), fields[1].trim()));
  }
  return entries;
}

final starCatalogProvider = FutureProvider<List<StarCatalogEntry>>((ref) async {
  if (kIsWeb) {
    final contents = await rootBundle.loadString('assets/ephe/sefstars.txt');
    return _parseSefstars(contents);
  }
  final ephePath = ref.watch(resolvedEphePathProvider);
  if (ephePath == null) return const [];
  final file = File('$ephePath/sefstars.txt');
  if (!file.existsSync()) return const [];
  return _parseSefstars(file.readAsStringSync());
});

/// Current star search term (name or catalog number), bound to the search
/// text field. Submitting adds the term to [selectedStarsProvider].
final starSearchProvider = StateProvider<String>((ref) => 'Aldebaran');

/// Star names/search terms currently computed and shown as cards.
final selectedStarsProvider = StateProvider<List<String>>(
  (ref) => ['Aldebaran'],
);

/// Display format for star results.
final starsFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Result of a fixed star calculation.
class StarResult {
  const StarResult({
    required this.searchTerm,
    required this.resolvedName,
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.speedLon,
    required this.speedLat,
    required this.speedDist,
    required this.magnitude,
    required this.returnFlag,
    this.rascension = double.nan,
    this.declination = double.nan,
    this.horizontal = HorizontalCoords.nan,
    this.housePos = double.nan,
    this.houseRequested = false,
    this.errorMessage,
  });

  final String searchTerm;
  final String resolvedName;
  final double longitude;
  final double latitude;
  final double distance;
  final double speedLon;
  final double speedLat;
  final double speedDist;
  final double magnitude;
  final int returnFlag;
  final double rascension;
  final double declination;

  /// Position in the observer's horizontal frame (azimuth, altitude, zenith,
  /// meridian distance). [HorizontalCoords.nan] for helio/barycentric origins
  /// or when the card toggle is off (swe-dashboard/69).
  final HorizontalCoords horizontal;

  /// Raw `swe_house_pos` value (swetest `j`), NaN when not requested or the star
  /// could not be resolved. See [houseNumberOf], [housePositionDegrees].
  final double housePos;

  /// Whether house position was requested; true with a NaN [housePos] surfaces
  /// as `—` instead of dropping the column.
  final bool houseRequested;
  final String? errorMessage;
}

/// Whether the Stars card view shows each star's house position
/// (swe-dashboard/58). Default off; the house-system dropdown appears only when
/// on.
final starsShowHousePosProvider = StateProvider<bool>((ref) => false);

/// Whether the Stars card view shows each star's horizontal coordinates
/// (azimuth, altitude, zenith, meridian distance — swe-dashboard/69). Default
/// off; the quantities are always present in series mode.
final starsShowHorizontalProvider = StateProvider<bool>((ref) => false);

/// Pure compute: resolve a fixed star by name, with Bayer-prefix retry.
/// Returns null when the search term doesn't match any star (not an error).
StarResult? computeStar({
  required Ephemeris eph,
  required double jdUt,
  required int iflag,
  required String searchTerm,
  required double Function(String) getMagnitude,
  HousePosInputs? hpInputs,
  bool doHorizontal = false,
  double geolon = 0,
  double geolat = 0,
  double geoalt = 0,
  double? gmstHours,
}) {
  final term = searchTerm.trim();
  if (term.isEmpty) return null;

  final flags = iflag | seFlgSpeed;
  var r = eph.fixstar2Ut(term, jdUt, flags);

  // swisseph silently returns the first star (Aldebaran) when a search
  // doesn't match. Detect this by checking if the resolved name contains
  // what the user typed. If not, retry as a Bayer designation (leading
  // comma). If that also mismatches, return null.
  final termLower = term.toLowerCase();
  final bayerTerm = term.startsWith(',') ? term.substring(1) : term;
  bool nameMatches(String resolved) {
    final lower = resolved.toLowerCase();
    return lower.contains(termLower) || lower.contains(bayerTerm.toLowerCase());
  }

  if (!nameMatches(r.starName)) {
    if (!term.startsWith(',')) {
      try {
        r = eph.fixstar2Ut(',$term', jdUt, flags);
      } on SweException {
        return null;
      }
    }
    if (!nameMatches(r.starName)) {
      return null;
    }
  }

  final searchForMag = r.starName.split(',').first.trim();
  double magnitude;
  try {
    magnitude = getMagnitude(searchForMag);
  } catch (_) {
    magnitude = double.nan;
  }

  var ra = double.nan;
  var dec = double.nan;
  try {
    final eq = eph.fixstar2Ut(
      r.starName.split(',').first.trim(),
      jdUt,
      (iflag | seFlgEquatorial) & ~seFlgXyz,
    );
    ra = eq.longitude;
    dec = eq.latitude;
  } catch (_) {
    // equatorial calc failed — leave NaN
  }

  var horizontal = HorizontalCoords.nan;
  if (doHorizontal) {
    double eclLon = r.longitude, eclLat = r.latitude, eclDist = r.distance;
    if (!isFrameOfDate(iflag)) {
      try {
        // Dedicated tropical ecliptic-of-date lookup — the horizontal
        // transform needs tropical ecliptic lon/lat of date, which a
        // sidereal/XYZ/equatorial/J2000 config won't return (equatorial would
        // hand SE_ECL2HOR raw RA/Dec).
        final trop = eph.fixstar2Ut(searchForMag, jdUt, frameOfDateFlag(iflag));
        eclLon = trop.longitude;
        eclLat = trop.latitude;
        eclDist = trop.distance;
      } catch (_) {
        eclLon = eclLat = eclDist = double.nan;
      }
    }
    horizontal = horizontalCoordsOf(
      eph,
      jdUt: jdUt,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      eclLon: eclLon,
      eclLat: eclLat,
      eclDist: eclDist,
      ra: meridianRaOf(
        iflag: iflag,
        displayRa: ra,
        raAt: (flag) => eph.fixstar2Ut(searchForMag, jdUt, flag).longitude,
      ),
      gmstHours: gmstHours,
    );
  }

  var housePos = double.nan;
  if (hpInputs != null) {
    try {
      // Dedicated tropical ecliptic-of-date lookup — swe_house_pos can't
      // honour a sidereal/XYZ config, and its ARMC is of date.
      final trop = eph.fixstar2Ut(searchForMag, jdUt, frameOfDateFlag(iflag));
      housePos = housePosOf(eph, hpInputs, trop.longitude, trop.latitude);
    } catch (_) {
      // This star would not place — NaN renders `—` in a column the other
      // stars still fill.
    }
  }

  return StarResult(
    searchTerm: term,
    resolvedName: r.starName,
    longitude: r.longitude,
    latitude: r.latitude,
    distance: r.distance,
    speedLon: r.longitudeSpeed,
    speedLat: r.latitudeSpeed,
    speedDist: r.distanceSpeed,
    magnitude: magnitude,
    returnFlag: r.returnFlag,
    rascension: ra,
    declination: dec,
    horizontal: horizontal,
    housePos: housePos,
    houseRequested: hpInputs != null,
  );
}

/// Pure compute step: resolves each selected star, capturing per-star
/// lookup failures (no match or SweException) as an `errorMessage` instead
/// of failing the whole batch.
List<StarResult> computeStars({
  required Ephemeris eph,
  required double jdUt,
  required int iflag,
  required List<String> searchTerms,
  required double Function(String) getMagnitude,
  Origin origin = Origin.geocentric,
  double geolon = 0,
  double geolat = 0,
  double geoalt = 0,
  bool includeHorizontal = false,
  bool includeHousePos = false,
  int hsys = 0x50,
}) {
  // Horizontal coordinates are a geocentric-observer quantity: only the
  // geo/topocentric origins. GMST is per-Moment, reused for every star.
  final doHorizontal =
      includeHorizontal &&
      (origin == Origin.geocentric || origin == Origin.topocentric);
  double? gmstHours;
  if (doHorizontal) {
    try {
      gmstHours = eph.sidTime(jdUt);
    } catch (_) {
      // Null GMST is a documented input to horizontalCoordsOf: az/alt still
      // compute, only the meridian distance goes NaN (shown as `—`).
    }
  }

  // House position inputs (ARMC + obliquity) computed once per Moment, reused
  // for every star.
  HousePosInputs? hpInputs;
  if (includeHousePos) {
    try {
      hpInputs = housePosInputs(
        eph,
        jdUt: jdUt,
        lat: geolat,
        lon: geolon,
        hsys: hsys,
        iflag: iflag,
      );
    } catch (_) {
      // No frame, no House column at all: `houseRequested` reads hpInputs, so
      // the column is dropped rather than shown as wrong.
    }
  }

  return searchTerms.map((term) {
    try {
      final result = computeStar(
        eph: eph,
        jdUt: jdUt,
        iflag: iflag,
        searchTerm: term,
        getMagnitude: getMagnitude,
        hpInputs: hpInputs,
        doHorizontal: doHorizontal,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        gmstHours: gmstHours,
      );
      if (result != null) return result;
      return StarResult(
        searchTerm: term,
        resolvedName: term,
        longitude: double.nan,
        latitude: double.nan,
        distance: double.nan,
        speedLon: double.nan,
        speedLat: double.nan,
        speedDist: double.nan,
        magnitude: double.nan,
        returnFlag: -1,
        houseRequested: hpInputs != null,
        errorMessage: 'Star not found — check the name or catalog number',
      );
    } on SweException catch (e) {
      return StarResult(
        searchTerm: term,
        resolvedName: term,
        longitude: double.nan,
        latitude: double.nan,
        distance: double.nan,
        speedLon: double.nan,
        speedLat: double.nan,
        speedDist: double.nan,
        magnitude: double.nan,
        returnFlag: -1,
        houseRequested: hpInputs != null,
        errorMessage: e.message,
      );
    }
  }).toList();
}

List<StarResult> Function(Ephemeris, Moment) _starsCompute(Ref ref) {
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final searchTerms = ref.watch(selectedStarsProvider);
  final ctx = ref.watch(contextBarProvider);

  // House position: computed on card-toggle, or always in series mode where it
  // is a default quantity (swe-dashboard/58); one app-wide house system.
  final seriesEnabled = ref.watch(
    seriesSettingsProvider(AppTab.stars.name).select((s) => s.enabled),
  );
  final includeHousePos = ref.watch(starsShowHousePosProvider) || seriesEnabled;
  // Horizontal coordinates: on the card toggle, or always in series mode where
  // they are default quantities (swe-dashboard/69).
  final includeHorizontal =
      ref.watch(starsShowHorizontalProvider) || seriesEnabled;
  final hsys = ref.watch(selectedHouseSystemProvider);

  return (eph, moment) => computeStars(
    eph: eph,
    jdUt: moment.ut,
    iflag: flags.iflag,
    searchTerms: searchTerms,
    getMagnitude: (star) => swe.fixstar2Mag(star).magnitude,
    origin: ctx.origin,
    geolon: ctx.longitude,
    geolat: ctx.latitude,
    geoalt: ctx.altitude,
    includeHorizontal: includeHorizontal,
    includeHousePos: includeHousePos,
    hsys: hsys,
  );
}

final _starCalcProvider = Provider<CalcOutcome<List<StarResult>>>((ref) {
  return runTabCalc(ref, compute: _starsCompute(ref));
});

final starResultProvider = Provider<CalcOutcome<List<StarResult>>>((ref) {
  return ref.watch(_starCalcProvider);
});

final starsSeriesProvider =
    Provider<List<(Moment, CalcOutcome<List<StarResult>>)>>((ref) {
      return seriesSteps(
        ref,
        AppTab.stars.name,
        compute: () => _starsCompute(ref),
      );
    });

/// Convert star results to export rows.
List<ExportRow> starToExportRows(
  List<StarResult> results,
  DisplayFormat fmt, {
  bool isXyz = false,
  int coordValue = 0,
}) {
  final lbl = coordLabels(coordValue);
  return results.map((result) {
    return ExportRow(
      header: result.resolvedName,
      // Mirror the card view: a star that failed to resolve at this step shows
      // its error string, not quantities formatted from NaN fields.
      fields: result.errorMessage != null
          ? [('Error', result.errorMessage!)]
          : [
              (
                lbl.c1,
                isXyz
                    ? formatAu(result.longitude, fmt)
                    : formatAngle(result.longitude, fmt),
              ),
              (
                lbl.c2,
                isXyz
                    ? formatAu(result.latitude, fmt)
                    : formatAngle(result.latitude, fmt),
              ),
              (
                lbl.c3,
                isXyz
                    ? formatAu(result.distance, fmt)
                    : formatDistance(result.distance, fmt),
              ),
              if (isXyz)
                (
                  'Distance',
                  formatEuclidean(
                    result.longitude,
                    result.latitude,
                    result.distance,
                    fmt,
                    lightYears: true,
                  ),
                ),
              ('Dist (ly)', formatDistanceLy(result.distance, fmt)),
              ('Dist (km)', formatDistanceKm(result.distance, fmt)),
              (
                'Magnitude',
                result.magnitude.isNaN
                    ? '—'
                    : result.magnitude.toStringAsFixed(2),
              ),
              if (!isXyz) ...[
                (
                  'U ecl',
                  formatUnitVector(result.longitude, result.latitude, fmt),
                ),
                if (!result.rascension.isNaN)
                  (
                    'U equ',
                    formatUnitVector(
                      result.rascension,
                      result.declination,
                      fmt,
                    ),
                  ),
              ],
              (
                lbl.sc1,
                isXyz
                    ? formatAuSpeed(result.speedLon, fmt)
                    : formatSpeed(result.speedLon, fmt),
              ),
              (
                lbl.sc2,
                isXyz
                    ? formatAuSpeed(result.speedLat, fmt)
                    : formatSpeed(result.speedLat, fmt),
              ),
              (
                lbl.sc3,
                isXyz
                    ? formatAuSpeed(result.speedDist, fmt)
                    : formatSpeed(result.speedDist, fmt),
              ),
              ...horizontalExportRows(result.horizontal, fmt),
              if (result.houseRequested) ...[
                (
                  'House',
                  result.housePos.isNaN
                      ? '—'
                      : '${houseNumberOf(result.housePos)}',
                ),
                (
                  'House Pos',
                  result.housePos.isNaN
                      ? '—'
                      : formatAngle(housePositionDegrees(result.housePos), fmt),
                ),
              ],
            ],
    );
  }).toList();
}
