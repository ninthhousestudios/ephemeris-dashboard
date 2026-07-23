// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Unit-pins the body tabs' horizontal-coordinate wiring (swe-dashboard/69):
/// `includeHorizontal` gates the `azAlt` transform, the ecliptic feed is
/// tropical (sidereal/XYZ stripped), the meridian distance uses GMST, and the
/// whole frame is confined to the geo/topocentric origins. `computePlanets` is
/// the worked example; Other Bodies and Stars share the same
/// `horizontalCoordsOf` helper.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/ephemeris/fake_ephemeris.dart';
import 'package:swe_dashboard/tabs/planets/planets_provider.dart';

CalcResult _calc(int body, int flags) => CalcResult(
  longitude: body * 30.0,
  latitude: 1.0,
  distance: 1.0,
  longitudeSpeed: 0.5,
  latitudeSpeed: 0.01,
  distanceSpeed: -0.001,
  returnFlag: flags,
);

const _fixedAzAlt = AzAltResult(
  azimuth: 123.0,
  trueAltitude: 45.0,
  apparentAltitude: 45.5,
);

List<PlanetResult> _run(
  FakeEphemeris fake, {
  required Origin origin,
  required int iflag,
  bool includeHorizontal = false,
}) => computePlanets(
  eph: fake,
  moment: Moment(ut: 2461041.5, deltaT: 0),
  iflag: iflag,
  origin: origin,
  bodies: [seMars],
  getName: (body) => 'Body $body',
  geolon: 0,
  geolat: 52.5,
  geoalt: 0,
  includeHorizontal: includeHorizontal,
);

void main() {
  group('computePlanets horizontal coordinates', () {
    test('includeHorizontal runs azAlt and fills the frame', () {
      var azCalled = false;
      final fake = FakeEphemeris()
        ..onCalcUt = ((jdUt, body, flags) => _calc(body, flags))
        ..onSidTime =
            ((jdUt) => 6.0) // 6h → 90° of GMST
        ..onAzAlt =
            ((
              jdUt,
              calcFlag, {
              required geolon,
              required geolat,
              geoalt = 0,
              atpress = 1013.25,
              attemp = 15.0,
              required bodyLon,
              required bodyLat,
              bodyDist = 1.0,
            }) {
              azCalled = true;
              return _fixedAzAlt;
            });

      final r = _run(
        fake,
        origin: Origin.geocentric,
        iflag: seFlgSwiEph,
        includeHorizontal: true,
      ).single;

      expect(azCalled, isTrue);
      expect(r.horizontal.hasValue, isTrue);
      expect(r.horizontal.azimuth, 123.0);
      expect(r.horizontal.trueAltitude, 45.0);
      expect(r.horizontal.apparentAltitude, 45.5);
      // Zenith distance = 90 − true altitude.
      expect(r.horizontal.zenithDistance, 45.0);
      // Meridian distance is finite once GMST and RA are in hand.
      expect(r.horizontal.meridianDistance.isNaN, isFalse);
    });

    test('off by default — azAlt is never called', () {
      // onAzAlt / onSidTime left unscripted: touching them would throw.
      final fake = FakeEphemeris()
        ..onCalcUt = ((jdUt, body, flags) => _calc(body, flags));

      final r = _run(
        fake,
        origin: Origin.geocentric,
        iflag: seFlgSwiEph,
      ).single;

      expect(r.horizontal.hasValue, isFalse);
    });

    test('skipped for heliocentric origin even when requested', () {
      final fake = FakeEphemeris()
        ..onCalcUt = ((jdUt, body, flags) => _calc(body, flags));

      final r = _run(
        fake,
        origin: Origin.heliocentric,
        iflag: seFlgSwiEph,
        includeHorizontal: true,
      ).firstWhere((r) => r.body == seMars);

      expect(r.horizontal.hasValue, isFalse);
    });

    test('sidereal/XYZ request feeds azAlt a stripped tropical position', () {
      int? seenEclFlag;
      var tropicalCalcs = 0;
      final fake = FakeEphemeris()
        ..onCalcUt = ((jdUt, body, flags) {
          // The dedicated tropical recalc for the horizontal feed strips
          // sidereal + XYZ (and is not the equatorial calc).
          if (body == seMars &&
              flags & seFlgSidereal == 0 &&
              flags & seFlgXyz == 0 &&
              flags & seFlgEquatorial == 0) {
            tropicalCalcs++;
            seenEclFlag = flags;
          }
          return _calc(body, flags);
        })
        ..onSidTime = ((jdUt) => 6.0)
        ..onAzAlt =
            ((
              jdUt,
              calcFlag, {
              required geolon,
              required geolat,
              geoalt = 0,
              atpress = 1013.25,
              attemp = 15.0,
              required bodyLon,
              required bodyLat,
              bodyDist = 1.0,
            }) => _fixedAzAlt);

      _run(
        fake,
        origin: Origin.geocentric,
        iflag: seFlgSwiEph | seFlgSidereal,
        includeHorizontal: true,
      );

      expect(tropicalCalcs, greaterThan(0));
      expect(seenEclFlag! & seFlgSidereal, 0);
      expect(seenEclFlag! & seFlgXyz, 0);
    });
  });
}
