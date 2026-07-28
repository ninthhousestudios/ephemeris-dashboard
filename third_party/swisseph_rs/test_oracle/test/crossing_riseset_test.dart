// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph/swisseph.dart' as swe;
import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

import 'src/agreement.dart';
import 'src/oracle.dart';

const _searchTolerance = 1e-6;

void main() {
  late Ephemeris eph;
  late Oracle oracle;

  const j2000Ut = JdUt1(2451545.0);
  const j2000Et = JdTt(2451545.0);

  // Berlin: 52.52N, 13.41E
  const berlinLat = 52.52;
  const berlinLon = 13.41;

  setUpAll(() {
    eph = Ephemeris(const EphemerisConfig());
    oracle = Oracle();
  });

  tearDownAll(() {
    eph.close();
    oracle.close();
  });

  // -----------------------------------------------------------------------
  // Solar crossing (task /32)
  // -----------------------------------------------------------------------

  group('solcrossUt', () {
    test('Sun crosses 0° Aries forward', () {
      final actual = eph.solcrossUt(0, j2000Ut, CalcFlags.none);
      final expected = oracle.solcrossUt(0, j2000Ut.value, 0);
      expectAgreement(
        'jd',
        actual,
        expected,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });

    test('Sun crosses 90° forward', () {
      final actual = eph.solcrossUt(90, j2000Ut, CalcFlags.none);
      final expected = oracle.solcrossUt(90, j2000Ut.value, 0);
      expectAgreement(
        'jd',
        actual,
        expected,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });
  });

  group('solcross (ET)', () {
    test('Sun crosses 180° forward', () {
      final actual = eph.solcross(180, j2000Et, CalcFlags.none);
      final expected = oracle.solcross(180, j2000Et.value, 0);
      expectAgreement(
        'jd',
        actual,
        expected,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });
  });

  // -----------------------------------------------------------------------
  // Moon crossing (task /32)
  // -----------------------------------------------------------------------

  group('mooncrossUt', () {
    test('Moon crosses 0° forward', () {
      final actual = eph.mooncrossUt(0, j2000Ut, CalcFlags.none);
      final expected = oracle.mooncrossUt(0, j2000Ut.value, 0);
      expectAgreement(
        'jd',
        actual,
        expected,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });
  });

  group('mooncross (ET)', () {
    test('Moon crosses 120° forward', () {
      final actual = eph.mooncross(120, j2000Et, CalcFlags.none);
      final expected = oracle.mooncross(120, j2000Et.value, 0);
      expectAgreement(
        'jd',
        actual,
        expected,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });
  });

  // -----------------------------------------------------------------------
  // Moon node crossing (task /32)
  // -----------------------------------------------------------------------

  group('mooncrossNodeUt', () {
    test('next node crossing — jd, lon, lat', () {
      final actual = eph.mooncrossNodeUt(j2000Ut, CalcFlags.none);
      final expected = oracle.mooncrossNodeUt(j2000Ut.value, 0);
      expectAgreement(
        'jd',
        actual.jd,
        expected.jdUt,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'longitude',
        actual.longitude,
        expected.longitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'latitude',
        actual.latitude,
        expected.latitude,
        AgreementClass.positional,
      );
    });
  });

  group('mooncrossNode (ET)', () {
    test('next node crossing', () {
      final actual = eph.mooncrossNode(j2000Et, CalcFlags.none);
      final expected = oracle.mooncrossNode(j2000Et.value, 0);
      expectAgreement(
        'jd',
        actual.jd,
        expected.jdUt,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });
  });

  // -----------------------------------------------------------------------
  // Heliocentric crossing (task /32)
  // -----------------------------------------------------------------------

  group('helioCrossUt', () {
    test('Mars crosses 0° forward', () {
      final actual = eph.helioCrossUt(Body.mars, 0, j2000Ut, CalcFlags.none);
      final expected = oracle.helioCrossUt(
        Body.mars.rawValue,
        0,
        j2000Ut.value,
        0,
        1,
      );
      expectAgreement(
        'jd',
        actual,
        expected,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });

    test('Venus crosses 90° backward', () {
      final actual = eph.helioCrossUt(
        Body.venus,
        90,
        j2000Ut,
        CalcFlags.none,
        dir: -1,
      );
      final expected = oracle.helioCrossUt(
        Body.venus.rawValue,
        90,
        j2000Ut.value,
        0,
        -1,
      );
      expectAgreement(
        'jd',
        actual,
        expected,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });
  });

  group('helioCross (ET)', () {
    test('Jupiter crosses 45° forward', () {
      final actual = eph.helioCross(Body.jupiter, 45, j2000Et, CalcFlags.none);
      final expected = oracle.helioCross(
        Body.jupiter.rawValue,
        45,
        j2000Et.value,
        0,
        1,
      );
      expectAgreement(
        'jd',
        actual,
        expected,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });
  });

  // -----------------------------------------------------------------------
  // Rise/set (task /32)
  // -----------------------------------------------------------------------

  group('riseTrans', () {
    test('Sun rise at Berlin', () {
      final actual = eph.riseTrans(
        j2000Ut,
        Body.sun,
        CalcFlags.none,
        RiseSetFlags.rise,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      final expected = oracle.riseTrans(
        j2000Ut.value,
        Body.sun.rawValue,
        rsmi: swe.seCalcRise,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      expectAgreement(
        'time',
        actual.time,
        expected.transitTime,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });

    test('Sun set at Berlin', () {
      final actual = eph.riseTrans(
        j2000Ut,
        Body.sun,
        CalcFlags.none,
        RiseSetFlags.set,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      final expected = oracle.riseTrans(
        j2000Ut.value,
        Body.sun.rawValue,
        rsmi: swe.seCalcSet,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      expectAgreement(
        'time',
        actual.time,
        expected.transitTime,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });

    test('Moon upper meridian transit', () {
      final actual = eph.riseTrans(
        j2000Ut,
        Body.moon,
        CalcFlags.none,
        RiseSetFlags.mtransit,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      final expected = oracle.riseTrans(
        j2000Ut.value,
        Body.moon.rawValue,
        rsmi: swe.seCalcMTransit,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      expectAgreement(
        'time',
        actual.time,
        expected.transitTime,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });

    test('circumpolar body throws CircumpolarBodyException', () {
      // Sun at North Pole in summer — never sets.
      expect(
        () => eph.riseTrans(
          // mid-June 2000 — Sun above horizon at 90°N
          const JdUt1(2451710.0),
          Body.sun,
          CalcFlags.none,
          RiseSetFlags.set,
          geolon: 0,
          geolat: 90,
        ),
        throwsA(isA<CircumpolarBodyException>()),
      );
    });
  });

  group('riseTransTrueHor', () {
    test('Sun rise with horizon height', () {
      final actual = eph.riseTransTrueHor(
        j2000Ut,
        Body.sun,
        CalcFlags.none,
        RiseSetFlags.rise,
        geolon: berlinLon,
        geolat: berlinLat,
        horhgt: 0.5,
      );
      final expected = oracle.riseTransTrueHor(
        j2000Ut.value,
        Body.sun.rawValue,
        rsmi: swe.seCalcRise,
        geolon: berlinLon,
        geolat: berlinLat,
        horizonHeight: 0.5,
      );
      expectAgreement(
        'time',
        actual.time,
        expected.transitTime,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
    });
  });
}
