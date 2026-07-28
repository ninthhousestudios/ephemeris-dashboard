// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io' show Platform;

import 'package:swisseph/swisseph.dart' as swe;
import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

import 'src/agreement.dart';
import 'src/oracle.dart';

const _calcResultFields = {
  'longitude',
  'latitude',
  'distance',
  'longitudeSpeed',
  'latitudeSpeed',
  'distanceSpeed',
};

final _positionalSpec = ComparisonSpec<CalcResult, OracleCalcResult>([
  FieldPairSpec(
    'longitude',
    (r) => r.longitude,
    (o) => o.longitude,
    AgreementClass.positional,
  ),
  FieldPairSpec(
    'latitude',
    (r) => r.latitude,
    (o) => o.latitude,
    AgreementClass.positional,
  ),
  FieldPairSpec(
    'distance',
    (r) => r.distance,
    (o) => o.distance,
    AgreementClass.positional,
  ),
  FieldPairSpec(
    'longitudeSpeed',
    (r) => r.longitudeSpeed,
    (o) => o.longitudeSpeed,
    AgreementClass.positional,
  ),
  FieldPairSpec(
    'latitudeSpeed',
    (r) => r.latitudeSpeed,
    (o) => o.latitudeSpeed,
    AgreementClass.positional,
  ),
  FieldPairSpec(
    'distanceSpeed',
    (r) => r.distanceSpeed,
    (o) => o.distanceSpeed,
    AgreementClass.positional,
  ),
], _calcResultFields);

final _pctrSpec = ComparisonSpec<CalcResult, OracleCalcResult>([
  FieldPairSpec(
    'longitude',
    (r) => r.longitude,
    (o) => o.longitude,
    AgreementClass.boundary,
    tolerance: 1e-8,
    boundaryArtifact: 'planetocentric subtraction amplification',
  ),
  FieldPairSpec(
    'latitude',
    (r) => r.latitude,
    (o) => o.latitude,
    AgreementClass.boundary,
    tolerance: 1e-8,
    boundaryArtifact: 'planetocentric subtraction amplification',
  ),
  FieldPairSpec(
    'distance',
    (r) => r.distance,
    (o) => o.distance,
    AgreementClass.boundary,
    tolerance: 1e-8,
    boundaryArtifact: 'planetocentric subtraction amplification',
  ),
  FieldPairSpec(
    'longitudeSpeed',
    (r) => r.longitudeSpeed,
    (o) => o.longitudeSpeed,
    AgreementClass.boundary,
    tolerance: 1e-8,
    boundaryArtifact: 'planetocentric subtraction amplification',
  ),
  FieldPairSpec(
    'latitudeSpeed',
    (r) => r.latitudeSpeed,
    (o) => o.latitudeSpeed,
    AgreementClass.boundary,
    tolerance: 1e-8,
    boundaryArtifact: 'planetocentric subtraction amplification',
  ),
  FieldPairSpec(
    'distanceSpeed',
    (r) => r.distanceSpeed,
    (o) => o.distanceSpeed,
    AgreementClass.boundary,
    tolerance: 1e-8,
    boundaryArtifact: 'planetocentric subtraction amplification',
  ),
], _calcResultFields);

final _topoSpec = ComparisonSpec<CalcResult, OracleCalcResult>([
  FieldPairSpec(
    'longitude',
    (r) => r.longitude,
    (o) => o.longitude,
    AgreementClass.positional,
  ),
  FieldPairSpec(
    'latitude',
    (r) => r.latitude,
    (o) => o.latitude,
    AgreementClass.positional,
  ),
  FieldPairSpec(
    'distance',
    (r) => r.distance,
    (o) => o.distance,
    AgreementClass.positional,
  ),
  FieldPairSpec(
    'longitudeSpeed',
    (r) => r.longitudeSpeed,
    (o) => o.longitudeSpeed,
    AgreementClass.boundary,
    tolerance: 1e-7,
    boundaryArtifact: 'SPEED3 topocentric 3-point differentiation',
  ),
  FieldPairSpec(
    'latitudeSpeed',
    (r) => r.latitudeSpeed,
    (o) => o.latitudeSpeed,
    AgreementClass.boundary,
    tolerance: 1e-7,
    boundaryArtifact: 'SPEED3 topocentric 3-point differentiation',
  ),
  FieldPairSpec(
    'distanceSpeed',
    (r) => r.distanceSpeed,
    (o) => o.distanceSpeed,
    AgreementClass.boundary,
    tolerance: 1e-7,
    boundaryArtifact: 'SPEED3 topocentric 3-point differentiation',
  ),
], _calcResultFields);

