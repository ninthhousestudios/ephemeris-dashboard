import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/src/constants.dart';
import 'package:swe_dashboard/core/ephemeris/trace_model.dart';
import 'package:swe_dashboard/core/ephemeris/code_emitter.dart';

void main() {
  group('DartEmitter metadata', () {
    test('has correct language properties', () {
      const emitter = DartEmitter();
      expect(emitter.languageId, equals('dart'));
      expect(emitter.displayName, equals('Dart'));
      expect(emitter.fileExtension, equals('.dart'));
    });
  });

  group('emitSnippet', () {
    const emitter = DartEmitter();

    test('emits calcUt with Dart method name and symbolic constants', () {
      final entry = CallEntry(
        functionName: 'swe_calc_ut',
        args: {
          'jdUt': 2460412.5,
          'body': seSun,
          'iflag': seFlgSwiEph | seFlgSpeed,
        },
        category: CallCategory.calc,
        traceId: 'planets:calc_ut:body=0',
        returnFlag: seFlgSwiEph | seFlgSpeed,
        result: _FakeCalcResult(
          longitude: 123.456789,
          latitude: 0.000123,
          distance: 1.012345,
          longitudeSpeed: 0.953,
          latitudeSpeed: 0.0,
          distanceSpeed: -0.0001,
        ),
      );

      final snippet = emitter.emitSnippet(entry);

      expect(snippet, contains('swe.calcUt('));
      expect(snippet, contains('2460412.5'));
      expect(snippet, contains('seSun'));
      expect(snippet, contains('seFlgSwiEph'));
      expect(snippet, contains('seFlgSpeed'));
      expect(snippet, isNot(contains('SE_SUN')));
      expect(snippet, isNot(contains('SEFLG_')));
      expect(snippet, contains('// returns:'));
      expect(snippet, contains('123.456789'));
    });

    test('emits setSidMode with Dart constant names', () {
      final entry = CallEntry(
        functionName: 'swe_set_sid_mode',
        args: {'sidMode': seSidmLahiri, 't0': 0.0, 'ayanT0': 0.0},
        category: CallCategory.context,
        traceId: 'planets:set_sid_mode',
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('swe.setSidMode('));
      expect(snippet, contains('seSidmLahiri'));
      expect(snippet, isNot(contains('SE_SIDM_LAHIRI')));
    });

    test('emits setTopo with Dart method name', () {
      final entry = CallEntry(
        functionName: 'swe_set_topo',
        args: {'geolon': -0.1278, 'geolat': 51.5074, 'geoalt': 0.0},
        category: CallCategory.context,
        traceId: 'planets:set_topo',
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('swe.setTopo('));
      expect(snippet, contains('-0.1278'));
      expect(snippet, contains('51.5074'));
    });

    test('emits setEphePath with Dart method name', () {
      final entry = CallEntry(
        functionName: 'swe_set_ephe_path',
        args: {'path': '/usr/share/ephe'},
        category: CallCategory.context,
        traceId: 'planets:set_ephe_path',
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('swe.setEphePath('));
      expect(snippet, contains('/usr/share/ephe'));
    });

    test('emits houses with Dart method name', () {
      final entry = CallEntry(
        functionName: 'swe_houses',
        args: {
          'jdUt': 2460412.5,
          'geolat': 51.5074,
          'geolon': -0.1278,
          'hsys': 80, // 'P' = Placidus
        },
        category: CallCategory.calc,
        traceId: 'houses:houses:hsys=80',
        result: 'ok',
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('swe.houses('));
    });

    test('emits fixstar2Ut with Dart method name', () {
      final entry = CallEntry(
        functionName: 'swe_fixstar2_ut',
        args: {
          'star': 'Aldebaran',
          'jdUt': 2460412.5,
          'iflag': seFlgSwiEph | seFlgSpeed,
        },
        category: CallCategory.calc,
        traceId: 'stars:fixstar2_ut:star=Aldebaran',
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('swe.fixstar2Ut('));
      expect(snippet, contains('Aldebaran'));
    });

    test('emits error annotation', () {
      final entry = CallEntry(
        functionName: 'swe_calc_ut',
        args: {'jdUt': 2460412.5, 'body': -99, 'iflag': seFlgSwiEph},
        category: CallCategory.calc,
        traceId: 'planets:calc_ut:body=-99',
        errorMessage: 'illegal planet number',
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('// Error:'));
      expect(snippet, contains('illegal planet number'));
    });
  });

  group('emitSection', () {
    const emitter = DartEmitter();

    test('includes header comment with metadata', () {
      final entries = [
        CallEntry(
          functionName: 'swe_set_sid_mode',
          args: {'sidMode': seSidmLahiri, 't0': 0.0, 'ayanT0': 0.0},
          category: CallCategory.context,
          traceId: 'planets:set_sid_mode',
        ),
        CallEntry(
          functionName: 'swe_calc_ut',
          args: {
            'jdUt': 2460412.5,
            'body': seSun,
            'iflag': seFlgSwiEph | seFlgSpeed,
          },
          category: CallCategory.calc,
          traceId: 'planets:calc_ut:body=0',
          returnFlag: seFlgSwiEph | seFlgSpeed,
        ),
      ];

      final section = emitter.emitSection(
        entries,
        metadata: {'JD': 2460412.5, 'Ephemeris': 'Swiss Ephemeris'},
      );

      expect(section, contains('JD:'));
      expect(section, contains('2460412.5'));
      expect(section, contains('swe.setSidMode('));
      expect(section, contains('swe.calcUt('));
    });
  });

  group('emitProgram', () {
    const emitter = DartEmitter();

    test('produces a standalone Dart program', () {
      final entries = [
        CallEntry(
          functionName: 'swe_set_ephe_path',
          args: {'path': '/usr/share/ephe'},
          category: CallCategory.context,
          traceId: 'planets:set_ephe_path',
        ),
        CallEntry(
          functionName: 'swe_calc_ut',
          args: {
            'jdUt': 2460412.5,
            'body': seSun,
            'iflag': seFlgSwiEph | seFlgSpeed,
          },
          category: CallCategory.calc,
          traceId: 'planets:calc_ut:body=0',
          returnFlag: seFlgSwiEph | seFlgSpeed,
        ),
      ];

      final program = emitter.emitProgram(entries);

      expect(program, contains("import 'package:swisseph/swisseph.dart'"));
      expect(program, contains('void main()'));
      expect(program, contains('SwissEph()'));
      expect(program, contains('swe.close()'));
      expect(program, contains('swe.setEphePath('));
      expect(program, contains('swe.calcUt('));
    });
  });
}

class _FakeCalcResult {
  _FakeCalcResult({
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.longitudeSpeed,
    required this.latitudeSpeed,
    required this.distanceSpeed,
  });

  final double longitude;
  final double latitude;
  final double distance;
  final double longitudeSpeed;
  final double latitudeSpeed;
  final double distanceSpeed;
}
