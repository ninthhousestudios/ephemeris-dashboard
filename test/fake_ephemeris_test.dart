// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephemeris/result_types.dart';
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

  group('named params forwarded', () {
    test('riseTrans forwards geo and atmo params', () {
      double? capturedGeolon;
      double? capturedGeolat;
      double? capturedAtpress;

      fake
        ..onRiseTrans =
            (
              jdUt,
              body, {
              starName,
              epheflag = 4,
              rsmi = 1,
              required geolon,
              required geolat,
              geoalt = 0,
              atpress = 1013.25,
              attemp = 15.0,
            }) {
              capturedGeolon = geolon;
              capturedGeolat = geolat;
              capturedAtpress = atpress;
              return const RiseTransResult(transitTime: 2451545.5);
            }
        ..riseTrans(2451545.0, 0, geolon: 13.4, geolat: 52.5, atpress: 900.0);

      expect(capturedGeolon, 13.4);
      expect(capturedGeolat, 52.5);
      expect(capturedAtpress, 900.0);
    });

    test('solEclipseWhenLoc forwards geo params', () {
      double? capturedGeolat;
      bool? capturedBackward;

      fake
        ..onSolEclipseWhenLoc =
            (
              jdStart,
              flags, {
              required geolon,
              required geolat,
              geoalt = 0,
              backward = false,
            }) {
              capturedGeolat = geolat;
              capturedBackward = backward;
              return const SolarEclipseLocalResult(
                maxEclipse: 0,
                firstContact: 0,
                secondContact: 0,
                thirdContact: 0,
                fourthContact: 0,
                sunrise: 0,
                sunset: 0,
                magnitude: 0,
                diameterRatio: 0,
                obscuration: 0,
                coreShadowKm: 0,
                sunAzimuth: 0,
                sunTrueAltitude: 0,
                sunApparentAltitude: 0,
                moonSunAngle: 0,
                magnitudeNasa: 0,
                sarosSeries: 0,
                sarosMember: 0,
                returnFlag: 0,
              );
            }
        ..solEclipseWhenLoc(
          2451545.0,
          0,
          geolon: 13.4,
          geolat: 52.5,
          backward: true,
        );

      expect(capturedGeolat, 52.5);
      expect(capturedBackward, true);
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
