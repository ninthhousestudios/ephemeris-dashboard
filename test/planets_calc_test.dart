import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/swisseph.dart';
import 'package:swe_dashboard/core/context_state.dart';
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
        jdUt: 2451545.0,
        iflag: 0,
        origin: Origin.geocentric,
        bodies: [seSun, seMoon],
        getName: (body) => 'Body $body',
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
          if (body == seMoon) throw const SweException('no data for Moon', -1);
          return _result(body);
        };

      final results = computePlanets(
        eph: fake,
        jdUt: 2451545.0,
        iflag: 0,
        origin: Origin.geocentric,
        bodies: [seSun, seMoon],
        getName: (body) => 'Body $body',
      );

      expect(results, hasLength(2));
      expect(results[0].errorMessage, isNull);
      expect(results[1].errorMessage, isNotNull);
      expect(results[1].longitude, isNaN);
    });

    test('auto-adds Earth for heliocentric origin', () {
      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) => _result(body);

      final results = computePlanets(
        eph: fake,
        jdUt: 2451545.0,
        iflag: 0,
        origin: Origin.heliocentric,
        bodies: [seSun],
        getName: (body) => 'Body $body',
      );

      expect(results.map((r) => r.body), contains(seEarth));
    });

    test('does not duplicate Earth if already selected', () {
      final fake = FakeEphemeris()
        ..onCalcUt = (jdUt, body, flags) => _result(body);

      final results = computePlanets(
        eph: fake,
        jdUt: 2451545.0,
        iflag: 0,
        origin: Origin.heliocentric,
        bodies: [seSun, seEarth],
        getName: (body) => 'Body $body',
      );

      final earthCount = results.where((r) => r.body == seEarth).length;
      expect(earthCount, 1);
    });
  });
}
