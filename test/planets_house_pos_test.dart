// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Unit-pins the Planets tab's house-position wiring (swe-dashboard/58): the
/// swetest recipe (ARMC from `houses`, obliquity from SE_ECL_NUT), that the
/// sidereal bit is stripped from every calc feeding `swe_house_pos`, and that
/// house position is confined to the geo/topocentric origins. The seam's own
/// numeric parity against swetest lives in house_pos_parity_test.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/ephemeris/fake_ephemeris.dart';
import 'package:swe_dashboard/tabs/planets/planets_provider.dart';

const _armc = 123.456;
const _eps = 23.4;
const _placidus = 0x50;

CalcResult _calc(int body, int flags) => CalcResult(
  longitude: body * 30.0,
  latitude: 1.0,
  distance: 1.0,
  longitudeSpeed: 0.5,
  latitudeSpeed: 0.01,
  distanceSpeed: -0.001,
  returnFlag: flags,
);

void main() {
  group('computePlanets house position', () {
    test('includeHousePos runs the swetest recipe and strips sidereal', () {
      var housesCalled = false;
      int? epsFlag;
      double? seenArmc, seenEps, seenLon, seenLat;

      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) {
          // eps comes from calcUt(seEclNut).longitude; the rest are body calcs.
          if (body == seEclNut) {
            epsFlag = flags;
            return CalcResult(
              longitude: _eps,
              latitude: 0,
              distance: 0,
              longitudeSpeed: 0,
              latitudeSpeed: 0,
              distanceSpeed: 0,
              returnFlag: flags,
            );
          }
          return _calc(body, flags);
        }
        ..onHouses = (jdUt, geolat, geolon, hsys) {
          housesCalled = true;
          return const HouseResult(
            cusps: [0, 1, 2],
            ascmc: [10, 20, _armc, 30],
            returnFlag: 0,
          );
        }
        ..onHousePos = (armc, geolat, eps, hsys, bodyLon, bodyLat) {
          seenArmc = armc;
          seenEps = eps;
          seenLon = bodyLon;
          seenLat = bodyLat;
          return 3.5; // house 3, 15° in
        };

      final results = computePlanets(
        eph: fake,
        moment: Moment(ut: 2461041.5, deltaT: 0),
        iflag: seFlgSwiEph | seFlgSidereal,
        origin: Origin.geocentric,
        bodies: [seMars],
        getName: (body) => 'Body $body',
        geolon: 13.4,
        geolat: 52.5,
        geoalt: 0,
        includeHousePos: true,
        hsys: _placidus,
      );

      expect(housesCalled, isTrue);
      expect(results.single.housePos, 3.5);
      expect(seenArmc, _armc);
      expect(seenEps, _eps);
      // Mars tropical position fed to housePos.
      expect(seenLon, seMars * 30.0);
      expect(seenLat, 1.0);
      // The obliquity/tropical calcs feeding house position drop sidereal and
      // XYZ, even though the request asked for sidereal.
      expect(epsFlag! & seFlgSidereal, 0, reason: 'eps must strip sidereal');
      expect(epsFlag! & seFlgXyz, 0, reason: 'eps must strip XYZ');
    });

    test('house position is skipped for heliocentric origin', () {
      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) {
          return _calc(body, flags);
        }
        ..onHouses = (_, _, _, _) {
          return fail('houses must not be called');
        }
        ..onHousePos = (_, _, _, _, _, _) {
          return fail('housePos must not be called');
        };

      final results = computePlanets(
        eph: fake,
        moment: Moment(ut: 2461041.5, deltaT: 0),
        iflag: seFlgSwiEph,
        origin: Origin.heliocentric,
        bodies: [seMars],
        getName: (body) => 'Body $body',
        geolon: 13.4,
        geolat: 52.5,
        geoalt: 0,
        includeHousePos: true,
        hsys: _placidus,
      );

      expect(results.first.housePos, isNaN);
    });

    test('house position is off by default', () {
      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) {
          return _calc(body, flags);
        }
        ..onHousePos = (_, _, _, _, _, _) =>
            fail('housePos must not be called');

      final results = computePlanets(
        eph: fake,
        moment: Moment(ut: 2461041.5, deltaT: 0),
        iflag: seFlgSwiEph,
        origin: Origin.geocentric,
        bodies: [seMars],
        getName: (body) => 'Body $body',
        geolon: 13.4,
        geolat: 52.5,
        geoalt: 0,
      );

      expect(results.single.housePos, isNaN);
    });
  });
}
