// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Julian/Gregorian calendar handling (swe-dashboard/73).
///
/// The reference values are swetest 2.10.03, captured with:
///
/// ```
/// swetest -b4.10.1582  -ut0 -p0 -fTj -n1   # auto → 2299159.5 (jul)
/// swetest -b15.10.1582 -ut0 -p0 -fTj -n1   # auto → 2299160.5 (greg)
/// swetest -b10.10.1582 -ut0 -p0 -fTj -n1   # auto gap → 2299165.5, read as Julian
/// swetest -b5.10.1582j -ut0 -p0 -fTj -n1   # jul  → 2299160.5
/// swetest -b15.9.1582  -ut0 -p0 -fTjY -s1mo -n4   # monthly, crosses the reform
/// ```
///
/// The engine-free half (Calendar enum, calendar_step) is where the series
/// stepping lives, so it carries the gap-crossing assertions. The engine-backed
/// half proves civil entry through JdUtils reproduces the same JDs swetest
/// prints for a typed date.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/calculation/calendar_step.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/calculation/series_settings.dart';
import 'package:swe_dashboard/core/calculation/series_spec.dart';
import 'package:swe_dashboard/core/calendar.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/jd_utils.dart';
import 'package:swe_dashboard/core/swe_utils.dart';

// swetest reference JDs at 0h UT.
const double _oct4_1582jul = 2299159.5; // last Julian day
const double _oct15_1582greg = 2299160.5; // first Gregorian day
const double _sep15_1582jul = 2299140.5;

void main() {
  group('Calendar boundaries', () {
    test('reform JD is 15 Oct 1582 Gregorian midnight', () {
      expect(Calendar.reformJd, _oct15_1582greg);
    });

    test('auto: civil date before 15.10.1582 reads Julian', () {
      expect(Calendar.auto.isGregorianForCivil(1582, 10, 4), isFalse);
      expect(Calendar.auto.isGregorianForCivil(1582, 10, 14), isFalse);
      // Gap dates (5–14 Oct 1582) read as Julian, matching swetest.
      expect(Calendar.auto.isGregorianForCivil(1582, 10, 10), isFalse);
    });

    test('auto: civil date on/after 15.10.1582 reads Gregorian', () {
      expect(Calendar.auto.isGregorianForCivil(1582, 10, 15), isTrue);
      expect(Calendar.auto.isGregorianForCivil(1582, 11, 1), isTrue);
      expect(Calendar.auto.isGregorianForCivil(1583, 1, 1), isTrue);
    });

    test('auto: JD side switches exactly at the reform', () {
      expect(Calendar.auto.isGregorianForJd(_oct4_1582jul), isFalse);
      expect(Calendar.auto.isGregorianForJd(_oct15_1582greg), isTrue);
    });

    test('explicit modes ignore the reform', () {
      expect(Calendar.julian.isGregorianForCivil(2026, 1, 1), isFalse);
      expect(Calendar.gregorian.isGregorianForCivil(-3000, 1, 1), isTrue);
      expect(Calendar.julian.isGregorianForJd(_oct15_1582greg), isFalse);
    });
  });

  group('addCalendarMonths', () {
    test('default is proleptic Gregorian (unchanged behaviour)', () {
      // 31 Jan 2000 + 1 month clamps to 29 Feb 2000 (leap).
      final jan31 = 2451574.5;
      expect(addCalendarMonths(jan31, 1), 2451603.5); // 29 Feb 2000
    });

    test('auto: monthly step crosses the Oct 1582 gap like swetest', () {
      // 15.9.1582 (jul) stepped monthly: 15.10 flips to Gregorian (+20-day
      // jump), then stays Gregorian.
      expect(
        addCalendarMonths(_sep15_1582jul, 1, Calendar.auto),
        _oct15_1582greg,
      );
      expect(
        addCalendarMonths(_sep15_1582jul, 2, Calendar.auto),
        2299191.5,
      ); // 15.11.1582 greg
      expect(
        addCalendarMonths(_sep15_1582jul, 3, Calendar.auto),
        2299221.5,
      ); // 15.12.1582 greg
    });

    test('julian: stays on the Julian calendar across October 1582', () {
      // 15.9.1582 jul + 1 month = 15.10.1582 jul (30 days, no reform jump).
      expect(
        addCalendarMonths(_sep15_1582jul, 1, Calendar.julian),
        _sep15_1582jul + 30.0,
      );
    });

    test(
      'Feb leap rule follows the calendar (1500: Julian leap, not Greg)',
      () {
        // 1500 is divisible by 100 but not 400: a Julian leap year, not a
        // Gregorian one. The reform is irrelevant to the length of February.
        expect(daysInMonth(1500, 2, gregorian: false), 29);
        expect(daysInMonth(1500, 2, gregorian: true), 28);
      },
    );

    test('time of day is carried across a calendar-crossing step', () {
      final atNoon = _sep15_1582jul + 0.5; // 15.9.1582 12:00
      final stepped = addCalendarMonths(atNoon, 1, Calendar.auto);
      expect(stepped - _oct15_1582greg, closeTo(0.5, 1e-9));
    });
  });

  group('series stepping threads the calendar', () {
    test('SeriesSpec.utAt walks the auto calendar across the reform', () {
      const settings = SeriesSettings(
        enabled: true,
        stepValue: 1,
        stepUnit: StepUnit.months,
        rowCount: 4,
      );
      final spec = settings.specFrom(
        // ΔT is irrelevant to civil stepping, so a fixed-ΔT Moment keeps this
        // engine-free.
        Moment(ut: _sep15_1582jul, deltaT: 0),
        Calendar.auto,
      );
      expect(spec.utAt(0), _sep15_1582jul);
      expect(spec.utAt(1), _oct15_1582greg);
      expect(spec.utAt(2), 2299191.5);
      expect(spec.utAt(3), 2299221.5);
    });
  });

  group('civil entry through JdUtils matches swetest', () {
    JdUtils? jd;

    setUp(() {
      try {
        jd = JdUtils(SweUtils(EphemerisRunner()));
      } catch (_) {
        // Native library not available on this platform.
      }
    });

    test('auto: 4.10.1582 → Julian JD; 15.10.1582 → Gregorian JD', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      expect(
        jd!.dateTimeToJd(DateTime.utc(1582, 10, 4), calendar: Calendar.auto),
        closeTo(_oct4_1582jul, 1e-9),
      );
      expect(
        jd!.dateTimeToJd(DateTime.utc(1582, 10, 15), calendar: Calendar.auto),
        closeTo(_oct15_1582greg, 1e-9),
      );
    });

    test('auto: a gap date (10.10.1582) reads as Julian, like swetest', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      expect(
        jd!.dateTimeToJd(DateTime.utc(1582, 10, 10), calendar: Calendar.auto),
        closeTo(2299165.5, 1e-9),
      );
    });

    test('explicit julian: 5.10.1582 → 2299160.5', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      expect(
        jd!.dateTimeToJd(DateTime.utc(1582, 10, 5), calendar: Calendar.julian),
        closeTo(_oct15_1582greg, 1e-9),
      );
    });

    test('auto display: pre-reform JD renders on the Julian calendar', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      final dt = jd!.jdToDateTime(_oct4_1582jul, calendar: Calendar.auto);
      expect([dt.year, dt.month, dt.day], [1582, 10, 4]);
    });
  });
}
