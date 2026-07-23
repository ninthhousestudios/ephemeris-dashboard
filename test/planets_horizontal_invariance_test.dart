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

  test('az/alt are identical across Ecliptic, Equatorial and XYZ modes', () {
    final ecliptic = sun(seFlgSwiEph).horizontal;
    final equatorial = sun(seFlgSwiEph | seFlgEquatorial).horizontal;
    final xyz = sun(seFlgSwiEph | seFlgXyz).horizontal;

    // All three actually produced a frame.
    for (final h in [ecliptic, equatorial, xyz]) {
      expect(h.hasValue, isTrue);
    }

    // Bit-for-bit would be ideal, but the XYZ/Equatorial paths route through a
    // second engine call, so allow sub-arcsecond slack (1e-6°).
    const tol = 1e-6;
    for (final other in [equatorial, xyz]) {
      expect(other.azimuth, closeTo(ecliptic.azimuth, tol), reason: 'azimuth');
      expect(
        other.trueAltitude,
        closeTo(ecliptic.trueAltitude, tol),
        reason: 'true altitude',
      );
      expect(
        other.apparentAltitude,
        closeTo(ecliptic.apparentAltitude, tol),
        reason: 'apparent altitude',
      );
      expect(
        other.zenithDistance,
        closeTo(ecliptic.zenithDistance, tol),
        reason: 'zenith distance',
      );
      expect(
        other.meridianDistance,
        closeTo(ecliptic.meridianDistance, tol),
        reason: 'meridian distance',
      );
    }
  });
}
