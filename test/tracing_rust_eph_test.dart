// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/swisseph.dart';
import 'package:swe_dashboard/core/ephemeris/trace_model.dart';
import 'package:swe_dashboard/core/ephemeris/tracing_rust_eph.dart';
import 'package:swe_dashboard/core/ephemeris/tracing_swiss_eph.dart';
import 'package:swe_dashboard/core/ephemeris/swe_symbol_catalog.dart';

void main() {
  late TracingRustEph rust;
  late TracingSwissEph legacy;

  setUp(() {
    rust = TracingRustEph();
    legacy = TracingSwissEph(SwissEph.find());
  });

  tearDown(() {
    rust.close();
  });

  // -------------------------------------------------------------------------
  // Trace recording tests
  // -------------------------------------------------------------------------

  group('trace recording', () {
    test('context setters record entries with correct category', () {
      rust.setTabTag('test');
      rust.setEphePath('/tmp/ephe');
      rust.setSidMode(1, t0: 0, ayanT0: 0);
      rust.setTopo(13.41, 52.52, 34.0);
      rust.setJplFile('de431.eph');

      expect(rust.entries.length, 4);
      expect(
        rust.entries.every((e) => e.category == CallCategory.context),
        isTrue,
      );
      expect(rust.entries[0].functionName, TracedFunction.sweSetEphePath);
      expect(rust.entries[1].functionName, TracedFunction.sweSetSidMode);
      expect(rust.entries[2].functionName, TracedFunction.sweSetTopo);
      expect(rust.entries[3].functionName, TracedFunction.sweSetJplFile);
    });

    test('calcUt records calc entry with traceId', () {
      rust.setTabTag('planets');
      rust.clearEntries();
      rust.calcUt(2451545.0, 0, 256); // Sun, speed flag

      expect(rust.entries.length, 1);
      final entry = rust.entries.first;
      expect(entry.functionName, TracedFunction.sweCalcUt);
      expect(entry.category, CallCategory.calc);
      expect(entry.traceId, 'planets:calc_ut:body=0');
      expect(entry.result, isA<CalcResult>());
      expect(entry.returnFlag, isNotNull);
      expect(entry.errorMessage, isNull);
    });

    test('clearEntries empties the trace', () {
      rust.calcUt(2451545.0, 0, 256);
      expect(rust.entries, isNotEmpty);
      rust.clearEntries();
      expect(rust.entries, isEmpty);
    });

    test('error path records errorMessage', () {
      expect(() => rust.calcUt(2451545.0, -999, 0), throwsA(anything));
      expect(rust.entries.last.errorMessage, isNotNull);
      expect(rust.entries.last.result, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Differential tests: TracingRustEph vs TracingSwissEph
  // -------------------------------------------------------------------------

  group('differential: tropical', () {
    const jd = 2451545.0; // J2000
    const flags = 256; // seFlgSpeed

    test('calcUt Sun', () {
      final rResult = rust.calcUt(jd, 0, flags);
      final lResult = legacy.calcUt(jd, 0, flags);

      expect(rResult.longitude, closeTo(lResult.longitude, 1e-9));
      expect(rResult.latitude, closeTo(lResult.latitude, 1e-9));
      expect(rResult.distance, closeTo(lResult.distance, 1e-9));
      expect(rResult.longitudeSpeed, closeTo(lResult.longitudeSpeed, 1e-9));
      expect(rResult.latitudeSpeed, closeTo(lResult.latitudeSpeed, 1e-9));
      expect(rResult.distanceSpeed, closeTo(lResult.distanceSpeed, 1e-9));
    });

    test('calcUt Moon', () {
      final rResult = rust.calcUt(jd, 1, flags);
      final lResult = legacy.calcUt(jd, 1, flags);

      expect(rResult.longitude, closeTo(lResult.longitude, 1e-9));
      expect(rResult.latitude, closeTo(lResult.latitude, 1e-9));
      expect(rResult.distance, closeTo(lResult.distance, 1e-9));
    });

    test('houses Placidus', () {
      final rResult = rust.houses(jd, 52.52, 13.41, 0x50); // 'P'
      final lResult = legacy.houses(jd, 52.52, 13.41, 0x50);

      for (var i = 1; i <= 12; i++) {
        expect(
          rResult.cusps[i],
          closeTo(lResult.cusps[i], 1e-8),
          reason: 'cusp $i',
        );
      }
      expect(rResult.ascendant, closeTo(lResult.ascendant, 1e-8));
      expect(rResult.mc, closeTo(lResult.mc, 1e-8));
    });

    test('deltat', () {
      expect(rust.deltat(jd), closeTo(legacy.deltat(jd), 1e-12));
    });

    test('sidTime', () {
      expect(rust.sidTime(jd), closeTo(legacy.sidTime(jd), 1e-9));
    });

    test('sidTime0', () {
      expect(
        rust.sidTime0(jd, 23.4393, -0.001),
        closeTo(legacy.sidTime0(jd, 23.4393, -0.001), 1e-9),
      );
    });

    test('timeEqu', () {
      expect(rust.timeEqu(jd), closeTo(legacy.timeEqu(jd), 1e-12));
    });

    test('lmtToLat', () {
      expect(
        rust.lmtToLat(jd, 13.41),
        closeTo(legacy.lmtToLat(jd, 13.41), 1e-12),
      );
    });

    test('latToLmt', () {
      expect(
        rust.latToLmt(jd, 13.41),
        closeTo(legacy.latToLmt(jd, 13.41), 1e-12),
      );
    });

    test('cotrans', () {
      final rResult = rust.cotrans(120.0, 5.0, 1.0, 23.44);
      final lResult = legacy.cotrans(120.0, 5.0, 1.0, 23.44);

      expect(rResult.lon, closeTo(lResult.lon, 1e-9));
      expect(rResult.lat, closeTo(lResult.lat, 1e-9));
      expect(rResult.dist, closeTo(lResult.dist, 1e-9));
    });

    test('refrac true-to-app', () {
      expect(
        rust.refrac(10.0, 1013.25, 15.0, 0),
        closeTo(legacy.refrac(10.0, 1013.25, 15.0, 0), 1e-9),
      );
    });

    test('refrac app-to-true', () {
      expect(
        rust.refrac(10.0, 1013.25, 15.0, 1),
        closeTo(legacy.refrac(10.0, 1013.25, 15.0, 1), 1e-9),
      );
    });
  });

  group('differential: sidereal (Lahiri)', () {
    const jd = 2451545.0;
    const flags = 256 | 65536; // seFlgSpeed | seFlgSidereal

    setUp(() {
      rust.setSidMode(1); // Lahiri
      legacy.setSidMode(1);
    });

    test('calcUt Sun sidereal', () {
      final rResult = rust.calcUt(jd, 0, flags);
      final lResult = legacy.calcUt(jd, 0, flags);

      expect(rResult.longitude, closeTo(lResult.longitude, 1e-9));
      expect(rResult.latitude, closeTo(lResult.latitude, 1e-9));
    });

    test('getAyanamsaUt', () {
      expect(rust.getAyanamsaUt(jd), closeTo(legacy.getAyanamsaUt(jd), 1e-9));
    });

    test('getAyanamsaExUt', () {
      final rResult = rust.getAyanamsaExUt(jd, flags);
      final lResult = legacy.getAyanamsaExUt(jd, flags);

      expect(rResult.ayanamsa, closeTo(lResult.ayanamsa, 1e-9));
    });
  });

  group('differential: topocentric', () {
    const jd = 2451545.0;
    const flags = 256 | 32768; // seFlgSpeed | seFlgTopoctr

    setUp(() {
      rust.setTopo(13.41, 52.52, 34.0);
      legacy.setTopo(13.41, 52.52, 34.0);
    });

    test('calcUt Moon topocentric', () {
      final rResult = rust.calcUt(jd, 1, flags);
      final lResult = legacy.calcUt(jd, 1, flags);

      expect(rResult.longitude, closeTo(lResult.longitude, 1e-7));
      expect(rResult.latitude, closeTo(lResult.latitude, 1e-7));
      expect(rResult.distance, closeTo(lResult.distance, 1e-7));
    });
  });
}
