// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

import 'src/agreement.dart';
import 'src/oracle.dart';

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
  // julday / revjul round-trip
  // -----------------------------------------------------------------------

  group('julday', () {
    test('J2000.0 epoch', () {
      final rs = julday(2000, 1, 1, 12.0, CalendarType.gregorian);
      final oc = oracle.julday(2000, 1, 1, 12.0);
      expectAgreement('julday J2000', rs.value, oc, AgreementClass.bitwise);
    });

    test('Julian calendar date', () {
      final rs = julday(1582, 10, 4, 12.0, CalendarType.julian);
      final oc = oracle.julday(1582, 10, 4, 12.0, gregorian: false);
      expectAgreement(
        'julday Julian 1582-10-04',
        rs.value,
        oc,
        AgreementClass.bitwise,
      );
    });

    test('negative year (BCE)', () {
      final rs = julday(-4712, 1, 1, 12.0, CalendarType.julian);
      final oc = oracle.julday(-4712, 1, 1, 12.0, gregorian: false);
      expectAgreement('julday BCE', rs.value, oc, AgreementClass.bitwise);
    });

    test('fractional hour', () {
      final rs = julday(2024, 6, 15, 18.75, CalendarType.gregorian);
      final oc = oracle.julday(2024, 6, 15, 18.75);
      expectAgreement(
        'julday fractional',
        rs.value,
        oc,
        AgreementClass.bitwise,
      );
    });
  });

  group('revjul', () {
    test('J2000.0 round-trip', () {
      const jd = 2451545.0;
      final rs = revjul(jd, CalendarType.gregorian);
      final oc = oracle.revjul(jd);
      expect(rs.year, equals(oc.year));
      expect(rs.month, equals(oc.month));
      expect(rs.day, equals(oc.day));
      expectAgreement('revjul hour', rs.hour, oc.hour, AgreementClass.bitwise);
    });

    test('Julian calendar', () {
      const jd = 2299160.5; // 1582-10-04 Julian
      final rs = revjul(jd, CalendarType.julian);
      final oc = oracle.revjul(jd, gregorian: false);
      expect(rs.year, equals(oc.year));
      expect(rs.month, equals(oc.month));
      expect(rs.day, equals(oc.day));
      expectAgreement(
        'revjul Julian hour',
        rs.hour,
        oc.hour,
        AgreementClass.bitwise,
      );
    });

    test('julday/revjul round-trip preserves components', () {
      final jd = julday(2024, 3, 15, 6.5, CalendarType.gregorian);
      final back = revjul(jd.value, CalendarType.gregorian);
      expect(back.year, equals(2024));
      expect(back.month, equals(3));
      expect(back.day, equals(15));
      expect(back.hour, closeTo(6.5, 1e-8));
    });
  });

  // -----------------------------------------------------------------------
  // dateConversion
  // -----------------------------------------------------------------------

  group('dateConversion', () {
    test('valid Gregorian date', () {
      final rs = dateConversion(2024, 6, 15, 12.0, CalendarType.gregorian);
      final oc = oracle.dateConversion(2024, 6, 15, 12.0);
      expect(oc, isNotNull);
      expectAgreement(
        'dateConversion valid',
        rs.value,
        oc!,
        AgreementClass.bitwise,
      );
    });

    test('invalid date (Feb 30) throws', () {
      expect(
        () => dateConversion(2024, 2, 30, 12.0, CalendarType.gregorian),
        throwsA(isA<InvalidDateException>()),
      );
      final oc = oracle.dateConversion(2024, 2, 30, 12.0);
      expect(oc, isNull);
    });

    test('leap day valid', () {
      final rs = dateConversion(2024, 2, 29, 0.0, CalendarType.gregorian);
      final oc = oracle.dateConversion(2024, 2, 29, 0.0);
      expect(oc, isNotNull);
      expectAgreement(
        'dateConversion leap',
        rs.value,
        oc!,
        AgreementClass.bitwise,
      );
    });

    test('non-leap Feb 29 throws', () {
      expect(
        () => dateConversion(2023, 2, 29, 0.0, CalendarType.gregorian),
        throwsA(isA<InvalidDateException>()),
      );
    });
  });

  // -----------------------------------------------------------------------
  // dayOfWeek
  // -----------------------------------------------------------------------

  group('dayOfWeek', () {
    test('J2000.0 (Saturday)', () {
      const jd = 2451545.0;
      final rs = dayOfWeek(jd);
      final oc = oracle.dayOfWeek(jd);
      expect(rs, equals(oc));
    });

    test('known Monday', () {
      // 2024-01-01 is a Monday
      final jd = julday(2024, 1, 1, 12.0, CalendarType.gregorian);
      final rs = dayOfWeek(jd.value);
      final oc = oracle.dayOfWeek(jd.value);
      expect(rs, equals(oc));
    });
  });

  // -----------------------------------------------------------------------
  // utcTimeZone
  // -----------------------------------------------------------------------

  group('utcTimeZone', () {
    test('IST to UTC (offset 5.5)', () {
      final rs = utcTimeZone(
        const UtcComponents(
          year: 2024,
          month: 6,
          day: 15,
          hour: 18,
          minute: 30,
          second: 0.0,
        ),
        5.5,
      );
      final oc = oracle.utcTimeZone(2024, 6, 15, 18, 30, 0.0, 5.5);
      expect(rs.year, equals(oc.year));
      expect(rs.month, equals(oc.month));
      expect(rs.day, equals(oc.day));
      expect(rs.hour, equals(oc.hour));
      expect(rs.minute, equals(oc.min));
      expectAgreement(
        'utcTimeZone sec',
        rs.second,
        oc.sec,
        AgreementClass.bitwise,
      );
    });

    test('day rollover across midnight', () {
      final rs = utcTimeZone(
        const UtcComponents(
          year: 2024,
          month: 1,
          day: 1,
          hour: 2,
          minute: 0,
          second: 0.0,
        ),
        5.0,
      );
      final oc = oracle.utcTimeZone(2024, 1, 1, 2, 0, 0.0, 5.0);
      expect(rs.year, equals(oc.year));
      expect(rs.month, equals(oc.month));
      expect(rs.day, equals(oc.day));
      expect(rs.hour, equals(oc.hour));
      expect(rs.minute, equals(oc.min));
    });

    test('negative timezone (west)', () {
      final rs = utcTimeZone(
        const UtcComponents(
          year: 2024,
          month: 12,
          day: 31,
          hour: 20,
          minute: 0,
          second: 0.0,
        ),
        -5.0,
      );
      final oc = oracle.utcTimeZone(2024, 12, 31, 20, 0, 0.0, -5.0);
      expect(rs.year, equals(oc.year));
      expect(rs.month, equals(oc.month));
      expect(rs.day, equals(oc.day));
      expect(rs.hour, equals(oc.hour));
    });
  });

  // -----------------------------------------------------------------------
  // utcToJd / jdetToUtc / jdut1ToUtc (Ephemeris methods — need DeltaT)
  // -----------------------------------------------------------------------

  group('utcToJd', () {
    test('J2000.0 epoch', () {
      final rs = eph.utcToJd(
        const UtcComponents(
          year: 2000,
          month: 1,
          day: 1,
          hour: 12,
          minute: 0,
          second: 0.0,
        ),
        CalendarType.gregorian,
      );
      final oc = oracle.utcToJd(2000, 1, 1, 12, 0, 0.0);
      expectAgreement(
        'utcToJd tt',
        rs.tt.value,
        oc.et,
        AgreementClass.positional,
      );
      expectAgreement(
        'utcToJd ut1',
        rs.ut1.value,
        oc.ut1,
        AgreementClass.positional,
      );
    });

    test('modern date', () {
      final rs = eph.utcToJd(
        const UtcComponents(
          year: 2024,
          month: 6,
          day: 15,
          hour: 14,
          minute: 30,
          second: 45.5,
        ),
        CalendarType.gregorian,
      );
      final oc = oracle.utcToJd(2024, 6, 15, 14, 30, 45.5);
      expectAgreement(
        'utcToJd modern tt',
        rs.tt.value,
        oc.et,
        AgreementClass.positional,
      );
      expectAgreement(
        'utcToJd modern ut1',
        rs.ut1.value,
        oc.ut1,
        AgreementClass.positional,
      );
    });
  });

  group('jdetToUtc', () {
    test('round-trip through utcToJd', () {
      const utcIn = UtcComponents(
        year: 2024,
        month: 3,
        day: 20,
        hour: 3,
        minute: 6,
        second: 21.0,
      );
      final jds = eph.utcToJd(utcIn, CalendarType.gregorian);
      final rs = eph.jdetToUtc(jds.tt, CalendarType.gregorian);
      final oc = oracle.jdetToUtc(jds.tt.value);
      expect(rs.year, equals(oc.year));
      expect(rs.month, equals(oc.month));
      expect(rs.day, equals(oc.day));
      expect(rs.hour, equals(oc.hour));
      expect(rs.minute, equals(oc.min));
      expectAgreement(
        'jdetToUtc sec',
        rs.second,
        oc.sec,
        AgreementClass.positional,
      );
    });
  });

  group('jdut1ToUtc', () {
    test('round-trip through utcToJd', () {
      const utcIn = UtcComponents(
        year: 2024,
        month: 7,
        day: 4,
        hour: 18,
        minute: 0,
        second: 0.0,
      );
      final jds = eph.utcToJd(utcIn, CalendarType.gregorian);
      final rs = eph.jdut1ToUtc(jds.ut1, CalendarType.gregorian);
      final oc = oracle.jdut1ToUtc(jds.ut1.value);
      expect(rs.year, equals(oc.year));
      expect(rs.month, equals(oc.month));
      expect(rs.day, equals(oc.day));
      expect(rs.hour, equals(oc.hour));
      expect(rs.minute, equals(oc.min));
      expectAgreement(
        'jdut1ToUtc sec',
        rs.second,
        oc.sec,
        AgreementClass.positional,
      );
    });
  });

  // -----------------------------------------------------------------------
  // deltaT
  // -----------------------------------------------------------------------

  group('deltaT', () {
    test('J2000.0', () {
      const jd = JdUt1(2451545.0);
      final rs = eph.deltaT(jd);
      final oc = oracle.deltat(jd.value);
      expectAgreement('deltaT J2000', rs, oc, AgreementClass.positional);
    });

    test('modern date', () {
      final jd = julday(2024, 6, 15, 12.0, CalendarType.gregorian);
      final rs = eph.deltaT(jd);
      final oc = oracle.deltat(jd.value);
      expectAgreement('deltaT modern', rs, oc, AgreementClass.positional);
    });
  });

  // -----------------------------------------------------------------------
  // siderealTime / siderealTime0
  // -----------------------------------------------------------------------

  group('siderealTime', () {
    test('J2000.0', () {
      const jd = JdUt1(2451545.0);
      final rs = eph.siderealTime(jd);
      final oc = oracle.siderealTime(jd.value);
      expectAgreement('siderealTime J2000', rs, oc, AgreementClass.positional);
    });

    test('modern date', () {
      final jd = julday(2024, 6, 15, 12.0, CalendarType.gregorian);
      final rs = eph.siderealTime(jd);
      final oc = oracle.siderealTime(jd.value);
      expectAgreement('siderealTime modern', rs, oc, AgreementClass.positional);
    });
  });

  group('siderealTime0', () {
    test('explicit obliquity and nutation', () {
      const jd = JdUt1(2451545.0);
      final rs = eph.siderealTime0(jd, 23.44, 0.005);
      final oc = oracle.siderealTime0(jd.value, 23.44, 0.005);
      expectAgreement('siderealTime0', rs, oc, AgreementClass.bitwise);
    });
  });

  // -----------------------------------------------------------------------
  // timeEqu / lmtToLat / latToLmt
  // -----------------------------------------------------------------------

  group('timeEqu', () {
    test('J2000.0', () {
      const jd = 2451545.0;
      final rs = eph.timeEqu(jd);
      final oc = oracle.timeEqu(jd);
      expectAgreement('timeEqu J2000', rs, oc, AgreementClass.positional);
    });
  });

  group('lmtToLat', () {
    test('Greenwich', () {
      const jd = 2451545.0;
      final rs = eph.lmtToLat(jd, 0.0);
      final oc = oracle.lmtToLat(jd, 0.0);
      expectAgreement('lmtToLat Greenwich', rs, oc, AgreementClass.positional);
    });

    test('positive longitude', () {
      const jd = 2451545.0;
      final rs = eph.lmtToLat(jd, 77.5946);
      final oc = oracle.lmtToLat(jd, 77.5946);
      expectAgreement('lmtToLat east', rs, oc, AgreementClass.positional);
    });
  });

  group('latToLmt', () {
    test('round-trip with lmtToLat', () {
      const jdLmt = 2451545.0;
      const geolon = 13.41; // Berlin
      final lat = eph.lmtToLat(jdLmt, geolon);
      final back = eph.latToLmt(lat, geolon);
      final ocLat = oracle.lmtToLat(jdLmt, geolon);
      final ocBack = oracle.latToLmt(ocLat, geolon);
      expectAgreement(
        'latToLmt round-trip',
        back,
        ocBack,
        AgreementClass.positional,
      );
    });
  });

  // -----------------------------------------------------------------------
  // getPlanetName
  // -----------------------------------------------------------------------

  group('getPlanetName', () {
    test('Sun', () {
      final rs = eph.getPlanetName(Body.sun);
      final oc = oracle.getPlanetName(0);
      expect(rs, equals(oc));
    });

    test('Moon', () {
      final rs = eph.getPlanetName(Body.moon);
      final oc = oracle.getPlanetName(1);
      expect(rs, equals(oc));
    });

    test('Pluto', () {
      final rs = eph.getPlanetName(Body.pluto);
      final oc = oracle.getPlanetName(9);
      expect(rs, equals(oc));
    });

    test('TrueNode', () {
      final rs = eph.getPlanetName(Body.trueNode);
      final oc = oracle.getPlanetName(11);
      expect(rs, equals(oc));
    });
  });

  // -----------------------------------------------------------------------
  // splitDegrees
  // -----------------------------------------------------------------------

  group('splitDegrees', () {
    test('positive degrees', () {
      final rs = splitDegrees(123.456789, SplitDegFlags.none);
      final oc = oracle.splitDeg(123.456789, 0);
      expect(rs.degrees, equals(oc.degrees));
      expect(rs.minutes, equals(oc.minutes));
      expect(rs.seconds, equals(oc.seconds));
      expectAgreement(
        'splitDeg secFr',
        rs.secondFraction,
        oc.secondsFraction,
        AgreementClass.bitwise,
      );
      expect(rs.sign, equals(oc.sign));
    });

    test('negative degrees', () {
      final rs = splitDegrees(-45.5, SplitDegFlags.none);
      final oc = oracle.splitDeg(-45.5, 0);
      expect(rs.degrees, equals(oc.degrees));
      expect(rs.minutes, equals(oc.minutes));
      expect(rs.seconds, equals(oc.seconds));
      expect(rs.sign, equals(oc.sign));
    });

    test('zodiacal flag', () {
      final rs = splitDegrees(
        275.5,
        SplitDegFlags.zodiacal | SplitDegFlags.roundSec,
      );
      final oc = oracle.splitDeg(275.5, 8 | 1); // ZODIACAL | ROUND_SEC
      expect(rs.degrees, equals(oc.degrees));
      expect(rs.minutes, equals(oc.minutes));
      expect(rs.seconds, equals(oc.seconds));
      expect(rs.sign, equals(oc.sign));
    });

    test('round to minutes', () {
      final rs = splitDegrees(100.999, SplitDegFlags.roundMin);
      final oc = oracle.splitDeg(100.999, 2); // ROUND_MIN
      expect(rs.degrees, equals(oc.degrees));
      expect(rs.minutes, equals(oc.minutes));
      expect(rs.seconds, equals(oc.seconds));
      expect(rs.sign, equals(oc.sign));
    });
  });

  // -----------------------------------------------------------------------
  // cotrans
  // -----------------------------------------------------------------------

  group('cotrans', () {
    test('ecliptic to equatorial', () {
      const lon = 120.0;
      const lat = 5.0;
      const dist = 1.0;
      const eps = 23.44;
      final rs = cotrans(lon, lat, dist, eps);
      final oc = oracle.cotrans(lon, lat, dist, eps);
      expectAgreement('cotrans lon', rs[0], oc.lon, AgreementClass.bitwise);
      expectAgreement('cotrans lat', rs[1], oc.lat, AgreementClass.bitwise);
      expectAgreement('cotrans dist', rs[2], oc.dist, AgreementClass.bitwise);
    });

    test('zero obliquity is identity', () {
      const lon = 45.0;
      const lat = -10.0;
      const dist = 2.5;
      final rs = cotrans(lon, lat, dist, 0.0);
      final oc = oracle.cotrans(lon, lat, dist, 0.0);
      expectAgreement(
        'cotrans zero-eps lon',
        rs[0],
        oc.lon,
        AgreementClass.bitwise,
      );
      expectAgreement(
        'cotrans zero-eps lat',
        rs[1],
        oc.lat,
        AgreementClass.bitwise,
      );
    });

    test('negative obliquity (equatorial to ecliptic)', () {
      const lon = 200.0;
      const lat = 30.0;
      const dist = 1.0;
      const eps = -23.44;
      final rs = cotrans(lon, lat, dist, eps);
      final oc = oracle.cotrans(lon, lat, dist, eps);
      expectAgreement(
        'cotrans neg-eps lon',
        rs[0],
        oc.lon,
        AgreementClass.bitwise,
      );
      expectAgreement(
        'cotrans neg-eps lat',
        rs[1],
        oc.lat,
        AgreementClass.bitwise,
      );
    });
  });

  // -----------------------------------------------------------------------
  // cotransWithSpeed (engine-trusted — swisseph.dart lacks swe_cotrans_sp)
  // -----------------------------------------------------------------------

  group('cotransWithSpeed', () {
    // Positional, not bitwise: eps=0 makes the rotation an identity, but the
    // engine still routes through polar -> cartesian -> polar, so the inputs
    // do not come back bit-identical (lon=120.0 returns 119.99999999999999,
    // a 1.4e-14 deg round-trip loss). This is a self-consistency check against
    // the literal inputs, not an oracle comparison — swisseph.dart exposes no
    // swe_cotrans_sp — so there is no second implementation to agree bitwise
    // with. Unrelated to the boundary-artifact tolerances in the ledger.
    test('zero obliquity is identity for all six fields', () {
      const lon = 120.0, lat = 5.0, dist = 1.0;
      const lonSpd = 0.5, latSpd = -0.1, distSpd = 0.01;
      final rs = cotransWithSpeed(lon, lat, dist, lonSpd, latSpd, distSpd, 0.0);
      expectAgreement(
        'ctSp zero-eps lon',
        rs[0],
        lon,
        AgreementClass.positional,
      );
      expectAgreement(
        'ctSp zero-eps lat',
        rs[1],
        lat,
        AgreementClass.positional,
      );
      expectAgreement(
        'ctSp zero-eps dist',
        rs[2],
        dist,
        AgreementClass.positional,
      );
      expectAgreement(
        'ctSp zero-eps lonSpd',
        rs[3],
        lonSpd,
        AgreementClass.positional,
      );
      expectAgreement(
        'ctSp zero-eps latSpd',
        rs[4],
        latSpd,
        AgreementClass.positional,
      );
      expectAgreement(
        'ctSp zero-eps distSpd',
        rs[5],
        distSpd,
        AgreementClass.positional,
      );
    });

    test('position fields match cotrans', () {
      const lon = 200.0, lat = -15.0, dist = 1.0, eps = 23.44;
      final pos = cotrans(lon, lat, dist, eps);
      final full = cotransWithSpeed(lon, lat, dist, 0.0, 0.0, 0.0, eps);
      expectAgreement(
        'ctSp vs ct lon',
        full[0],
        pos[0],
        AgreementClass.bitwise,
      );
      expectAgreement(
        'ctSp vs ct lat',
        full[1],
        pos[1],
        AgreementClass.bitwise,
      );
      expectAgreement(
        'ctSp vs ct dist',
        full[2],
        pos[2],
        AgreementClass.bitwise,
      );
    });
  });

  // -----------------------------------------------------------------------
  // normalizeDegrees (engine-trusted, self-test only)
  // -----------------------------------------------------------------------

  group('normalizeDegrees', () {
    test('already in range', () {
      expect(normalizeDegrees(180.0), equals(180.0));
    });

    test('negative', () {
      expect(normalizeDegrees(-90.0), equals(270.0));
    });

    test('over 360', () {
      expect(normalizeDegrees(450.0), equals(90.0));
    });

    test('zero', () {
      expect(normalizeDegrees(0.0), equals(0.0));
    });

    test('exactly 360', () {
      expect(normalizeDegrees(360.0), equals(0.0));
    });
  });

  // -----------------------------------------------------------------------
  // DateTime ↔ JdUt1 round-trip (additive helpers)
  // -----------------------------------------------------------------------

  group('DateTime helpers', () {
    test('round-trip matches julday within bitwise', () {
      final dt = DateTime.utc(2024, 6, 15, 14, 30, 0);
      final fromHelper = dt.toJdUt1();
      final fromJulday = julday(2024, 6, 15, 14.5, CalendarType.gregorian);
      expectAgreement(
        'DateTime vs julday',
        fromHelper.value,
        fromJulday.value,
        AgreementClass.bitwise,
      );
    });

    test('toDateTime round-trip', () {
      final dt = DateTime.utc(2024, 1, 1, 0, 0, 0);
      final jd = dt.toJdUt1();
      final back = jd.toDateTime();
      expect(back.year, equals(dt.year));
      expect(back.month, equals(dt.month));
      expect(back.day, equals(dt.day));
      expect(back.hour, equals(dt.hour));
      expect(back.minute, equals(dt.minute));
      expect(back.second, equals(dt.second));
    });
  });
}
