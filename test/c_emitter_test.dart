// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/core/ephemeris/swe_symbol_catalog.dart';
import 'package:swe_dashboard/core/ephemeris/trace_model.dart';
import 'package:swe_dashboard/core/ephemeris/code_emitter.dart';

void main() {
  group('CEmitter metadata', () {
    test('has correct language properties', () {
      const emitter = CEmitter();
      expect(emitter.languageId, equals('c'));
      expect(emitter.displayName, equals('C'));
      expect(emitter.fileExtension, equals('.c'));
    });
  });

  group('emitSnippet', () {
    const emitter = CEmitter();

    test('emits swe_calc_ut with symbolic body and flags', () {
      final entry = CallEntry(
        functionName: TracedFunction.sweCalcUt,
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

      expect(snippet, contains('double xx[6]'));
      expect(snippet, contains('char serr[256]'));
      expect(snippet, contains('swe_calc_ut('));
      expect(snippet, contains('2460412.5'));
      expect(snippet, contains('SE_SUN'));
      expect(snippet, contains('SEFLG_SWIEPH'));
      expect(snippet, contains('SEFLG_SPEED'));
      // Must NOT contain raw numeric 0 for the body
      expect(snippet, isNot(contains('swe_calc_ut(2460412.5, 0,')));
    });

    test('uses symbolic flag decomposition with pipe', () {
      final entry = CallEntry(
        functionName: TracedFunction.sweCalcUt,
        args: {
          'jdUt': 2460412.5,
          'body': seSun,
          'iflag': seFlgSwiEph | seFlgSpeed,
        },
        category: CallCategory.calc,
        traceId: 'planets:calc_ut:body=0',
        returnFlag: seFlgSwiEph | seFlgSpeed,
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('SEFLG_SWIEPH | SEFLG_SPEED'));
    });

    test('includes // returns: annotation with result values', () {
      final entry = CallEntry(
        functionName: TracedFunction.sweCalcUt,
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
      expect(snippet, contains('// returns:'));
      expect(snippet, contains('123.456789'));
    });

    test('emits // Error: for errored calls', () {
      final entry = CallEntry(
        functionName: TracedFunction.sweCalcUt,
        args: {'jdUt': 2460412.5, 'body': -99, 'iflag': seFlgSwiEph},
        category: CallCategory.calc,
        traceId: 'planets:calc_ut:body=-99',
        errorMessage: 'illegal planet number',
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('// Error:'));
      expect(snippet, contains('illegal planet number'));
    });

    test('emits setup calls as C function calls', () {
      final entry = CallEntry(
        functionName: TracedFunction.sweSetSidMode,
        args: {'sidMode': seSidmLahiri, 't0': 0.0, 'ayanT0': 0.0},
        category: CallCategory.context,
        traceId: 'planets:set_sid_mode',
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('swe_set_sid_mode('));
      expect(snippet, contains('SE_SIDM_LAHIRI'));
    });

    test('emits swe_set_topo with coordinate values', () {
      final entry = CallEntry(
        functionName: TracedFunction.sweSetTopo,
        args: {'geolon': -0.1278, 'geolat': 51.5074, 'geoalt': 0.0},
        category: CallCategory.context,
        traceId: 'planets:set_topo',
      );

      final snippet = emitter.emitSnippet(entry);
      expect(snippet, contains('swe_set_topo('));
      expect(snippet, contains('-0.1278'));
      expect(snippet, contains('51.5074'));
    });

    test('falls back to numeric when body unknown', () {
      final entry = CallEntry(
        functionName: TracedFunction.sweCalcUt,
        args: {
          'jdUt': 2460412.5,
          'body': 10099,
          'iflag': seFlgSwiEph | seFlgSpeed,
        },
        category: CallCategory.calc,
        traceId: 'planets:calc_ut:body=10099',
        returnFlag: seFlgSwiEph | seFlgSpeed,
      );

      final snippet = emitter.emitSnippet(entry);
      // Asteroid — no symbolic name, should use SE_AST_OFFSET + N or raw number
      expect(snippet, contains('10099'));
    });
  });

  group('emitSection', () {
    const emitter = CEmitter();

    test('includes header comment with metadata', () {
      final entries = [
        CallEntry(
          functionName: TracedFunction.sweSetSidMode,
          args: {'sidMode': seSidmLahiri, 't0': 0.0, 'ayanT0': 0.0},
          category: CallCategory.context,
          traceId: 'planets:set_sid_mode',
        ),
        CallEntry(
          functionName: TracedFunction.sweCalcUt,
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
        metadata: {
          'JD': 2460412.5,
          'Date/Time': '2024-03-25 12:00:00 UTC',
          'Location': '51.5074°N, 0.1278°W',
          'Ephemeris': 'Swiss Ephemeris',
          'Ayanamsa': 'Lahiri',
        },
      );

      expect(section, contains('JD:'));
      expect(section, contains('2460412.5'));
      expect(section, contains('Swiss Ephemeris'));
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
