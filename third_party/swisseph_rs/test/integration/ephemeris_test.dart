// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io' show Platform;

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

void main() {
  group('Ephemeris lifecycle', () {
    test('constructs with Moshier (no files needed)', () {
      final eph = Ephemeris(const EphemerisConfig());
      addTearDown(eph.close);
    });

    test('close() is idempotent', () {
      final eph = Ephemeris(const EphemerisConfig());
      eph.close();
      eph.close();
    });

    test('use-after-close throws StateError', () {
      final eph = Ephemeris(const EphemerisConfig());
      eph.close();
      expect(
        () => eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed),
        throwsStateError,
      );
    });

    test('bad ephePath throws FileNotFoundException', () {
      expect(
        () => Ephemeris(
          const EphemerisConfig(
            ephemerisSource: EphemerisSource.swiss,
            ephePath: '/nonexistent/path',
          ),
        ),
        throwsA(isA<FileNotFoundException>()),
      );
    });
  });

  group('engineVersion', () {
    test('returns non-empty string', () {
      expect(engineVersion, isNotEmpty);
    });
  });

  group('calcUt Sun longitude', () {
    late Ephemeris eph;

    setUp(() {
      eph = Ephemeris(const EphemerisConfig());
    });

    tearDown(() => eph.close());

    test('Moshier: Sun at J2000 epoch', () {
      final result = eph.calcUt(
        const JdUt1(2451545.0),
        Body.sun,
        CalcFlags.speed,
      );
      // Moshier Sun at J2000.0 (2000-01-01 12:00 UT).
      // Positional agreement class: 1e-9°.
      expect(result.longitude, closeTo(280.36891967534336, 1e-9));
      expect(result.longitudeSpeed, closeTo(1.0194320944233946, 1e-9));
      expect(result.distance, closeTo(0.9833276448202026, 1e-12));
    });

    test('Moshier: Sun returns speed components when SPEED flag set', () {
      final result = eph.calcUt(
        const JdUt1(2451545.0),
        Body.sun,
        CalcFlags.speed,
      );
      expect(result.longitudeSpeed, isNot(0.0));
    });

    test('Moshier: Moon returns reasonable longitude', () {
      final result = eph.calcUt(
        const JdUt1(2451545.0),
        Body.moon,
        CalcFlags.speed,
      );
      expect(result.longitude, greaterThanOrEqualTo(0));
      expect(result.longitude, lessThan(360));
      expect(result.longitudeSpeed, closeTo(13.0, 2.0));
    });

    test('Swiss-file: Sun at J2000 epoch', () {
      final ephePath = Platform.environment['SWE_EPHE_PATH'];
      if (ephePath == null) {
        markTestSkipped('SWE_EPHE_PATH not set');
        return;
      }
      final swissEph = Ephemeris(
        EphemerisConfig(
          ephemerisSource: EphemerisSource.swiss,
          ephePath: ephePath,
        ),
      );
      addTearDown(swissEph.close);
      final result = swissEph.calcUt(
        const JdUt1(2451545.0),
        Body.sun,
        CalcFlags.speed | CalcFlags.swiEph,
      );
      // Swiss-file Sun at J2000.0. Positional agreement class: 1e-9°.
      //
      // Data-dependent golden: these values are bit-identical to the C Swiss
      // Ephemeris oracle read against the SE3 / DE441 data release currently
      // in ephe/ (sepl_18.se1, semo_18.se1 header: "Created for Astrodienst
      // in Switzerland 2026/05/26, based on JPL Ephemeris DE441").
      //
      // The previous golden was recorded against the older DE431 files; the
      // DE431 -> DE441 upgrade moved this longitude by ~2.9e-8° (~1e-4"),
      // which exceeds the agreement class. Re-record from the oracle -- do
      // not loosen the tolerance -- if ephe/ is upgraded again.
      expect(result.longitude, closeTo(280.3689186698997, 1e-9));
      expect(result.longitudeSpeed, closeTo(1.0194341629435535, 1e-9));
    });
  });
}
