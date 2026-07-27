// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Time-scale entry (UT1 / TT / UTC) on the civil time input (swe-dashboard/75).
///
/// The canonical Moment is always a UT1 Julian Day; the scale is an input
/// transform on the way in and a display label on the way out. Reference JDs
/// are swetest 2.10.03 (Moshier ΔT = 63.828915 s), captured with:
///
/// ```
/// swetest -b1.1.2000 -ut12:00:00  -p0 -fTtj -n1   # UT1 → 2451545.000000000
/// swetest -b1.1.2000  -t12:00:00  -p0 -fTtj -n1   # TT  → 2451544.999261240
/// swetest -b1.1.2000 -utc12:00:00 -p0 -fTtj -n1   # UTC → 2451545.000004110
/// ```
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/calendar.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/jd_utils.dart';
import 'package:swe_dashboard/core/output_clock.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/core/time_scale.dart';

// swetest reference JDs (UT1) for civil 2000-01-01 12:00:00 on each scale.
const double _ut1Jd = 2451545.000000000;
const double _ttJd = 2451544.999261240;
const double _utcJd = 2451545.000004110;

void main() {
  group('TimeScale enum', () {
    test('labels are the swetest scale names', () {
      expect(TimeScale.ut1.label, 'UT1');
      expect(TimeScale.tt.label, 'TT');
      expect(TimeScale.utc.label, 'UTC');
    });
  });

  group('civil entry through JdUtils reproduces swetest', () {
    JdUtils? jd;
    final noon = DateTime.utc(2000, 1, 1, 12, 0, 0);

    setUp(() {
      try {
        jd = JdUtils(SweUtils(EphemerisRunner()));
      } catch (_) {
        // Native library not available on this platform.
      }
    });

    test('UT1: the civil value is the UT1 Julian Day', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      expect(
        jd!.civilToJdUt(
          noon,
          calendar: Calendar.gregorian,
          scale: TimeScale.ut1,
        ),
        closeTo(_ut1Jd, 1e-9),
      );
    });

    test('TT: one ΔT step back to UT1 (swetest -t)', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      expect(
        jd!.civilToJdUt(
          noon,
          calendar: Calendar.gregorian,
          scale: TimeScale.tt,
        ),
        closeTo(_ttJd, 1e-7),
      );
    });

    test('UTC: leap seconds via utc_to_jd (swetest -utc)', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      expect(
        jd!.civilToJdUt(
          noon,
          calendar: Calendar.gregorian,
          scale: TimeScale.utc,
        ),
        closeTo(_utcJd, 1e-7),
      );
    });
  });

  group('display is symmetric with the input scale', () {
    JdUtils? jd;
    final noon = DateTime.utc(2000, 1, 1, 12, 0, 0);

    setUp(() {
      try {
        jd = JdUtils(SweUtils(EphemerisRunner()));
      } catch (_) {
        // Platform-availability guard: leaving `jd` null is the signal each
        // test below reads to markTestSkipped('SwissEph unavailable').
      }
    });

    for (final scale in TimeScale.values) {
      test('$scale: entered fields render back unchanged', () {
        if (jd == null) return markTestSkipped('SwissEph unavailable');
        final ut = jd!.civilToJdUt(
          noon,
          calendar: Calendar.gregorian,
          scale: scale,
        );
        final back = jd!.jdUtToCivil(
          ut,
          calendar: Calendar.gregorian,
          scale: scale,
        );
        expect(
          [
            back.year,
            back.month,
            back.day,
            back.hour,
            back.minute,
            back.second,
          ],
          [2000, 1, 1, 12, 0, 0],
        );
      });
    }

    test('the canonical Moment (UT1) is scale-independent', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      // TT and UTC entry land on a *different* UT1 JD than UT1 entry — the
      // scale changes what civil "12:00" means, not what UT1 means afterwards.
      final ut1 = jd!.civilToJdUt(
        noon,
        calendar: Calendar.gregorian,
        scale: TimeScale.ut1,
      );
      final tt = jd!.civilToJdUt(
        noon,
        calendar: Calendar.gregorian,
        scale: TimeScale.tt,
      );
      expect(ut1 - tt, closeTo(63.828915 / 86400.0, 1e-7));
    });
  });

  // The display direction: a Moment's rendered civil date-time (used by every
  // series row label) must shift with the Context's Scale and Calendar, not
  // just the output clock (swe-dashboard: series shift-with-scale/calendar).
  group('formatJdDateTime honours the Context Scale and Calendar', () {
    SweUtils? swe;

    setUp(() {
      try {
        swe = SweUtils(EphemerisRunner());
      } catch (_) {
        // Native library not available on this platform.
      }
    });

    ClockView view({
      Calendar calendar = Calendar.gregorian,
      TimeScale scale = TimeScale.ut1,
    }) => ClockView(
      clock: OutputClock.standard,
      longitude: 0,
      utcOffset: 0,
      calendar: calendar,
      scale: scale,
    );

    test('base render and label shift with the Scale', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final ut1 = formatJdDateTime(
        swe!,
        _ut1Jd,
        view: view(scale: TimeScale.ut1),
        showCompanion: false,
      );
      final tt = formatJdDateTime(
        swe!,
        _ut1Jd,
        view: view(scale: TimeScale.tt),
        showCompanion: false,
      );
      expect(ut1, contains('UT1'));
      expect(tt, contains('TT'));
      // TT leads UT1 by ΔT, so the rendered instant differs.
      expect(ut1, isNot(equals(tt)));
    });

    test('base render shifts with the Calendar for pre-reform dates', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      const preReformJd = 2268923.5; // ~1500, well before the 1582 reform
      final greg = formatJdDateTime(
        swe!,
        preReformJd,
        view: view(calendar: Calendar.gregorian),
        showLabel: false,
        showCompanion: false,
      );
      final jul = formatJdDateTime(
        swe!,
        preReformJd,
        view: view(calendar: Calendar.julian),
        showLabel: false,
        showCompanion: false,
      );
      // Julian and Gregorian civil dates diverge by ~10 days here.
      expect(greg, isNot(equals(jul)));
    });
  });
}