void main() {
  late Ephemeris eph;
  late Oracle oracle;

  setUpAll(() {
    eph = Ephemeris(const EphemerisConfig());
    oracle = Oracle();
  });

  tearDownAll(() {
    eph.close();
    oracle.close();
  });

  // -----------------------------------------------------------------------
  // Direct mapping: calc (TT)
  // -----------------------------------------------------------------------

  group('Direct mapping: calc', () {
    test('Sun at J2000 epoch (Moshier)', () {
      const jd = JdTt(2451545.0);
      final actual = eph.calc(jd, Body.sun, CalcFlags.speed);
      final expected = oracle.calc(jd.value, swe.seSun, swe.seFlgSpeed);
      _positionalSpec.compare(actual, expected);
    });

    test('Moon at J2000 epoch (Moshier)', () {
      const jd = JdTt(2451545.0);
      final actual = eph.calc(jd, Body.moon, CalcFlags.speed);
      final expected = oracle.calc(jd.value, swe.seMoon, swe.seFlgSpeed);
      _positionalSpec.compare(actual, expected);
    });

    test('Mars at arbitrary date (Moshier)', () {
      const jd = JdTt(2460000.5);
      final actual = eph.calc(jd, Body.mars, CalcFlags.speed);
      final expected = oracle.calc(jd.value, swe.seMars, swe.seFlgSpeed);
      _positionalSpec.compare(actual, expected);
    });
  });

  // -----------------------------------------------------------------------
  // Flag matrix: calc
  // -----------------------------------------------------------------------

  group('Flag matrix: calc', () {
    const jd = JdTt(2451545.0);
    const body = Body.sun;
    const oracleBody = swe.seSun;

    test('equatorial', () {
      final flags = CalcFlags.speed | CalcFlags.equatorial;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgEquatorial,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('xyz', () {
      final flags = CalcFlags.speed | CalcFlags.xyz;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgXyz,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('radians', () {
      final flags = CalcFlags.speed | CalcFlags.radians;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgRadians,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('heliocentric', () {
      const moonJd = JdTt(2451545.0);
      final flags = CalcFlags.speed | CalcFlags.helctr;
      final actual = eph.calc(moonJd, Body.mars, flags);
      final expected = oracle.calc(
        moonJd.value,
        swe.seMars,
        swe.seFlgSpeed | swe.seFlgHelCtr,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('barycentric rejects Moshier', () {
      final flags = CalcFlags.speed | CalcFlags.baryctr;
      expect(
        () => eph.calc(jd, body, flags),
        throwsA(isA<UnsupportedFlagsException>()),
      );
    });

    test('J2000', () {
      final flags = CalcFlags.speed | CalcFlags.j2000;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgJ2000,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('noNut', () {
      final flags = CalcFlags.speed | CalcFlags.noNut;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgNoNut,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('truePos', () {
      final flags = CalcFlags.speed | CalcFlags.truePos;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgTruePos,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('astrometric (noAberr | noGdefl)', () {
      final flags = CalcFlags.speed | CalcFlags.astrometric;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgNoAberr | swe.seFlgNoGdefl,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('EclipticNutation pseudo-body', () {
      final actual = eph.calc(jd, Body.eclipticNutation, CalcFlags.none);
      final expected = oracle.calc(jd.value, swe.seEclNut, 0);
      _positionalSpec.compare(actual, expected);
    });

    test('speed3 (explicit)', () {
      final actual = eph.calc(jd, body, CalcFlags.speed3);
      final expected = oracle.calc(jd.value, oracleBody, swe.seFlgSpeed3);
      // SPEED3 uses 3-point numeric differentiation — boundary class for speeds
      _topoSpec.compare(actual, expected);
    });

    test('icrs', () {
      final flags = CalcFlags.speed | CalcFlags.icrs;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgIcrs,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('dpsideps1980 (JPL Horizons mode)', () {
      final flags = CalcFlags.speed | CalcFlags.dpsideps1980;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgJplHor,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('jplHorApprox', () {
      final flags = CalcFlags.speed | CalcFlags.jplHorApprox;
      final actual = eph.calc(jd, body, flags);
      final expected = oracle.calc(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgJplHorApprox,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('centerBody', () {
      final flags = CalcFlags.speed | CalcFlags.centerBody;
      final actual = eph.calc(jd, Body.moon, flags);
      final expected = oracle.calc(
        jd.value,
        swe.seMoon,
        swe.seFlgSpeed | swe.seFlgCenterBody,
      );
      _positionalSpec.compare(actual, expected);
    });
  });

  // -----------------------------------------------------------------------
  // Engine-bit precedence
  // -----------------------------------------------------------------------

  group('Engine-bit precedence', () {
    const jd = JdTt(2451545.0);

    test('MOSEPH on Moshier config stays Moshier', () {
      final flags = CalcFlags.speed | CalcFlags.mosEph;
      final actual = eph.calc(jd, Body.sun, flags);
      final expected = oracle.calc(
        jd.value,
        swe.seSun,
        swe.seFlgSpeed | swe.seFlgMosEph,
      );
      _positionalSpec.compare(actual, expected);
      expect(
        actual.flagsUsed.contains(CalcFlags.mosEph),
        isTrue,
        reason: 'flagsUsed should contain MOSEPH',
      );
    });

    test('SWIEPH on Moshier config falls back to Moshier', () {
      final flags = CalcFlags.speed | CalcFlags.swiEph;
      final actual = eph.calc(jd, Body.sun, flags);
      final expected = oracle.calc(
        jd.value,
        swe.seSun,
        swe.seFlgSpeed | swe.seFlgSwiEph,
      );
      _positionalSpec.compare(actual, expected);
      expect(
        actual.flagsUsed.contains(CalcFlags.mosEph),
        isTrue,
        reason: 'flagsUsed should show Moshier fallback',
      );
    });

    test('JPLEPH on Moshier config falls back to Moshier', () {
      final flags = CalcFlags.speed | CalcFlags.jplEph;
      final actual = eph.calc(jd, Body.sun, flags);
      final expected = oracle.calc(
        jd.value,
        swe.seSun,
        swe.seFlgSpeed | swe.seFlgJplEph,
      );
      _positionalSpec.compare(actual, expected);
      expect(
        actual.flagsUsed.contains(CalcFlags.mosEph),
        isTrue,
        reason: 'flagsUsed should show Moshier fallback',
      );
    });
  });

  // -----------------------------------------------------------------------
  // Direct mapping: calcPctr
  // -----------------------------------------------------------------------

  group('Direct mapping: calcPctr', () {
    test('rejects Moshier (Swiss/JPL only)', () {
      const jd = JdTt(2451545.0);
      expect(
        () => eph.calcPctr(jd, Body.moon, Body.jupiter, CalcFlags.speed),
        throwsA(isA<SweException>()),
      );
    });
  });

  // -----------------------------------------------------------------------
  // Composite mapping: calcWithConfig
  // -----------------------------------------------------------------------

  group('Composite mapping: calcWithConfig', () {
    test('sidereal Lahiri Sun (Moshier)', () {
      const jd = JdTt(2451545.0);
      final actual = eph.calcWithConfig(
        jd,
        Body.sun,
        CalcFlags.speed | CalcFlags.sidereal,
        const EphemerisConfig(siderealMode: SiderealMode.lahiri),
      );
      final expected = oracle.calcSidereal(
        jd.value,
        swe.seSun,
        swe.seFlgSpeed,
        swe.seSidmLahiri,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('sidereal FaganBradley Moon (Moshier)', () {
      const jd = JdTt(2460000.5);
      final actual = eph.calcWithConfig(
        jd,
        Body.moon,
        CalcFlags.speed | CalcFlags.sidereal,
        const EphemerisConfig(siderealMode: SiderealMode.faganBradley),
      );
      final expected = oracle.calcSidereal(
        jd.value,
        swe.seMoon,
        swe.seFlgSpeed,
        swe.seSidmFaganBradley,
      );
      _positionalSpec.compare(actual, expected);
    });

    test('topocentric Moon (Moshier)', () {
      const jd = JdTt(2451545.0);
      final actual = eph.calcWithConfig(
        jd,
        Body.moon,
        CalcFlags.speed | CalcFlags.topoctr,
        const EphemerisConfig(
          topographic: TopoPosition(
            longitude: 13.41,
            latitude: 52.52,
            altitude: 34,
          ),
        ),
      );
      final expected = oracle.calcTopo(
        jd.value,
        swe.seMoon,
        swe.seFlgSpeed,
        13.41,
        52.52,
        34,
      );
      _topoSpec.compare(actual, expected);
    });

    test('sidereal + topocentric combined (Moshier)', () {
      const jd = JdTt(2451545.0);
      final actual = eph.calcWithConfig(
        jd,
        Body.sun,
        CalcFlags.speed | CalcFlags.sidereal | CalcFlags.topoctr,
        const EphemerisConfig(
          siderealMode: SiderealMode.lahiri,
          topographic: TopoPosition(
            longitude: 77.59,
            latitude: 12.97,
            altitude: 920,
          ),
        ),
      );
      final sWeOracle = swe.SwissEph.find()
        ..setSidMode(swe.seSidmLahiri)
        ..setTopo(77.59, 12.97, 920);
      try {
        final oResult = sWeOracle.calc(
          jd.value,
          swe.seSun,
          swe.seFlgSpeed | swe.seFlgSidereal | swe.seFlgTopoCtr,
        );
        final expected = OracleCalcResult.fromFields(
          longitude: oResult.longitude,
          latitude: oResult.latitude,
          distance: oResult.distance,
          longitudeSpeed: oResult.longitudeSpeed,
          latitudeSpeed: oResult.latitudeSpeed,
          distanceSpeed: oResult.distanceSpeed,
        );
        _topoSpec.compare(actual, expected);
      } finally {
        sWeOracle
          ..setSidMode(0)
          ..close();
      }
    });
  });

  // -----------------------------------------------------------------------
  // Asteroid config
  // -----------------------------------------------------------------------

  group('Asteroid config', () {
    test('undeclared asteroid throws EphemerisNotAvailableException', () {
      const jd = JdTt(2451545.0);
      expect(
        () => eph.calc(
          jd,
          const Body.asteroid(AsteroidId(99942)),
          CalcFlags.speed,
        ),
        throwsA(isA<EphemerisNotAvailableException>()),
      );
    });
  });

  // -----------------------------------------------------------------------
  // calcPctr positive test (Swiss files, must run after all Moshier tests)
  // -----------------------------------------------------------------------

  final ephePath = Platform.environment['SWE_EPHE_PATH'];

  group(
    'Direct mapping: calcPctr (Swiss)',
    skip: ephePath == null ? 'SWE_EPHE_PATH not set' : null,
    () {
      late Ephemeris swissEph;
      late Oracle swissOracle;

      setUpAll(() {
        swissEph = Ephemeris(
          EphemerisConfig(
            ephemerisSource: EphemerisSource.swiss,
            ephePath: ephePath,
          ),
        );
        swissOracle = Oracle(ephePath: ephePath);
      });

      tearDownAll(() {
        swissEph.close();
        swissOracle.close();
      });

      test('Moon relative to Jupiter', () {
        const jd = JdTt(2451545.0);
        final actual = swissEph.calcPctr(
          jd,
          Body.moon,
          Body.jupiter,
          CalcFlags.speed,
        );
        final expected = swissOracle.calcPctr(
          jd.value,
          swe.seMoon,
          swe.seJupiter,
          swe.seFlgSpeed,
        );
        _pctrSpec.compare(actual, expected);
      });
    },
  );
}
