// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Horizontal coordinates are a *physical* position in the sky: azimuth and
/// altitude cannot change because the user switched the display coordinate
/// grid. This pins that Ecliptic, Equatorial and XYZ modes all produce the
/// identical horizontal frame for the same body, time and place — the
/// regression that the `SE_ECL2HOR` feed being handed raw RA/Dec in Equatorial
/// mode broke (a body-tab bug, root cause: `tropicalEclipticFlag` must strip
/// the equatorial bit, not only sidereal/XYZ).
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;
import 'package:swe_dashboard/core/calculation/flag_masks.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/ephemeris/rust_eph.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/tabs/planets/planets_provider.dart';

void main() {
  late RustEph eph;

  setUp(() {
    eph = RustEph(
      const rs.EphemerisConfig(
        ephemerisSource: rs.EphemerisSource.swiss,
        ephePath: 'assets/ephe',
      ),
    );
  });

  tearDown(() => eph.close());

  // Noblesville, IN — the location in the reported screenshots. Daytime UT so
  // the Sun is well above the horizon (positive altitude), but the invariance
  // holds regardless.
  const geolat = 40.0456;
  const geolon = -86.0086;
  final moment = Moment(ut: 2461041.5 + 0.75, deltaT: 0); // ~18:00 UT

  PlanetResult sun(int iflag) => computePlanets(
    eph: eph,
    moment: moment,
    iflag: iflag,
    origin: Origin.geocentric,
    bodies: [seSun],
    getName: (_) => 'Sun',
    geolon: geolon,
    geolat: geolat,
    geoalt: 0,
    includeHorizontal: true,
  ).single;

  // Every flag that only re-expresses *where the coordinate grid is anchored*.
  // None of them moves the body in the sky, so none may move the horizontal
  // frame. Display modes first (the original three), then the frame flags the
  // locked Zodiac/Equinox references set.
  const frameFlags = <String, int>{
    'Equatorial': seFlgEquatorial,
    'XYZ': seFlgXyz,
    'Sidereal': seFlgSidereal,
    'Mean equinox of date (no nutation)': seFlgNoNut,
    'Mean equinox J2000': seFlgJ2000,
    'Sidereal + Equatorial': seFlgSidereal | seFlgEquatorial,
    'J2000 + Equatorial': seFlgJ2000 | seFlgEquatorial,
    // ICRS skips the ICRS -> dynamical-J2000 frame bias, so precession to date
    // lands on a grid ~17 mas (4.7e-6 deg) off the true equinox of date. Small,
    // but above the tolerance below — and a frame error either way.
    'ICRS': seFlgIcrs,
    'ICRS + Equatorial': seFlgIcrs | seFlgEquatorial,
  };

  // Bit-for-bit would be ideal, but these paths route through a second
  // engine call, so allow sub-arcsecond slack (1e-6°).
  const tol = 1e-6;

  for (final entry in frameFlags.entries) {
    final mode = entry.key;
    test('$mode leaves az/alt and meridian distance unchanged', () {
      final ecliptic = sun(seFlgSwiEph).horizontal;
      expect(ecliptic.hasValue, isTrue);
      expect(ecliptic.meridianDistance.isNaN, isFalse);

      final other = sun(seFlgSwiEph | entry.value).horizontal;
      expect(other.hasValue, isTrue, reason: '$mode produced no frame');
      expect(
        other.azimuth,
        closeTo(ecliptic.azimuth, tol),
        reason: '$mode azimuth',
      );
      expect(
        other.trueAltitude,
        closeTo(ecliptic.trueAltitude, tol),
        reason: '$mode true altitude',
      );
      expect(
        other.apparentAltitude,
        closeTo(ecliptic.apparentAltitude, tol),
        reason: '$mode apparent altitude',
      );
      expect(
        other.zenithDistance,
        closeTo(ecliptic.zenithDistance, tol),
        reason: '$mode zenith distance',
      );
      expect(
        other.meridianDistance,
        closeTo(ecliptic.meridianDistance, tol),
        reason: '$mode meridian distance',
      );
    });
  }

  // The gap that put ICRS in this file: it was a user-exposed frame bit that no
  // row exercised, so nothing noticed when `frameOfDateFlag` failed to strip it
  // and `isFrameOfDate` waved an ICRS position through as already of-date. This
  // makes the matrix's completeness a fact the suite checks rather than
  // something the next person to add a frame bit has to remember.
  test('every equinox-shifting bit has a row of its own', () {
    final covered = frameFlags.values.toSet();
    for (var i = 0; i < 32; i++) {
      final bit = 1 << i;
      if (equinoxShiftMask & bit == 0) continue;
      expect(
        covered,
        contains(bit),
        reason:
            'equinoxShiftMask carries bit $bit with no standalone row in '
            'frameFlags — add one before trusting it is stripped',
      );
    }
  });
}
