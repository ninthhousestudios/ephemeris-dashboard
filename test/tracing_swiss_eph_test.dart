import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/swisseph.dart';
import 'package:swisseph/src/constants.dart';
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
      expect(entry.functionName, equals('swe_calc_ut'));
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

  group('untraced methods forward correctly', () {
    test('getPlanetName forwards without recording', () {
      final name = tracing.getPlanetName(seSun);
      expect(name, equals('Sun'));
      expect(tracing.entries, isEmpty);
    });
  });
}
