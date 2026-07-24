// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../display_format.dart';
import '../ephemeris/ephemeris.dart';
import '../swe_constants.dart';
import 'flag_masks.dart';

/// A body's position in the observer's horizontal frame at one Moment
/// (swetest `-fPADIH`-adjacent quantities): azimuth, true/apparent altitude,
/// zenith distance, and meridian (hour-angle) distance.
///
/// Only meaningful for the geo/topocentric origins; helio/barycentric leave it
/// [nan]. Shared by the three body tabs (Planets/Other Bodies/Stars,
/// swe-dashboard/69) so the recipe lives in one place — the ecliptic position
/// that feeds it is acquired per body type (`calcUt` vs `fixstar2Ut`), but the
/// az/alt math and rendering are common.
class HorizontalCoords {
  const HorizontalCoords({
    this.azimuth = double.nan,
    this.trueAltitude = double.nan,
    this.apparentAltitude = double.nan,
    this.zenithDistance = double.nan,
    this.meridianDistance = double.nan,
  });

  final double azimuth;
  final double trueAltitude;
  final double apparentAltitude;
  final double zenithDistance;
  final double meridianDistance;

  /// Sentinel for "not computed" (wrong origin, or the calc threw).
  static const nan = HorizontalCoords();

  /// True once the frame was computed — the single gate every consumer uses,
  /// so a body that could not be placed shows nothing rather than NaN cells.
  bool get hasValue => !azimuth.isNaN;
}

/// The right ascension to feed [horizontalCoordsOf] as [ra].
///
/// The meridian distance differences RA against GMST *of date*, so the RA has
/// to be referred to the equinox of date too. [displayRa] — the RA the tab
/// shows, which deliberately follows the Context frame, J2000 and all — is only
/// usable when the Context is already of date ([isEquinoxOfDate]). Otherwise
/// [raAt] re-reads the body at [frameOfDateFlag], the one extra engine call
/// being the price of not mixing two equinoxes into a physical angle.
///
/// [raAt] is the tab's own position lookup (`calcUt` for bodies, `fixstar2Ut`
/// for stars) reduced to "give me the RA at this flag"; a throw leaves the
/// meridian distance NaN, as an unavailable RA already does.
double meridianRaOf({
  required int iflag,
  required double displayRa,
  required double Function(int flag) raAt,
}) {
  if (isEquinoxOfDate(iflag)) return displayRa;
  try {
    return raAt(frameOfDateFlag(iflag) | seFlgEquatorial);
  } catch (_) {
    return double.nan;
  }
}

/// Computes [HorizontalCoords] from a body's tropical ecliptic position.
///
/// [eclLon]/[eclLat]/[eclDist] must be tropical ecliptic (never sidereal/XYZ);
/// the caller strips those bits before the ecliptic calc, exactly as house
/// position does. [ra] is the equatorial right ascension (for the meridian
/// distance) and [gmstHours] the Greenwich mean sidereal time in hours; either
/// being unavailable simply leaves the meridian distance NaN. Any engine error
/// yields [HorizontalCoords.nan] rather than propagating.
HorizontalCoords horizontalCoordsOf(
  Ephemeris eph, {
  required double jdUt,
  required double geolon,
  required double geolat,
  required double geoalt,
  required double eclLon,
  required double eclLat,
  required double eclDist,
  required double ra,
  required double? gmstHours,
}) {
  try {
    final hz = eph.azAlt(
      jdUt,
      seEcl2hor,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      bodyLon: eclLon,
      bodyLat: eclLat,
      bodyDist: eclDist,
    );
    final trueAlt = hz.trueAltitude;
    var meridian = double.nan;
    if (gmstHours != null && !ra.isNaN) {
      meridian =
          ((gmstHours * 15.0 + geolon - ra) % 360.0 + 540.0) % 360.0 - 180.0;
    }
    return HorizontalCoords(
      azimuth: hz.azimuth,
      trueAltitude: trueAlt,
      apparentAltitude: hz.apparentAltitude,
      zenithDistance: 90.0 - trueAlt,
      meridianDistance: meridian,
    );
  } catch (_) {
    return HorizontalCoords.nan;
  }
}

/// The horizontal-frame rows for an export table (label/value pairs), empty
/// when the frame was not computed. Shared by every body tab's
/// `*ToExportRows` so the label set and formatting never drift.
List<(String, String)> horizontalExportRows(
  HorizontalCoords h,
  DisplayFormat fmt,
) => [
  if (h.hasValue) ...[
    ('Azimuth', formatAngle(h.azimuth, fmt)),
    ('True Alt', formatAngle(h.trueAltitude, fmt)),
    ('App. Alt', formatAngle(h.apparentAltitude, fmt)),
    ('Zenith Dist', formatAngle(h.zenithDistance, fmt)),
  ],
  if (!h.meridianDistance.isNaN)
    ('Meridian Dist', formatAngle(h.meridianDistance, fmt)),
];
