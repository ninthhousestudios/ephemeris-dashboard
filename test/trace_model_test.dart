import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/calc_context.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/ephemeris/trace_model.dart';

final _testContext = EffectiveContext(
  jdUt: 2460412.5,
  iflag: 258,
  latitude: 51.5074,
  longitude: -0.1278,
  altitude: 0,
  origin: Origin.geocentric,
  zodiacRef: ZodiacRef.tropical,
  eqRef: EqRef.meanEquinox,
  ayanamsa: -1,
  epheSource: EpheSource.swissEph,
);

CallEntry _entry({
  String functionName = 'swe_calc_ut',
  Map<String, Object?> args = const {},
  CallCategory category = CallCategory.calc,
  String traceId = 'planets:calc_ut:body=0',
  String? errorMessage,
}) =>
    CallEntry(
      functionName: functionName,
      args: args,
      category: category,
      traceId: traceId,
      errorMessage: errorMessage,
    );

void main() {
  group('CallEntry', () {
    test('stores function name, args, category, and traceId', () {
      final entry = _entry(
        args: {'jdUt': 2460412.5, 'body': 0, 'iflag': 258},
      );

      expect(entry.functionName, equals('swe_calc_ut'));
      expect(entry.args['body'], equals(0));
      expect(entry.category, equals(CallCategory.calc));
      expect(entry.traceId, equals('planets:calc_ut:body=0'));
      expect(entry.result, isNull);
      expect(entry.returnFlag, isNull);
      expect(entry.errorMessage, isNull);
    });
  });

  group('CallTrace', () {
    test('holds entries and context', () {
      final entries = [
        _entry(functionName: 'swe_set_topo', category: CallCategory.context, traceId: 'ctx:set_topo'),
        _entry(functionName: 'swe_calc_ut', traceId: 'planets:calc_ut:body=0'),
        _entry(functionName: 'swe_calc_ut', traceId: 'planets:calc_ut:body=1'),
      ];
      final now = DateTime.now();
      final trace = CallTrace(entries: entries, context: _testContext, capturedAt: now);

      expect(trace.entries, hasLength(3));
      expect(trace.context, equals(_testContext));
      expect(trace.capturedAt, equals(now));
    });
  });

  group('TraceSlice', () {
    late CallTrace trace;

    setUp(() {
      trace = CallTrace(
        entries: [
          _entry(functionName: 'swe_set_ephe_path', category: CallCategory.flags, traceId: 'ctx:set_ephe_path'),
          _entry(functionName: 'swe_set_sid_mode', category: CallCategory.context, traceId: 'ctx:set_sid_mode'),
          _entry(functionName: 'swe_set_topo', category: CallCategory.context, traceId: 'ctx:set_topo'),
          _entry(functionName: 'swe_calc_ut', category: CallCategory.calc, traceId: 'planets:calc_ut:body=0'),
          _entry(functionName: 'swe_calc_ut', category: CallCategory.calc, traceId: 'planets:calc_ut:body=1'),
          _entry(functionName: 'swe_calc_ut', category: CallCategory.calc, traceId: 'houses:calc_ut:body=0'),
          _entry(functionName: 'swe_close', category: CallCategory.teardown, traceId: 'ctx:close'),
        ],
        context: _testContext,
        capturedAt: DateTime.now(),
      );
    });

    test('filters by category', () {
      final slice = trace.sliceByCategory(CallCategory.context);
      expect(slice.entries, hasLength(2));
      expect(slice.entries.every((e) => e.category == CallCategory.context), isTrue);
    });

    test('filters by traceId', () {
      final slice = trace.sliceByTraceId('planets:calc_ut:body=0');
      expect(slice.entries, hasLength(1));
      expect(slice.entries.first.traceId, equals('planets:calc_ut:body=0'));
    });

    test('filters by tab tag', () {
      final slice = trace.sliceByTab('planets');
      expect(slice.entries, hasLength(2));
      expect(slice.entries.every((e) => e.traceId.startsWith('planets:')), isTrue);
    });

    test('preserves context through filtering', () {
      final slice = trace.sliceByCategory(CallCategory.calc);
      expect(slice.context, equals(_testContext));
    });

    test('returns empty slice for no matches', () {
      final slice = trace.sliceByTab('nonexistent');
      expect(slice.entries, isEmpty);
    });
  });
}
