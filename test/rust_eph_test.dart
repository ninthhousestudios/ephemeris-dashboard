// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;
import 'package:swe_dashboard/core/ephemeris/result_types.dart';
import 'package:swe_dashboard/core/ephemeris/rust_eph.dart';

void main() {
  late RustEph rust;

  setUp(() {
    rust = RustEph();
  });

  tearDown(() {
    rust.close();
  });

  // -------------------------------------------------------------------------
  // Sanity tests: RustEph calculation families
  // -------------------------------------------------------------------------

  group('tropical calculations', () {
    const jd = 2451545.0; // J2000
    const flags = 256; // seFlgSpeed

    test('calcUt Sun', () {
      final r = rust.calcUt(jd, 0, flags);
      expect(r.longitude, isNotNaN);
      expect(r.latitude, isNotNaN);
      expect(r.distance, greaterThan(0));
      expect(r.longitudeSpeed, isNotNaN);
      expect(r.latitudeSpeed, isNotNaN);
      expect(r.distanceSpeed, isNotNaN);
    });

    test('calcUt Moon', () {
      final r = rust.calcUt(jd, 1, flags);
      expect(r.longitude, isNotNaN);
      expect(r.latitude, isNotNaN);
      expect(r.distance, greaterThan(0));
    });

    test('houses Placidus', () {
      final r = rust.houses(jd, 52.52, 13.41, 0x50); // 'P'
      expect(r.cusps, hasLength(greaterThanOrEqualTo(13)));
      expect(r.ascendant, isNotNaN);
      expect(r.mc, isNotNaN);
    });

    test('deltat', () {
      expect(rust.deltat(jd), isNotNaN);
    });

    test('sidTime', () {
      expect(rust.sidTime(jd), isNotNaN);
    });

    test('sidTime0', () {
      expect(rust.sidTime0(jd, 23.4393, -0.001), isNotNaN);
    });

    test('timeEqu', () {
      expect(rust.timeEqu(jd), isNotNaN);
    });

    test('lmtToLat', () {
      expect(rust.lmtToLat(jd, 13.41), isNotNaN);
    });

    test('latToLmt', () {
      expect(rust.latToLmt(jd, 13.41), isNotNaN);
    });

    test('cotrans', () {
      final r = rust.cotrans(120.0, 5.0, 1.0, 23.44);
      expect(r.lon, isNotNaN);
      expect(r.lat, isNotNaN);
      expect(r.dist, isNotNaN);
    });

    test('refrac true-to-app', () {
      expect(rust.refrac(10.0, 1013.25, 15.0, 0), isNotNaN);
    });

    test('refrac app-to-true', () {
      expect(rust.refrac(10.0, 1013.25, 15.0, 1), isNotNaN);
    });
  });

  group('sidereal (Lahiri)', () {
    const jd = 2451545.0;
    const flags = 256 | 65536; // seFlgSpeed | seFlgSidereal

    setUp(() {
      rust.reconfigure(
        const rs.EphemerisConfig(siderealMode: rs.SiderealMode.lahiri),
      );
    });

    test('calcUt Sun sidereal', () {
      final r = rust.calcUt(jd, 0, flags);
      expect(r.longitude, isNotNaN);
      expect(r.latitude, isNotNaN);
    });

    test('getAyanamsaUt', () {
      expect(rust.getAyanamsaUt(jd), isNotNaN);
    });

    test('getAyanamsaExUt', () {
      final r = rust.getAyanamsaExUt(jd, flags);
      expect(r.ayanamsa, isNotNaN);
    });
  });

  group('topocentric', () {
    const jd = 2451545.0;
    const flags = 256 | 32768; // seFlgSpeed | seFlgTopoctr

    setUp(() {
      rust.reconfigure(
        rs.EphemerisConfig(
          topographic: rs.TopoPosition(
            longitude: 13.41,
            latitude: 52.52,
            altitude: 34.0,
          ),
        ),
      );
    });

    test('calcUt Moon topocentric', () {
      final r = rust.calcUt(jd, 1, flags);
      expect(r.longitude, isNotNaN);
      expect(r.latitude, isNotNaN);
      expect(r.distance, greaterThan(0));
    });
  });

  // -------------------------------------------------------------------------
  // Sanity tests: event/search families (S3)
  // -------------------------------------------------------------------------

  group('crossings', () {
    const jd = 2451545.0;
    const flags = 256;

    test('solCrossUt', () {
      final r = rust.solCrossUt(0, jd, flags);
      expect(r, isNotNaN);
    });

    test('moonCrossUt', () {
      final r = rust.moonCrossUt(0, jd, flags);
      expect(r, isNotNaN);
    });

    test('moonCrossNodeUt', () {
      final r = rust.moonCrossNodeUt(jd, flags);
      expect(r.jdUt, isNotNaN);
      expect(r.longitude, isNotNaN);
      expect(r.latitude, isNotNaN);
    });

    test('helioCrossUt', () {
      final r = rust.helioCrossUt(2, 0, jd, flags, 1); // Venus
      expect(r, isNotNaN);
    });
  });

  group('eclipses', () {
    const jd = 2451545.0;
    const flags = 4; // seFlgSwieph

    test('solEclipseWhenGlob', () {
      final r = rust.solEclipseWhenGlob(jd, flags);
      expect(r.maxEclipse, isNotNaN);
      expect(r.begin, isNotNaN);
      expect(r.end, isNotNaN);
    });

    test('solEclipseWhenLoc', () {
      final r = rust.solEclipseWhenLoc(jd, flags, geolon: 13.41, geolat: 52.52);
      expect(r.maxEclipse, isNotNaN);
      expect(r.firstContact, isNotNaN);
      expect(r.magnitude, isNotNaN);
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
      expect(r.magnitude, isNotNaN);
      expect(r.obscuration, isNotNaN);
    });

    test('solEclipseWhere', () {
      final when = rust.solEclipseWhenGlob(jd, flags);
      final r = rust.solEclipseWhere(when.maxEclipse, flags);
      expect(r.geolon, isNotNaN);
      expect(r.geolat, isNotNaN);
    });

    test('lunEclipseWhen', () {
      final r = rust.lunEclipseWhen(jd, flags);
      expect(r.maxEclipse, isNotNaN);
      expect(r.penumbralBegin, isNotNaN);
      expect(r.penumbralEnd, isNotNaN);
    });

    test('lunEclipseWhenLoc', () {
      final r = rust.lunEclipseWhenLoc(jd, flags, geolon: 13.41, geolat: 52.52);
      expect(r.maxEclipse, isNotNaN);
      expect(r.umbralMagnitude, isNotNaN);
    });

    test('lunEclipseHow', () {
      final when = rust.lunEclipseWhen(jd, flags);
      final r = rust.lunEclipseHow(
        when.maxEclipse,
        flags,
        geolon: 13.41,
        geolat: 52.52,
      );
      expect(r.umbralMagnitude, isNotNaN);
      expect(r.penumbralMagnitude, isNotNaN);
    });
  });

  group('rise/set', () {
    const jd = 2451545.0;

    test('riseTrans Sun rise', () {
      final r = rust.riseTrans(jd, 0, rsmi: 1, geolon: 13.41, geolat: 52.52);
      expect(r.transitTime, isNotNaN);
    });

    test('riseTrans Sun set', () {
      final r = rust.riseTrans(jd, 0, rsmi: 2, geolon: 13.41, geolat: 52.52);
      expect(r.transitTime, isNotNaN);
    });
  });

  group('horizon', () {
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
      expect(r.azimuth, isNotNaN);
      expect(r.trueAltitude, isNotNaN);
      expect(r.apparentAltitude, isNotNaN);
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
      expect(r.lon, isNotNaN);
      expect(r.lat, isNotNaN);
    });
  });

  group('nodes & orbits', () {
    const jd = 2451545.0;
    const flags = 256;

    test('nodApsUt Moon mean', () {
      final r = rust.nodApsUt(jd, 1, flags, 1);
      expect(r.ascending.longitude, isNotNaN);
      expect(r.descending.longitude, isNotNaN);
      expect(r.perihelion.longitude, isNotNaN);
      expect(r.aphelion.longitude, isNotNaN);
    });

    test('getOrbitalElements Mars', () {
      final dt = rust.deltat(jd);
      final jdEt = jd + dt;
      final r = rust.getOrbitalElements(jdEt, 4, flags);
      expect(r.semimajorAxis, isNotNaN);
      expect(r.eccentricity, isNotNaN);
      expect(r.inclination, isNotNaN);
      expect(r.siderealPeriodYears, isNotNaN);
    });

    test('orbitMaxMinTrueDistance Mars', () {
      final dt = rust.deltat(jd);
      final jdEt = jd + dt;
      final r = rust.orbitMaxMinTrueDistance(jdEt, 4, flags);
      expect(r.maxDist, isNotNaN);
      expect(r.minDist, isNotNaN);
      expect(r.trueDist, isNotNaN);
    });
  });

  group('phenomena', () {
    const jd = 2451545.0;
    const flags = 256;

    test('phenoUt Venus', () {
      final r = rust.phenoUt(jd, 3, flags);
      expect(r.phaseAngle, isNotNaN);
      expect(r.phase, isNotNaN);
      expect(r.elongation, isNotNaN);
      expect(r.apparentDiameter, isNotNaN);
      expect(r.apparentMagnitude, isNotNaN);
    });
  });

  group('stars', () {
    const jd = 2451545.0;
    const flags = 256;
    const ephePath =
        '/home/josh/.local/share/studio.ninthhouse.ephemeris_dashboard/ephe';

    test('fixstar2Ut Sirius', () {
      rust.reconfigure(rs.EphemerisConfig(ephePath: ephePath));

      final r = rust.fixstar2Ut('Sirius', jd, flags);
      expect(r.longitude, isNotNaN);
      expect(r.latitude, isNotNaN);
      expect(r.distance, greaterThan(0));
    });
  });

  group('heliacal', () {
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
      expect(r.startVisible, isNotNaN);
      expect(r.bestVisible, isNotNaN);
      expect(r.endVisible, isNotNaN);
    });
  });
}
