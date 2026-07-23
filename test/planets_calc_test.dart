// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/display_format.dart';
import 'package:swe_dashboard/core/ephemeris/fake_ephemeris.dart';
import 'package:swe_dashboard/tabs/planets/planets_provider.dart';

CalcResult _result(int body) => CalcResult(
  longitude: body * 30.0,
  latitude: 1.0,
  distance: 1.0,
  longitudeSpeed: 0.5,
  latitudeSpeed: 0.01,
  distanceSpeed: -0.001,
  returnFlag: 0,
);

void main() {
  group('computePlanets', () {
    test('computes positions via fake Ephemeris', () {
      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) => _result(body);

      final results = computePlanets(
        eph: fake,
        moment: Moment(ut: 2451545.0, deltaT: 0),
        iflag: 0,
        origin: Origin.geocentric,
        bodies: [seSun, seMoon],
        getName: (body) => 'Body $body',
        geolon: 0,
        geolat: 0,
        geoalt: 0,
      );

      expect(results, hasLength(2));
      expect(results[0].longitude, 0.0);
      expect(results[1].longitude, seMoon * 30.0);
      expect(results[0].bodyName, 'Body $seSun');
      expect(results[0].errorMessage, isNull);
    });

    test('per-body SweException captured as errorMessage', () {
      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) {
          if (body == seMoon) {
            throw const InvalidArgException('no data for Moon');
          }
          return _result(body);
        };

      final results = computePlanets(
        eph: fake,
        moment: Moment(ut: 2451545.0, deltaT: 0),
        iflag: 0,
        origin: Origin.geocentric,
        bodies: [seSun, seMoon],
        getName: (body) => 'Body $body',
        geolon: 0,
        geolat: 0,
        geoalt: 0,
      );

      expect(results, hasLength(2));
      expect(results[0].errorMessage, isNull);
      expect(results[1].errorMessage, isNotNull);
      expect(results[1].longitude, isNaN);
    });

    test('errored body exports a single Error field, not NaN quantities', () {
      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) {
          if (body == seMoon) {
            throw const InvalidArgException('no data for Moon');
          }
          return _result(body);
        };

      final results = computePlanets(
        eph: fake,
        moment: Moment(ut: 2451545.0, deltaT: 0),
        iflag: 0,
        origin: Origin.geocentric,
        bodies: [seSun, seMoon],
        getName: (body) => 'Body $body',
        geolon: 0,
        geolat: 0,
        geoalt: 0,
      );

      final rows = planetsToExportRows(results, DisplayFormat.decimal);
      final moonRow = rows.firstWhere((r) => r.header == 'Body $seMoon');
      // The failing body surfaces its message, not quantities formatted from
      // NaN — mirroring the card view (swe-dashboard/71).
      expect(moonRow.fields, hasLength(1));
      expect(moonRow.fields.single.$1, 'Error');
      expect(moonRow.fields.single.$2, contains('no data for Moon'));
      // The healthy body is unaffected.
      final sunRow = rows.firstWhere((r) => r.header == 'Body $seSun');
      expect(sunRow.fields.any((f) => f.$1 == 'Error'), isFalse);
    });

    test('auto-adds Earth for heliocentric origin', () {
      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) => _result(body);

      final results = computePlanets(
        eph: fake,
        moment: Moment(ut: 2451545.0, deltaT: 0),
        iflag: 0,
        origin: Origin.heliocentric,
        bodies: [seSun],
        getName: (body) => 'Body $body',
        geolon: 0,
        geolat: 0,
        geoalt: 0,
      );

      expect(results.map((r) => r.body), contains(seEarth));
    });

    test('does not duplicate Earth if already selected', () {
      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) => _result(body);

      final results = computePlanets(
        eph: fake,
        moment: Moment(ut: 2451545.0, deltaT: 0),
        iflag: 0,
        origin: Origin.heliocentric,
        bodies: [seSun, seEarth],
        getName: (body) => 'Body $body',
        geolon: 0,
        geolat: 0,
        geoalt: 0,
      );

      final earthCount = results.where((r) => r.body == seEarth).length;
      expect(earthCount, 1);
    });
  });
}
