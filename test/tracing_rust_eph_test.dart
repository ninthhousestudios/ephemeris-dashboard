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

  // -------------------------------------------------------------------------
  // Differential tests: event/search families (S3)
  // -------------------------------------------------------------------------

  group('differential: crossings', () {
    const jd = 2451545.0;
    const flags = 256;

    test('solCrossUt', () {
      final r = rust.solCrossUt(0, jd, flags);
      final l = legacy.solCrossUt(0, jd, flags);
      expect(r, closeTo(l, 1e-6));
    });

    test('moonCrossUt', () {
      final r = rust.moonCrossUt(0, jd, flags);
      final l = legacy.moonCrossUt(0, jd, flags);
      expect(r, closeTo(l, 1e-6));
    });

    test('moonCrossNodeUt', () {
      final r = rust.moonCrossNodeUt(jd, flags);
      final l = legacy.moonCrossNodeUt(jd, flags);
      expect(r.jdUt, closeTo(l.jdUt, 1e-6));
      expect(r.longitude, closeTo(l.longitude, 1e-6));
      expect(r.latitude, closeTo(l.latitude, 1e-6));
    });

    test('helioCrossUt', () {
      final r = rust.helioCrossUt(2, 0, jd, flags, 1); // Venus
      final l = legacy.helioCrossUt(2, 0, jd, flags, 1);
      expect(r, closeTo(l, 1e-6));
    });
  });

  group('differential: eclipses', () {
    const jd = 2451545.0;
    const flags = 4; // seFlgSwieph

    test('solEclipseWhenGlob', () {
      final r = rust.solEclipseWhenGlob(jd, flags);
      final l = legacy.solEclipseWhenGlob(jd, flags);
      expect(r.maxEclipse, closeTo(l.maxEclipse, 1e-6));
      expect(r.begin, closeTo(l.begin, 1e-6));
      expect(r.end, closeTo(l.end, 1e-6));
      expect(r.returnFlag, l.returnFlag);
    });

    test('solEclipseWhenLoc', () {
      final r = rust.solEclipseWhenLoc(jd, flags, geolon: 13.41, geolat: 52.52);
      final l = legacy.solEclipseWhenLoc(
        jd,
        flags,
        geolon: 13.41,
        geolat: 52.52,
      );
      expect(r.maxEclipse, closeTo(l.maxEclipse, 1e-6));
      expect(r.firstContact, closeTo(l.firstContact, 1e-6));
      expect(r.magnitude, closeTo(l.magnitude, 1e-6));
    });

    test('solEclipseHow', () {
      final when = rust.solEclipseWhenGlob(jd, flags);
      final where = rust.solEclipseWhere(when.maxEclipse, flags);
      final r = rust.solEclipseHow(
        when.maxEclipse,
        flags,
        geolon: where.geolon,
        geolat: where.geolat,
      );
      final l = legacy.solEclipseHow(
        when.maxEclipse,
        flags,
        geolon: where.geolon,
        geolat: where.geolat,
      );
      expect(r.magnitude, closeTo(l.magnitude, 1e-6));
      expect(r.obscuration, closeTo(l.obscuration, 1e-4));
    });

    test('solEclipseWhere', () {
      final when = rust.solEclipseWhenGlob(jd, flags);
      final r = rust.solEclipseWhere(when.maxEclipse, flags);
      final l = legacy.solEclipseWhere(when.maxEclipse, flags);
      expect(r.geolon, closeTo(l.geolon, 1e-6));
      expect(r.geolat, closeTo(l.geolat, 1e-6));
    });

    test('lunEclipseWhen', () {
      final r = rust.lunEclipseWhen(jd, flags);
      final l = legacy.lunEclipseWhen(jd, flags);
      expect(r.maxEclipse, closeTo(l.maxEclipse, 1e-6));
      expect(r.penumbralBegin, closeTo(l.penumbralBegin, 1e-6));
      expect(r.penumbralEnd, closeTo(l.penumbralEnd, 1e-6));
    });

    test('lunEclipseWhenLoc', () {
      final r = rust.lunEclipseWhenLoc(jd, flags, geolon: 13.41, geolat: 52.52);
      final l = legacy.lunEclipseWhenLoc(
        jd,
        flags,
        geolon: 13.41,
        geolat: 52.52,
      );
      expect(r.maxEclipse, closeTo(l.maxEclipse, 1e-6));
      expect(r.umbralMagnitude, closeTo(l.umbralMagnitude, 1e-6));
    });

    test('lunEclipseHow', () {
      final when = rust.lunEclipseWhen(jd, flags);
      final r = rust.lunEclipseHow(
        when.maxEclipse,
        flags,
        geolon: 13.41,
        geolat: 52.52,
      );
      final l = legacy.lunEclipseHow(
        when.maxEclipse,
        flags,
        geolon: 13.41,
        geolat: 52.52,
      );
      expect(r.umbralMagnitude, closeTo(l.umbralMagnitude, 1e-6));
      expect(r.penumbralMagnitude, closeTo(l.penumbralMagnitude, 1e-6));
    });
  });

  group('differential: rise/set', () {
    const jd = 2451545.0;

    test('riseTrans Sun rise', () {
      final r = rust.riseTrans(jd, 0, rsmi: 1, geolon: 13.41, geolat: 52.52);
      final l = legacy.riseTrans(jd, 0, rsmi: 1, geolon: 13.41, geolat: 52.52);
      expect(r.transitTime, closeTo(l.transitTime, 1e-6));
    });

    test('riseTrans Sun set', () {
      final r = rust.riseTrans(jd, 0, rsmi: 2, geolon: 13.41, geolat: 52.52);
      final l = legacy.riseTrans(jd, 0, rsmi: 2, geolon: 13.41, geolat: 52.52);
      expect(r.transitTime, closeTo(l.transitTime, 1e-6));
    });
  });

  group('differential: horizon', () {
    const jd = 2451545.0;

    test('azAlt ecliptic-to-horizon', () {
      final calc = rust.calcUt(jd, 0, 256);
      final r = rust.azAlt(
        jd,
        0,
        geolon: 13.41,
        geolat: 52.52,
        bodyLon: calc.longitude,
        bodyLat: calc.latitude,
      );
      final l = legacy.azAlt(
        jd,
        0,
        geolon: 13.41,
        geolat: 52.52,
        bodyLon: calc.longitude,
        bodyLat: calc.latitude,
      );
      expect(r.azimuth, closeTo(l.azimuth, 1e-6));
      expect(r.trueAltitude, closeTo(l.trueAltitude, 1e-6));
      expect(r.apparentAltitude, closeTo(l.apparentAltitude, 1e-6));
    });

    test('azAltRev horizon-to-ecliptic', () {
      final r = rust.azAltRev(
        jd,
        0,
        geolon: 13.41,
        geolat: 52.52,
        azimuth: 180.0,
        altitude: 30.0,
      );
      final l = legacy.azAltRev(
        jd,
        0,
        geolon: 13.41,
        geolat: 52.52,
        azimuth: 180.0,
        altitude: 30.0,
      );
      expect(r.lon, closeTo(l.lon, 1e-6));
      expect(r.lat, closeTo(l.lat, 1e-6));
    });
  });

  group('differential: nodes & orbits', () {
    const jd = 2451545.0;
    const flags = 256;

    test('nodApsUt Moon mean', () {
      final r = rust.nodApsUt(jd, 1, flags, 1);
      final l = legacy.nodApsUt(jd, 1, flags, 1);
      expect(r.ascending.longitude, closeTo(l.ascending.longitude, 1e-8));
      expect(r.descending.longitude, closeTo(l.descending.longitude, 1e-8));
      expect(r.perihelion.longitude, closeTo(l.perihelion.longitude, 1e-8));
      expect(r.aphelion.longitude, closeTo(l.aphelion.longitude, 1e-8));
    });

    test('getOrbitalElements Mars', () {
      final dt = rust.deltat(jd);
      final jdEt = jd + dt;
      final r = rust.getOrbitalElements(jdEt, 4, flags);
      final l = legacy.getOrbitalElements(jdEt, 4, flags);
      expect(r.semimajorAxis, closeTo(l.semimajorAxis, 1e-8));
      expect(r.eccentricity, closeTo(l.eccentricity, 1e-8));
      expect(r.inclination, closeTo(l.inclination, 1e-8));
      expect(r.siderealPeriodYears, closeTo(l.siderealPeriodYears, 1e-6));
    });

    test('orbitMaxMinTrueDistance Mars', () {
      final dt = rust.deltat(jd);
      final jdEt = jd + dt;
      final r = rust.orbitMaxMinTrueDistance(jdEt, 4, flags);
      final l = legacy.orbitMaxMinTrueDistance(jdEt, 4, flags);
      expect(r.maxDist, closeTo(l.maxDist, 1e-6));
      expect(r.minDist, closeTo(l.minDist, 1e-6));
      expect(r.trueDist, closeTo(l.trueDist, 1e-6));
    });
  });

  group('differential: phenomena', () {
    const jd = 2451545.0;
    const flags = 256;

    test('phenoUt Venus', () {
      final r = rust.phenoUt(jd, 3, flags);
      final l = legacy.phenoUt(jd, 3, flags);
      expect(r.phaseAngle, closeTo(l.phaseAngle, 1e-8));
      expect(r.phase, closeTo(l.phase, 1e-8));
      expect(r.elongation, closeTo(l.elongation, 1e-8));
      expect(r.apparentDiameter, closeTo(l.apparentDiameter, 1e-8));
      expect(r.apparentMagnitude, closeTo(l.apparentMagnitude, 1e-4));
    });
  });

  group('differential: stars', () {
    const jd = 2451545.0;
    const flags = 256;
    const ephePath =
        '/home/josh/.local/share/studio.ninthhouse.ephemeris_dashboard/ephe';

    test('fixstar2Ut Sirius', () {
      rust.setEphePath(ephePath);
      legacy.setEphePath(ephePath);
      rust.clearEntries();
      legacy.clearEntries();

      final r = rust.fixstar2Ut('Sirius', jd, flags);
      final l = legacy.fixstar2Ut('Sirius', jd, flags);
      expect(r.longitude, closeTo(l.longitude, 1e-4));
      expect(r.latitude, closeTo(l.latitude, 1e-4));
      expect(r.distance, closeTo(l.distance, 1e-2));
    });
  });

  group('differential: heliacal', () {
    const jd = 2451545.0;

    test('heliacalUt Venus morning first', () {
      final r = rust.heliacalUt(
        jd,
        geolon: 13.41,
        geolat: 52.52,
        atmo: const AtmoConditions(
          pressure: 1013.25,
          temperature: 15,
          humidity: 40,
          extinction: 0,
        ),
        observer: const ObserverConditions(),
        objectName: 'Venus',
        typeEvent: 1,
      );
      final l = legacy.heliacalUt(
        jd,
        geolon: 13.41,
        geolat: 52.52,
        atmo: const AtmoConditions(
          pressure: 1013.25,
          temperature: 15,
          humidity: 40,
          extinction: 0,
        ),
        observer: const ObserverConditions(),
        objectName: 'Venus',
        typeEvent: 1,
      );
      expect(r.startVisible, closeTo(l.startVisible, 1e-4));
      expect(r.bestVisible, closeTo(l.bestVisible, 1e-4));
      expect(r.endVisible, closeTo(l.endVisible, 1e-4));
    });
  });
}
