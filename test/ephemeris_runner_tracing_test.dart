import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/swisseph.dart';
import 'package:swisseph/src/constants.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/ephemeris/applied_globals.dart';
import 'package:swe_dashboard/core/ephemeris/trace_model.dart';
import 'package:swe_dashboard/core/ephemeris/tracing_swiss_eph.dart';

void main() {
  late SwissEph swe;
  late EphemerisRunner runner;

  setUp(() {
    swe = SwissEph.find();
    runner = EphemerisRunner(swe);
  });

  tearDown(() {
    swe.close();
  });

  group('_apply records setup calls', () {
    test('setSidMode is recorded when globals have sidMode', () {
      final globals = AppliedGlobals(
        ephePath: null,
        sidMode: 1,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      runner.run(globals, (eph) => eph.calcUt(2460412.5, seSun, seFlgSpeed));

      final entries = runner.traceEntries;
      expect(
        entries.where((e) => e.functionName == 'swe_set_sid_mode'),
        hasLength(1),
      );
      final setup = entries.firstWhere(
        (e) => e.functionName == 'swe_set_sid_mode',
      );
      expect(setup.category, equals(CallCategory.context));
      expect(setup.args['sidMode'], equals(1));
    });

    test('setTopo is recorded when globals have topo', () {
      final globals = AppliedGlobals(
        ephePath: null,
        sidMode: null,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: (lon: -0.1278, lat: 51.5074, alt: 0.0),
        jplFile: null,
      );

      runner.run(globals, (eph) => eph.calcUt(2460412.5, seSun, seFlgSpeed));

      final entries = runner.traceEntries;
      expect(
        entries.where((e) => e.functionName == 'swe_set_topo'),
        hasLength(1),
      );
    });
  });

  group('body closures receive TracingSwissEph', () {
    test('run passes TracingSwissEph to body', () {
      final globals = AppliedGlobals(
        ephePath: null,
        sidMode: null,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      SwissEph? received;
      runner.run(globals, (eph) {
        received = eph;
        return eph.calcUt(2460412.5, seSun, seFlgSpeed);
      });

      expect(received, isA<TracingSwissEph>());
    });

    test('runScoped passes TracingSwissEph to body', () {
      final globals = AppliedGlobals(
        ephePath: null,
        sidMode: null,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      // Need to run once first so _last is set for the finally block
      runner.run(globals, (eph) => eph.calcUt(2460412.5, seSun, seFlgSpeed));

      SwissEph? received;
      runner.runScoped(
        (eph) {},
        (eph) {
          received = eph;
          return eph.calcUt(2460412.5, seSun, seFlgSpeed);
        },
      );

      expect(received, isA<TracingSwissEph>());
    });
  });

  group('trace lifecycle', () {
    test('clearTrace removes all entries', () {
      final globals = AppliedGlobals(
        ephePath: null,
        sidMode: 1,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      runner.run(globals, (eph) => eph.calcUt(2460412.5, seSun, seFlgSpeed));
      expect(runner.traceEntries, isNotEmpty);

      runner.clearTrace();
      expect(runner.traceEntries, isEmpty);
    });

    test('setTabTag propagates to trace entries', () {
      final globals = AppliedGlobals(
        ephePath: null,
        sidMode: 1,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      runner.setTabTag('planets');
      runner.run(globals, (eph) => eph.calcUt(2460412.5, seSun, seFlgSpeed));

      final calcEntry = runner.traceEntries.firstWhere(
        (e) => e.functionName == 'swe_calc_ut',
      );
      expect(calcEntry.traceId, startsWith('planets:'));
    });
  });

  group('integration: trace ordering', () {
    test('trace contains setup calls before calc calls', () {
      final globals = AppliedGlobals(
        ephePath: null,
        sidMode: 1,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: (lon: -0.1278, lat: 51.5074, alt: 0.0),
        jplFile: null,
      );

      runner.setTabTag('planets');
      runner.run(globals, (eph) => eph.calcUt(2460412.5, seSun, seFlgSpeed));

      final names = runner.traceEntries.map((e) => e.functionName).toList();
      expect(names, containsAllInOrder([
        'swe_set_sid_mode',
        'swe_set_topo',
        'swe_calc_ut',
      ]));
    });

    test('planets-style calc with all setup types in order', () {
      final globals = AppliedGlobals(
        ephePath: '/tmp/ephe',
        sidMode: 1,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: (lon: -0.1278, lat: 51.5074, alt: 0.0),
        jplFile: 'de441.eph',
      );

      runner.setTabTag('planets');
      runner.clearTrace();

      // Simulate planets tab: multiple bodies
      runner.run(globals, (eph) {
        eph.calcUt(2460412.5, seSun, seFlgSpeed);
        eph.calcUt(2460412.5, seMoon, seFlgSpeed);
        return null;
      });

      final names = runner.traceEntries.map((e) => e.functionName).toList();

      // Setup calls come first in _apply order, then calc calls
      expect(names, containsAllInOrder([
        'swe_set_ephe_path',
        'swe_set_sid_mode',
        'swe_set_topo',
        'swe_set_jpl_file',
        'swe_calc_ut',
        'swe_calc_ut',
      ]));

      // All entries tagged with 'planets'
      expect(
        runner.traceEntries.every((e) => e.traceId.startsWith('planets:')),
        isTrue,
      );
    });

    test('values match direct SwissEph calculation', () {
      final globals = AppliedGlobals(
        ephePath: null,
        sidMode: null,
        userAyanT0: 0,
        userAyanValue: 0,
        topo: null,
        jplFile: null,
      );

      final traced = runner.run(
        globals,
        (eph) => eph.calcUt(2460412.5, seSun, seFlgSwiEph | seFlgSpeed),
      );

      // Compare with a fresh direct call
      final direct = SwissEph.find();
      try {
        final expected =
            direct.calcUt(2460412.5, seSun, seFlgSwiEph | seFlgSpeed);
        expect(traced.longitude, equals(expected.longitude));
        expect(traced.latitude, equals(expected.latitude));
        expect(traced.distance, equals(expected.distance));
      } finally {
        direct.close();
      }
    });
  });
}
