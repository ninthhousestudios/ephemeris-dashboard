// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

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

final _calcUtSpec = ComparisonSpec<CalcResult, OracleCalcResult>([
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

/// Topocentric calcs use SPEED3 internally (3-point speed differentiation),
/// which produces larger deltas than the analytic speed path.
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
    // SPEED3 auto-set when SPEED+TOPOCTR+!NOABERR
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

  group('Direct mapping: calcUt', () {
    test('Sun at J2000 epoch (Moshier)', () {
      const jd = JdUt1(2451545.0);
      final actual = eph.calcUt(jd, Body.sun, CalcFlags.speed);
      final expected = oracle.calcUt(jd.value, swe.seSun, swe.seFlgSpeed);
      _calcUtSpec.compare(actual, expected);
    });

    test('Moon at J2000 epoch (Moshier)', () {
      const jd = JdUt1(2451545.0);
      final actual = eph.calcUt(jd, Body.moon, CalcFlags.speed);
      final expected = oracle.calcUt(jd.value, swe.seMoon, swe.seFlgSpeed);
      _calcUtSpec.compare(actual, expected);
    });

    test('Mars at arbitrary date (Moshier)', () {
      const jd = JdUt1(2460000.5);
      final actual = eph.calcUt(jd, Body.mars, CalcFlags.speed);
      final expected = oracle.calcUt(jd.value, swe.seMars, swe.seFlgSpeed);
      _calcUtSpec.compare(actual, expected);
    });
  });

  group('Flag matrix: calcUt', () {
    const jd = JdUt1(2451545.0);
    const body = Body.sun;
    const oracleBody = swe.seSun;

    test('equatorial', () {
      final flags = CalcFlags.speed | CalcFlags.equatorial;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgEquatorial,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('xyz', () {
      final flags = CalcFlags.speed | CalcFlags.xyz;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgXyz,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('radians', () {
      final flags = CalcFlags.speed | CalcFlags.radians;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgRadians,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('heliocentric', () {
      final flags = CalcFlags.speed | CalcFlags.helctr;
      final actual = eph.calcUt(jd, Body.mars, flags);
      final expected = oracle.calcUt(
        jd.value,
        swe.seMars,
        swe.seFlgSpeed | swe.seFlgHelCtr,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('barycentric rejects Moshier', () {
      final flags = CalcFlags.speed | CalcFlags.baryctr;
      expect(
        () => eph.calcUt(jd, body, flags),
        throwsA(isA<UnsupportedFlagsException>()),
      );
    });

    test('J2000', () {
      final flags = CalcFlags.speed | CalcFlags.j2000;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgJ2000,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('noNut', () {
      final flags = CalcFlags.speed | CalcFlags.noNut;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgNoNut,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('truePos', () {
      final flags = CalcFlags.speed | CalcFlags.truePos;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgTruePos,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('astrometric (noAberr | noGdefl)', () {
      final flags = CalcFlags.speed | CalcFlags.astrometric;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgNoAberr | swe.seFlgNoGdefl,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('EclipticNutation pseudo-body', () {
      final actual = eph.calcUt(jd, Body.eclipticNutation, CalcFlags.none);
      final expected = oracle.calcUt(jd.value, swe.seEclNut, 0);
      _calcUtSpec.compare(actual, expected);
    });

    test('speed3 (explicit)', () {
      final actual = eph.calcUt(jd, body, CalcFlags.speed3);
      final expected = oracle.calcUt(jd.value, oracleBody, swe.seFlgSpeed3);
      // SPEED3 uses 3-point numeric differentiation — boundary class for speeds
      _topoSpec.compare(actual, expected);
    });

    test('icrs', () {
      final flags = CalcFlags.speed | CalcFlags.icrs;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgIcrs,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('dpsideps1980 (JPL Horizons mode)', () {
      final flags = CalcFlags.speed | CalcFlags.dpsideps1980;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgJplHor,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('jplHorApprox', () {
      final flags = CalcFlags.speed | CalcFlags.jplHorApprox;
      final actual = eph.calcUt(jd, body, flags);
      final expected = oracle.calcUt(
        jd.value,
        oracleBody,
        swe.seFlgSpeed | swe.seFlgJplHorApprox,
      );
      _calcUtSpec.compare(actual, expected);
    });

    test('centerBody', () {
      final flags = CalcFlags.speed | CalcFlags.centerBody;
      final actual = eph.calcUt(jd, Body.moon, flags);
      final expected = oracle.calcUt(
        jd.value,
        swe.seMoon,
        swe.seFlgSpeed | swe.seFlgCenterBody,
      );
      _calcUtSpec.compare(actual, expected);
    });
  });

  group('Composite mapping: calcUtWithConfig', () {
    test('sidereal Lahiri Sun at J2000 (Moshier)', () {
      const jd = JdUt1(2451545.0);

      final actual = eph.calcUtWithConfig(
        jd,
        Body.sun,
        CalcFlags.speed | CalcFlags.sidereal,
        const EphemerisConfig(siderealMode: SiderealMode.lahiri),
      );

      final expected = oracle.calcUtSidereal(
        jd.value,
        swe.seSun,
        swe.seFlgSpeed,
        swe.seSidmLahiri,
      );

      _calcUtSpec.compare(actual, expected);
    });

    test('sidereal FaganBradley Moon at arbitrary date (Moshier)', () {
      const jd = JdUt1(2460000.5);

      final actual = eph.calcUtWithConfig(
        jd,
        Body.moon,
        CalcFlags.speed | CalcFlags.sidereal,
        const EphemerisConfig(siderealMode: SiderealMode.faganBradley),
      );

      final expected = oracle.calcUtSidereal(
        jd.value,
        swe.seMoon,
        swe.seFlgSpeed,
        swe.seSidmFaganBradley,
      );

      _calcUtSpec.compare(actual, expected);
    });

    test('topocentric Moon (Moshier)', () {
      const jd = JdUt1(2451545.0);

      final actual = eph.calcUtWithConfig(
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

      final expected = oracle.calcUtTopo(
        jd.value,
        swe.seMoon,
        swe.seFlgSpeed,
        13.41,
        52.52,
        34,
      );

      _topoSpec.compare(actual, expected);
    });
  });

  group('Agreement-class enforcement', () {
    test('unclassified field throws StateError', () {
      final spec = ComparisonSpec<double, double>(
        [FieldPairSpec('a', (v) => v, (v) => v, AgreementClass.positional)],
        {'a', 'b'},
      );
      expect(() => spec.compare(1.0, 1.0), throwsStateError);
    });
  });
}
