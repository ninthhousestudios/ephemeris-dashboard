// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/context_state.dart' show EpheSource;
import 'package:swe_dashboard/core/ephemeris/applied_globals.dart';
import 'package:swe_dashboard/core/ephemeris/rust_eph.dart';

void main() {
  late EphemerisRunner runner;

  setUp(() {
    runner = EphemerisRunner();
  });

  tearDown(() {
    runner.close();
  });

  group('apply configures engine', () {
    test('apply with sidereal globals produces sidereal results', () {
      final tropical = AppliedGlobals(
        ephePath: null,
        epheSource: EpheSource.moshier,
        sidMode: null,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );
      final sidereal = AppliedGlobals(
        ephePath: null,
        epheSource: EpheSource.moshier,
        sidMode: 1,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      runner.apply(tropical);
      final tropResult = runner.eph.calcUt(2460412.5, seSun, seFlgSpeed);

      runner.apply(sidereal);
      final sidResult = runner.eph.calcUt(
        2460412.5,
        seSun,
        seFlgSpeed | seFlgSidereal,
      );

      expect(tropResult.longitude, isNot(equals(sidResult.longitude)));
    });

    test('apply skips reconfigure when globals unchanged', () {
      final globals = AppliedGlobals(
        ephePath: null,
        epheSource: EpheSource.moshier,
        sidMode: null,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      runner.apply(globals);
      final engineBefore = runner.eph.engine;
      runner.apply(globals);
      expect(identical(runner.eph.engine, engineBefore), isTrue);
    });
  });

  group('exposes RustEph', () {
    test('eph returns RustEph', () {
      expect(runner.eph, isA<RustEph>());
    });
  });

  group('integration: calc values', () {
    test('values match a direct engine calculation', () {
      final globals = AppliedGlobals(
        ephePath: null,
        epheSource: EpheSource.moshier,
        sidMode: null,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      runner.apply(globals);
      final traced = runner.eph.calcUt(
        2460412.5,
        seSun,
        seFlgSwiEph | seFlgSpeed,
      );

      final direct = RustEph();
      try {
        final expected = direct.calcUt(
          2460412.5,
          seSun,
          seFlgSwiEph | seFlgSpeed,
        );
        expect(traced.longitude, equals(expected.longitude));
        expect(traced.latitude, equals(expected.latitude));
        expect(traced.distance, equals(expected.distance));
      } finally {
        direct.close();
      }
    });
  });
}
