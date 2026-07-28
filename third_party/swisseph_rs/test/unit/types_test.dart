// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // Body hierarchy
  // -------------------------------------------------------------------------

  group('Body', () {
    test('standard body raw values', () {
      expect(Body.sun.rawValue, 0);
      expect(Body.moon.rawValue, 1);
      expect(Body.mercury.rawValue, 2);
      expect(Body.pluto.rawValue, 9);
      expect(Body.meanNode.rawValue, 10);
      expect(Body.earth.rawValue, 14);
      expect(Body.chiron.rawValue, 15);
      expect(Body.pholus.rawValue, 16);
      expect(Body.ceres.rawValue, 17);
      expect(Body.vesta.rawValue, 20);
      expect(Body.intpApogee.rawValue, 21);
      expect(Body.intpPerigee.rawValue, 22);
      expect(Body.eclipticNutation.rawValue, -1);
    });

    test('asteroid raw value offset', () {
      const eros = Body.asteroid(AsteroidId(433));
      expect(eros.rawValue, 10433);
    });

    test('fictitious body raw value', () {
      expect(FictitiousBody.cupido.rawValue, 40);
      expect(FictitiousBody.waldemath.rawValue, 58);
      const custom = Body.fictitious(FictitiousId(100));
      expect(custom.rawValue, 100);
    });

    test('planet moon raw value offset', () {
      const body = Body.planetMoon(PlanetMoonId(401));
      expect(body.rawValue, 9401);
    });

    test('fromRawId round-trip for standard bodies', () {
      for (final body in [
        Body.sun,
        Body.moon,
        Body.pluto,
        Body.earth,
        Body.eclipticNutation,
      ]) {
        final recovered = Body.fromRawId(body.rawValue);
        expect(recovered.rawValue, body.rawValue);
        expect(recovered, isA<StandardBody>());
      }
    });

    test('fromRawId for fictitious', () {
      final body = Body.fromRawId(40);
      expect(body, isA<FictitiousBody>());
      expect(body.rawValue, 40);
    });

    test('fromRawId for asteroid', () {
      final body = Body.fromRawId(10433);
      expect(body, isA<AsteroidBody>());
      expect(body.rawValue, 10433);
    });

    test('fromRawId for planet moon', () {
      final body = Body.fromRawId(9401);
      expect(body, isA<PlanetMoonBody>());
      expect(body.rawValue, 9401);
    });

    test('fromRawId rejects invalid IDs', () {
      expect(() => Body.fromRawId(23), throwsArgumentError);
      expect(() => Body.fromRawId(-2), throwsArgumentError);
      expect(() => Body.fromRawId(1000), throwsArgumentError);
      expect(() => Body.fromRawId(8999), throwsArgumentError);
    });

    test('exhaustive switch compiles over Body', () {
      const Body body = Body.sun;
      final result = switch (body) {
        StandardBody() => 'standard',
        AsteroidBody() => 'asteroid',
        FictitiousBody() => 'fictitious',
        PlanetMoonBody() => 'planet_moon',
      };
      expect(result, 'standard');
    });

    test('equality for dynamically created bodies', () {
      expect(Body.fromRawId(0), Body.sun);
      expect(
        const AsteroidBody(AsteroidId(433)),
        const AsteroidBody(AsteroidId(433)),
      );
      expect(const FictitiousBody(FictitiousId(40)), FictitiousBody.cupido);
    });
  });

  group('AsteroidId', () {
    test('validated accepts valid numbers', () {
      expect(AsteroidId.validated(0).mpcNumber, 0);
      expect(AsteroidId.validated(433).mpcNumber, 433);
    });

    test('validated rejects negative', () {
      expect(() => AsteroidId.validated(-1), throwsRangeError);
    });
  });

  group('FictitiousId', () {
    test('validated accepts valid range', () {
      expect(FictitiousId.validated(40).rawId, 40);
      expect(FictitiousId.validated(999).rawId, 999);
    });

    test('validated rejects out of range', () {
      expect(() => FictitiousId.validated(39), throwsRangeError);
      expect(() => FictitiousId.validated(1000), throwsRangeError);
    });
  });

  group('PlanetMoonId', () {
    test('validated accepts valid range', () {
      expect(PlanetMoonId.validated(0).encoded, 0);
      expect(PlanetMoonId.validated(999).encoded, 999);
    });

    test('validated rejects out of range', () {
      expect(() => PlanetMoonId.validated(-1), throwsRangeError);
      expect(() => PlanetMoonId.validated(1000), throwsRangeError);
    });
  });

  // -------------------------------------------------------------------------
  // Flag algebra
  // -------------------------------------------------------------------------

  group('CalcFlags', () {
    test('bitwise or combines flags', () {
      final flags = CalcFlags.speed | CalcFlags.equatorial;
      expect(flags.contains(CalcFlags.speed), isTrue);
      expect(flags.contains(CalcFlags.equatorial), isTrue);
      expect(flags.contains(CalcFlags.sidereal), isFalse);
    });

    test('bitwise and intersects flags', () {
      final flags = CalcFlags.speed | CalcFlags.equatorial | CalcFlags.sidereal;
      final masked = flags & CalcFlags.speed;
      expect(masked, CalcFlags.speed);
    });

    test('combo: astrometric contains noAberr and noGdefl', () {
      expect(CalcFlags.astrometric.contains(CalcFlags.noAberr), isTrue);
      expect(CalcFlags.astrometric.contains(CalcFlags.noGdefl), isTrue);
      expect(CalcFlags.astrometric.contains(CalcFlags.speed), isFalse);
    });

    test('none contains nothing', () {
      expect(CalcFlags.none.value, 0);
      expect(CalcFlags.none.contains(CalcFlags.speed), isFalse);
    });
  });

  group('EclipseFlags', () {
    test('allTypesSolar is union of six flags', () {
      final manual =
          EclipseFlags.central |
          EclipseFlags.noncentral |
          EclipseFlags.total |
          EclipseFlags.annular |
          EclipseFlags.partial |
          EclipseFlags.hybrid;
      expect(EclipseFlags.allTypesSolar, manual);
    });

    test('allTypesLunar is union of three flags', () {
      final manual =
          EclipseFlags.total | EclipseFlags.partial | EclipseFlags.penumbral;
      expect(EclipseFlags.allTypesLunar, manual);
    });

    test('bit-aliased flags share values', () {
      expect(EclipseFlags.occBegDaylight, EclipseFlags.penumbbegVisible);
      expect(EclipseFlags.occEndDaylight, EclipseFlags.penumbendVisible);
    });
  });

  group('RiseSetFlags', () {
    test('hinduRising combo', () {
      final manual =
          RiseSetFlags.discCenter |
          RiseSetFlags.noRefraction |
          RiseSetFlags.geoctrNoEclLat;
      expect(RiseSetFlags.hinduRising, manual);
    });
  });

  group('NodApsMethod', () {
    test('method + fopoint combination', () {
      final flags = NodApsMethod.oscu | NodApsMethod.fopoint;
      expect(flags.contains(NodApsMethod.oscu), isTrue);
      expect(flags.contains(NodApsMethod.fopoint), isTrue);
      expect(flags.contains(NodApsMethod.mean), isFalse);
    });
  });

  group('SiderealBits', () {
    test('bitwise combination', () {
      final bits = SiderealBits.eclT0 | SiderealBits.userUt;
      expect(bits.contains(SiderealBits.eclT0), isTrue);
      expect(bits.contains(SiderealBits.userUt), isTrue);
      expect(bits.contains(SiderealBits.ssyPlane), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // JdUt1 / JdTt
  // -------------------------------------------------------------------------

  group('JdUt1', () {
    test('arithmetic: add and subtract days', () {
      const jd = JdUt1(2451545.0);
      expect((jd + 1.0).value, 2451546.0);
      expect((jd - 1.0).value, 2451544.0);
    });

    test('difference between two JdUt1 values', () {
      const a = JdUt1(2451546.0);
      const b = JdUt1(2451545.0);
      expect(a.difference(b), 1.0);
    });

    test('J2000.0 → DateTime round-trip', () {
      const j2000 = JdUt1(2451545.0);
      final dt = j2000.toDateTime();
      expect(dt.year, 2000);
      expect(dt.month, 1);
      expect(dt.day, 1);
      expect(dt.hour, 12);
      expect(dt.minute, 0);
      expect(dt.second, 0);
      expect(dt.isUtc, isTrue);

      final jdBack = dt.toJdUt1();
      expect((jdBack.value - j2000.value).abs(), lessThan(1e-6));
    });

    test('arbitrary date round-trip', () {
      final dt = DateTime.utc(2024, 6, 15, 18, 30, 0);
      final jd = dt.toJdUt1();
      final dt2 = jd.toDateTime();
      expect(dt2.year, 2024);
      expect(dt2.month, 6);
      expect(dt2.day, 15);
      expect(dt2.hour, 18);
      expect(dt2.minute, 30);
      expect(dt2.second, 0);
    });

    test('epoch boundary: 1582-10-15 (Gregorian reform)', () {
      final dt = DateTime.utc(1582, 10, 15, 0, 0, 0);
      final jd = dt.toJdUt1();
      expect(jd.value, closeTo(2299160.5, 1e-6));
      final dt2 = jd.toDateTime();
      expect(dt2.year, 1582);
      expect(dt2.month, 10);
      expect(dt2.day, 15);
    });

    test('pre-Gregorian date round-trips (proleptic Gregorian)', () {
      final dt = DateTime.utc(1500, 1, 1, 12, 0, 0);
      final jd = dt.toJdUt1();
      final dt2 = jd.toDateTime();
      expect(dt2.year, 1500);
      expect(dt2.month, 1);
      expect(dt2.day, 1);
      expect(dt2.hour, 12);
    });

    test('midnight vs noon', () {
      final midnight = DateTime.utc(2000, 1, 1, 0, 0, 0);
      final noon = DateTime.utc(2000, 1, 1, 12, 0, 0);
      final jdMid = midnight.toJdUt1();
      final jdNoon = noon.toJdUt1();
      expect((jdNoon.value - jdMid.value), closeTo(0.5, 1e-10));
    });
  });

  group('JdTt', () {
    test('arithmetic', () {
      const jd = JdTt(2451545.0);
      expect((jd + 1.0).value, 2451546.0);
      expect((jd - 0.5).value, 2451544.5);
    });

    test('difference', () {
      const a = JdTt(2451546.0);
      const b = JdTt(2451545.0);
      expect(a.difference(b), 1.0);
    });
  });

  // -------------------------------------------------------------------------
  // SweException
  // -------------------------------------------------------------------------

  group('SweException', () {
    test('exceptionFromCode returns correct subtypes', () {
      final cases = <int, Type>{
        -1: InvalidBodyException,
        -2: UnsupportedFlagsException,
        -3: InvalidHouseSystemException,
        -4: InvalidSiderealModeException,
        -5: InvalidCalendarTypeException,
        -6: InvalidDateException,
        -7: EphemerisNotAvailableException,
        -8: BeyondEphemerisLimitsException,
        -9: FileNotFoundException,
        -10: FileFormatException,
        -11: CircumpolarBodyException,
        -12: InvalidTimeException,
        -13: InvalidLeapSecondException,
        -14: UnsupportedEphemerisException,
        -15: SiderealModeRequiresFixedStarsException,
        -16: CErrorException,
        -17: NoConvergenceException,
        -90: EnginePanicException,
        -91: InvalidArgException,
        -99: InternalException,
      };
      for (final MapEntry(:key, :value) in cases.entries) {
        final ex = exceptionFromCode(key, 'test');
        expect(ex.runtimeType, value, reason: 'code $key');
        expect(ex.message, 'test');
      }
    });

    test('unknown code produces UnknownSweException', () {
      final ex = exceptionFromCode(-999, 'mystery');
      expect(ex, isA<UnknownSweException>());
      expect((ex as UnknownSweException).code, -999);
      expect(ex.message, 'mystery');
    });

    test('exhaustive switch compiles over SweException', () {
      const SweException ex = InvalidBodyException('test');
      final result = switch (ex) {
        InvalidBodyException() => 'body',
        UnsupportedFlagsException() => 'flags',
        InvalidHouseSystemException() => 'house',
        InvalidSiderealModeException() => 'sidmode',
        InvalidCalendarTypeException() => 'cal',
        InvalidDateException() => 'date',
        EphemerisNotAvailableException() => 'ephna',
        BeyondEphemerisLimitsException() => 'limits',
        FileNotFoundException() => 'fnf',
        FileFormatException() => 'fmt',
        CircumpolarBodyException() => 'circpol',
        InvalidTimeException() => 'time',
        InvalidLeapSecondException() => 'leap',
        UnsupportedEphemerisException() => 'unsupeph',
        SiderealModeRequiresFixedStarsException() => 'sidfixed',
        CErrorException() => 'cerr',
        NoConvergenceException() => 'noconv',
        EnginePanicException() => 'panic',
        InvalidArgException() => 'arg',
        InternalException() => 'internal',
        UnknownSweException() => 'unknown',
      };
      expect(result, 'body');
    });
  });

  // -------------------------------------------------------------------------
  // Enums
  // -------------------------------------------------------------------------

  group('HouseSystem', () {
    test('charCode values', () {
      expect(HouseSystem.placidus.charCode, 0x50); // 'P'
      expect(HouseSystem.wholeSign.charCode, 0x57); // 'W'
      expect(HouseSystem.equal.charCode, 0x41); // 'A'
    });

    test('fromCharCode lookup', () {
      expect(HouseSystem.fromCharCode(0x50), HouseSystem.placidus);
      expect(HouseSystem.fromCharCode(0x57), HouseSystem.wholeSign);
    });

    test('fromCharCode E alias maps to equal', () {
      expect(HouseSystem.fromCharCode(0x45), HouseSystem.equal);
    });

    test('fromCharCode returns null for invalid', () {
      expect(HouseSystem.fromCharCode(0x5A), isNull); // 'Z'
    });

    test('25 variants', () {
      expect(HouseSystem.values.length, 25);
    });
  });

  group('SiderealMode', () {
    test('known values', () {
      expect(SiderealMode.faganBradley.value, 0);
      expect(SiderealMode.lahiri.value, 1);
      expect(SiderealMode.user.value, 255);
    });

    test('48 variants (47 built-in + user)', () {
      expect(SiderealMode.values.length, 48);
    });
  });

  group('CalendarType', () {
    test('values', () {
      expect(CalendarType.julian.value, 0);
      expect(CalendarType.gregorian.value, 1);
    });
  });

  // -------------------------------------------------------------------------
  // Config
  // -------------------------------------------------------------------------

  group('EphemerisConfig', () {
    test('default config', () {
      const config = EphemerisConfig();
      expect(config.ephemerisSource, EphemerisSource.moshier);
      expect(config.ephePath, isNull);
      expect(config.siderealMode, isNull);
      expect(config.topographic, isNull);
      expect(config.astroModels, isNull);
      expect(config.tidalAcceleration, isNull);
      expect(config.asteroidNumbers, isEmpty);
      expect(config.planetMoonNumbers, isEmpty);
      expect(config.siderealBits, SiderealBits.none);
      expect(config.siderealT0IsUt, isFalse);
    });

    test('custom config', () {
      const config = EphemerisConfig(
        ephemerisSource: EphemerisSource.swiss,
        ephePath: '/path/to/ephe',
        siderealMode: SiderealMode.lahiri,
        siderealBits: SiderealBits.eclT0,
        topographic: TopoPosition(
          longitude: 13.41,
          latitude: 52.52,
          altitude: 34,
        ),
        asteroidNumbers: [433, 4],
        astroModels: AstroModels(),
      );
      expect(config.ephemerisSource, EphemerisSource.swiss);
      expect(config.siderealMode, SiderealMode.lahiri);
      expect(config.siderealBits, SiderealBits.eclT0);
      expect(config.topographic!.latitude, 52.52);
      expect(config.asteroidNumbers, [433, 4]);
      expect(config.astroModels!.deltaT, DeltaTModel.stephensonEtc2016);
    });
  });

  group('AstroModels', () {
    test('defaults match Rust crate defaults', () {
      const m = AstroModels();
      expect(m.deltaT, DeltaTModel.stephensonEtc2016);
      expect(m.precLongterm, PrecessionModel.vondrak2011);
      expect(m.precShortterm, PrecessionModel.vondrak2011);
      expect(m.nutation, NutationModel.iau2000B);
      expect(m.bias, BiasModel.iau2006);
      expect(m.jplhorMode, JplHorMode.longAgreement);
      expect(m.jplhoraMode, JplHoraMode.v3);
      expect(m.siderealTime, SiderealTimeModel.longterm);
    });
  });
}
