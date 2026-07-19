// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/context_state.dart' show EpheSource;
import 'package:swe_dashboard/core/ephemeris/applied_globals.dart';
import 'package:swe_dashboard/core/ephemeris/swe_symbol_catalog.dart';
import 'package:swe_dashboard/core/ephemeris/tracing_rust_eph.dart';

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
      final tropResult = runner.tracing.calcUt(2460412.5, seSun, seFlgSpeed);
      runner.traceEntries.clear();

      runner.apply(sidereal);
      final sidResult = runner.tracing.calcUt(
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
      final engineBefore = runner.tracing.engine;
      runner.apply(globals);
      expect(identical(runner.tracing.engine, engineBefore), isTrue);
    });
  });

  group('tracing exposes TracingRustEph', () {
    test('tracing returns TracingRustEph', () {
      expect(runner.tracing, isA<TracingRustEph>());
    });
  });

  group('trace lifecycle', () {
    test('setTabTag propagates to trace entries', () {
      final globals = AppliedGlobals(
        ephePath: null,
        epheSource: EpheSource.moshier,
        sidMode: null,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      runner.setTabTag('planets');
      runner.apply(globals);
      runner.tracing.calcUt(2460412.5, seSun, seFlgSpeed);

      final calcEntry = runner.traceEntries.firstWhere(
        (e) => e.functionName == TracedFunction.sweCalcUt,
      );
      expect(calcEntry.traceId, startsWith('planets:'));
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
      final traced = runner.tracing.calcUt(
        2460412.5,
        seSun,
        seFlgSwiEph | seFlgSpeed,
      );

      final direct = TracingRustEph();
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
