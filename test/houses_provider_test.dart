// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/display_format.dart';
import 'package:swe_dashboard/core/ephemeris/fake_ephemeris.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/tabs/houses/houses_provider.dart';

CalcResult _calc(double lon, double lat) => CalcResult(
  longitude: lon,
  latitude: lat,
  distance: 1,
  longitudeSpeed: 0,
  latitudeSpeed: 0,
  distanceSpeed: 0,
  returnFlag: 0,
);

HouseResult _houses(double armc) => HouseResult(
  cusps: List<double>.filled(13, 0),
  ascmc: [10, 280, armc, 0, 0, 0, 0, 0],
  returnFlag: 0,
);

void main() {
  group('computeHouses body positions', () {
    test('feeds swe_house_pos armc from ascmc[2], lat, and true obliquity', () {
      final eph = FakeEphemeris();
      final housePosCalls = <List<double>>[];
      final calcFlags = <int>[];

      eph.onHouses = (_, _, _, _) => _houses(114.06);
      eph.onCalcUt = (jd, body, flags) {
        calcFlags.add(flags);
        if (body == seEclNut) return _calc(23.44, 0); // obliquity in longitude
        return _calc(280.57, 0.0002); // any body position
      };
      eph.onHousePos = (armc, geolat, eps, hsys, lon, lat) {
        housePosCalls.add([armc, geolat, eps, hsys.toDouble(), lon, lat]);
        return 3.695;
      };

      final result = computeHouses(
        eph,
        jdUt: 2461041.5,
        lat: 52.5,
        lon: 13.4,
        hsys: 0x50,
        hsysName: 'Placidus',
        bodies: const [seSun],
        // Sidereal must be dropped: handle-free house_pos is tropical.
        iflag: seFlgSwiEph | seFlgSidereal,
        getName: (b) => 'Sun',
      );

      expect(result.bodyPositions, hasLength(1));
      final call = housePosCalls.single;
      expect(call[0], 114.06, reason: 'armc from ascmc[2]');
      expect(call[1], 52.5, reason: 'geolat');
      expect(call[2], 23.44, reason: 'eps = SE_ECL_NUT longitude');
      expect(call[3], 0x50, reason: 'hsys');

      // No calc carried the sidereal bit.
      expect(calcFlags, isNotEmpty);
      expect(calcFlags.every((f) => f & seFlgSidereal == 0), isTrue);

      final sun = result.bodyPositions.single;
      expect(sun.housePos, 3.695);
      expect(sun.houseNumber, 3);
      expect(sun.positionDegrees, closeTo(80.85, 1e-9));
    });

    test('a body whose calc throws becomes an error row, not a failure', () {
      final eph = FakeEphemeris();
      eph.onHouses = (_, _, _, _) => _houses(114.06);
      eph.onCalcUt = (jd, body, flags) {
        if (body == seEclNut) return _calc(23.44, 0);
        if (body == seMoon) throw Exception('missing file');
        return _calc(280.57, 0.0002);
      };
      eph.onHousePos = (_, _, _, _, _, _) => 3.695;

      final result = computeHouses(
        eph,
        jdUt: 2461041.5,
        lat: 52.5,
        lon: 13.4,
        hsys: 0x50,
        hsysName: 'Placidus',
        bodies: const [seSun, seMoon],
        iflag: seFlgSwiEph,
        getName: (b) => 'Body $b',
      );

      expect(result.bodyPositions, hasLength(2));
      expect(result.bodyPositions[0].errorMessage, isNull);
      expect(result.bodyPositions[1].errorMessage, contains('missing file'));
      expect(result.bodyPositions[1].housePos.isNaN, isTrue);
    });

    test('no bodies requested → no house_pos calls, empty positions', () {
      final eph = FakeEphemeris();
      eph.onHouses = (_, _, _, _) => _houses(114.06);
      // onCalcUt / onHousePos deliberately unscripted: must not be reached.

      final result = computeHouses(
        eph,
        jdUt: 2461041.5,
        lat: 52.5,
        lon: 13.4,
        hsys: 0x50,
        hsysName: 'Placidus',
      );

      expect(result.bodyPositions, isEmpty);
    });
  });

  group('housesToExportRows', () {
    test('emits a row per body — the series/export path (AC4)', () {
      final result = HousesCalcResult(
        cusps: List<double>.filled(13, 0),
        ascmc: [10, 280, 114, 0, 0, 0, 0, 0],
        hsys: 0x50,
        hsysName: 'Placidus',
        returnFlag: 0,
        bodyPositions: const [
          BodyHousePos(
            bodyId: 0,
            name: 'Sun',
            longitude: 280.57,
            latitude: 0.0002,
            housePos: 3.695,
          ),
        ],
      );

      final rows = housesToExportRows(result, DisplayFormat.decimal);
      final sun = rows.firstWhere((r) => r.header == 'Sun');
      final labels = sun.fields.map((f) => f.$1);
      expect(labels, containsAll(['House', 'House Pos']));
      expect(sun.fields.firstWhere((f) => f.$1 == 'House').$2, '3');
    });

    test('error body row carries the message, not a bogus house', () {
      final result = HousesCalcResult(
        cusps: List<double>.filled(13, 0),
        ascmc: [10, 280, 114, 0, 0, 0, 0, 0],
        hsys: 0x50,
        hsysName: 'Placidus',
        returnFlag: 0,
        bodyPositions: const [
          BodyHousePos(
            bodyId: 1,
            name: 'Moon',
            longitude: double.nan,
            latitude: double.nan,
            housePos: double.nan,
            errorMessage: 'missing file',
          ),
        ],
      );

      final rows = housesToExportRows(result, DisplayFormat.decimal);
      final moon = rows.firstWhere((r) => r.header == 'Moon');
      expect(moon.fields.firstWhere((f) => f.$1 == 'House').$2, '—');
      expect(
        moon.fields.firstWhere((f) => f.$1 == 'House Pos').$2,
        'missing file',
      );
    });
  });
}
