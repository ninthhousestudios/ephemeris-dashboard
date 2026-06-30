import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/swisseph.dart';
import 'package:swe_dashboard/core/ephemeris/swe_symbol_catalog.dart';
import 'package:swe_dashboard/core/ephemeris/trace_model.dart';
import 'package:swe_dashboard/core/ephemeris/tracing_swiss_eph.dart';

void main() {
  late SwissEph swe;
  late TracingSwissEph tracing;

  setUp(() {
    swe = SwissEph.find();
    tracing = TracingSwissEph(swe);
  });

  tearDown(() {
    swe.close();
  });

  group('calcUt', () {
    test('records CallEntry with correct function name and args', () {
      tracing.calcUt(2460412.5, seSun, seFlgSwiEph | seFlgSpeed);

      expect(tracing.entries, hasLength(1));
      final entry = tracing.entries.first;
      expect(entry.functionName, equals(TracedFunction.sweCalcUt));
      expect(entry.args['jdUt'], equals(2460412.5));
      expect(entry.args['body'], equals(seSun));
      expect(entry.args['iflag'], equals(seFlgSwiEph | seFlgSpeed));
      expect(entry.category, equals(CallCategory.calc));
      expect(entry.errorMessage, isNull);
    });

    test('returns same result as delegate', () {
      final direct = swe.calcUt(2460412.5, seSun, seFlgSwiEph | seFlgSpeed);
      swe.close();
      swe = SwissEph.find();
      tracing = TracingSwissEph(swe);
      final traced = tracing.calcUt(2460412.5, seSun, seFlgSwiEph | seFlgSpeed);

      expect(traced.longitude, equals(direct.longitude));
      expect(traced.latitude, equals(direct.latitude));
    });

    test('records error and rethrows on failure', () {
      expect(
        () => tracing.calcUt(2460412.5, -99, seFlgSwiEph),
        throwsA(isA<SweException>()),
      );

      expect(tracing.entries, hasLength(1));
      expect(tracing.entries.first.errorMessage, isNotNull);
    });
  });

  group('setup call tracing', () {
    test('setSidMode records entry with context category', () {
      tracing.setSidMode(1);

      expect(tracing.entries, hasLength(1));
      final entry = tracing.entries.first;
      expect(entry.functionName, equals(TracedFunction.sweSetSidMode));
      expect(entry.args['sidMode'], equals(1));
      expect(entry.category, equals(CallCategory.context));
    });

    test('setTopo records entry with context category', () {
      tracing.setTopo(-0.1278, 51.5074, 0);

      expect(tracing.entries, hasLength(1));
      final entry = tracing.entries.first;
      expect(entry.functionName, equals(TracedFunction.sweSetTopo));
      expect(entry.args['geolon'], equals(-0.1278));
      expect(entry.args['geolat'], equals(51.5074));
      expect(entry.category, equals(CallCategory.context));
    });

    test('setJplFile records entry with context category', () {
      tracing.setJplFile('de441.eph');

      expect(tracing.entries, hasLength(1));
      final entry = tracing.entries.first;
      expect(entry.functionName, equals(TracedFunction.sweSetJplFile));
      expect(entry.args['filename'], equals('de441.eph'));
      expect(entry.category, equals(CallCategory.context));
    });

    test('setEphePath records entry with context category', () {
      tracing.setEphePath('/tmp/ephe');

      expect(tracing.entries, hasLength(1));
      final entry = tracing.entries.first;
      expect(entry.functionName, equals(TracedFunction.sweSetEphePath));
      expect(entry.args['path'], equals('/tmp/ephe'));
      expect(entry.category, equals(CallCategory.context));
    });

    test('setup entries use tab tag in traceId', () {
      tracing.setTabTag('planets');
      tracing.setSidMode(1);

      expect(tracing.entries.first.traceId, equals('planets:set_sid_mode'));
    });
  });
}
