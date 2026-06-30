import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/swisseph.dart';
import 'package:swe_dashboard/core/ephemeris/ephemeris.dart';
import 'package:swe_dashboard/core/ephemeris/fake_ephemeris.dart';

void main() {
  late FakeEphemeris fake;

  setUp(() {
    fake = FakeEphemeris();
  });

  test('implements Ephemeris', () {
    expect(fake, isA<Ephemeris>());
  });

  group('context setters', () {
    test('record calls for assertion', () {
      fake.setSidMode(1);
      fake.setTopo(13.4, 52.5, 0);
      fake.setEphePath('/ephe');
      fake.setJplFile('jplde431.eph');

      expect(fake.contextCalls, hasLength(4));
      expect(fake.contextCalls[0].method, 'setSidMode');
      expect(fake.contextCalls[0].args['sidMode'], 1);
      expect(fake.contextCalls[1].method, 'setTopo');
      expect(fake.contextCalls[1].args['geolon'], 13.4);
      expect(fake.contextCalls[2].method, 'setEphePath');
      expect(fake.contextCalls[3].method, 'setJplFile');
    });

    test('setSidMode records t0 and ayanT0', () {
      fake.setSidMode(255, t0: 2451545.0, ayanT0: 23.5);
      expect(fake.contextCalls.first.args['t0'], 2451545.0);
      expect(fake.contextCalls.first.args['ayanT0'], 23.5);
    });
  });

  group('scripted calculation methods', () {
    test('calcUt returns scripted value', () {
      fake.onCalcUt = (jdUt, body, flags) => CalcResult(
        longitude: 120.5,
        latitude: 1.2,
        distance: 1.01,
        longitudeSpeed: 0.95,
        latitudeSpeed: 0.01,
        distanceSpeed: -0.001,
        returnFlag: flags,
      );

      final r = fake.calcUt(2451545.0, 0, 256);
      expect(r.longitude, 120.5);
      expect(r.returnFlag, 256);
    });

    test('deltat returns scripted value', () {
      fake.onDeltat = (jd) => 0.00074;
      expect(fake.deltat(2451545.0), 0.00074);
    });

    test('sidTime returns scripted value', () {
      fake.onSidTime = (jdUt) => 18.697;
      expect(fake.sidTime(2451545.0), 18.697);
    });

    test('getAyanamsaUt returns scripted value', () {
      fake.onGetAyanamsaUt = (jdUt) => 24.1;
      expect(fake.getAyanamsaUt(2451545.0), 24.1);
    });
  });

  group('unscripted methods', () {
    test('throw UnimplementedError', () {
      expect(() => fake.calcUt(0, 0, 0), throwsUnimplementedError);
      expect(() => fake.houses(0, 0, 0, 0), throwsUnimplementedError);
      expect(() => fake.deltat(0), throwsUnimplementedError);
      expect(() => fake.sidTime(0), throwsUnimplementedError);
      expect(() => fake.solEclipseWhere(0, 0), throwsUnimplementedError);
    });
  });
}
