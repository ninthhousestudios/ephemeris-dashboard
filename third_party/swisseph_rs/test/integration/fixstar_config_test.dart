// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io' show Platform;

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

void main() {
  const jdUt = JdUt1(2451545.0);
  const star = 'Aldebaran';
  const topo = TopoPosition(
    longitude: -122.4194,
    latitude: 37.7749,
    altitude: 16.0,
  );
  final flags = CalcFlags.speed | CalcFlags.sidereal | CalcFlags.topoctr;

  late String ephePath;

  setUpAll(() {
    final env = Platform.environment['SWE_EPHE_PATH'];
    if (env == null) {
      throw TestFailure(
        'SWE_EPHE_PATH must be set (fixstars need sefstars.txt)',
      );
    }
    ephePath = env;
  });

  group('fixstar2UtWithConfig', () {
    test('override config matches construction config', () {
      const overrideConfig = EphemerisConfig(
        siderealMode: SiderealMode.lahiri,
        topographic: topo,
      );
      final constructed = Ephemeris(
        EphemerisConfig(
          ephePath: ephePath,
          siderealMode: SiderealMode.lahiri,
          topographic: topo,
        ),
      );
      addTearDown(constructed.close);
      final expected = constructed.fixstar2Ut(star, jdUt, flags);

      final plain = Ephemeris(EphemerisConfig(ephePath: ephePath));
      addTearDown(plain.close);
      final actual = plain.fixstar2UtWithConfig(
        star,
        jdUt,
        flags,
        overrideConfig,
      );

      expect(actual.starName, equals(expected.starName));
      expect(actual.longitude, closeTo(expected.longitude, 1e-9));
      expect(actual.latitude, closeTo(expected.latitude, 1e-9));
      expect(actual.distance, closeTo(expected.distance, 1e-12));
      expect(actual.longitudeSpeed, closeTo(expected.longitudeSpeed, 1e-9));
    });
  });

  group('fixstar2WithConfig', () {
    test('override config matches construction config', () {
      const overrideConfig = EphemerisConfig(
        siderealMode: SiderealMode.lahiri,
        topographic: topo,
      );
      final constructed = Ephemeris(
        EphemerisConfig(
          ephePath: ephePath,
          siderealMode: SiderealMode.lahiri,
          topographic: topo,
        ),
      );
      addTearDown(constructed.close);
      final deltaT = constructed.deltaT(jdUt);
      final jdTt = JdTt(jdUt.value + deltaT);
      final expected = constructed.fixstar2(star, jdTt, flags);

      final plain = Ephemeris(EphemerisConfig(ephePath: ephePath));
      addTearDown(plain.close);
      final actual = plain.fixstar2WithConfig(
        star,
        jdTt,
        flags,
        overrideConfig,
      );

      expect(actual.starName, equals(expected.starName));
      expect(actual.longitude, closeTo(expected.longitude, 1e-9));
      expect(actual.latitude, closeTo(expected.latitude, 1e-9));
      expect(actual.distance, closeTo(expected.distance, 1e-12));
      expect(actual.longitudeSpeed, closeTo(expected.longitudeSpeed, 1e-9));
    });
  });
}
