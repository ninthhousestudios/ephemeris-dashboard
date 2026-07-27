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

  group('a Julian Day shown as a number carries the scale too', () {
    JdUtils? jd;

    setUp(() {
      try {
        jd = JdUtils(SweUtils(EphemerisRunner()));
      } catch (_) {
        // Platform-availability guard, as above.
      }
    });

    // ΔT at J2000, read off the swetest references rather than restated: civil
    // TT noon sits one ΔT step *below* the UT1 Moment, so the same Moment
    // numbered on TT sits one step above it.
    const deltaT = _ut1Jd - _ttJd;

    test('UT1 leaves the Moment as it is', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      expect(jd!.jdOnScale(_ut1Jd, TimeScale.ut1), _ut1Jd);
    });

    test('TT is one ΔT step up from the UT1 Moment', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      expect(
        jd!.jdOnScale(_ut1Jd, TimeScale.tt),
        closeTo(_ut1Jd + deltaT, 1e-9),
      );
    });

    test('UTC has no Julian Day of its own, and says so', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      // JD is a continuous count of days and leap seconds are what such a
      // count cannot express, so the number stays UT1 — within a second of
      // UTC by construction — and the label names UT1 rather than the scale
      // that was asked for.
      expect(jd!.jdOnScale(_ut1Jd, TimeScale.utc), _ut1Jd);
      expect(jdScaleLabel(TimeScale.utc), 'UT1');
    });

    test('the label names the scale the number is on', () {
      expect(jdScaleLabel(TimeScale.ut1), 'UT1');
      expect(jdScaleLabel(TimeScale.tt), 'TT');
    });

    test('the shift agrees with the civil render of the same Moment', () {
      if (jd == null) return markTestSkipped('SwissEph unavailable');
      // The point of routing both through JdUtils: a JD card beside a
      // date-time card must not be two answers to one question. Numbering the
      // Moment on TT and reading its civil fields as UT1 is the same instant
      // as reading the Moment's fields on TT.
      //
      // UTC is excluded because it is the one scale where the two *cannot*
      // agree: its civil render carries the leap seconds that its JD, being a
      // continuous count, does not. That is the divergence `jdScaleLabel`
      // exists to declare — the card says UT1 rather than pretending.
      for (final scale in [TimeScale.ut1, TimeScale.tt]) {
        final viaNumber = jd!.civilFieldsOn(
          jd!.jdOnScale(_ut1Jd, scale),
          Calendar.gregorian,
        );
        final viaCivil = jd!.localCivilOf(
          _ut1Jd,
          calendar: Calendar.gregorian,
          scale: scale,
          offsetHours: 0,
        );
        expect(
          [
            viaNumber.year,
            viaNumber.month,
            viaNumber.day,
            viaNumber.hour,
            viaNumber.minute,
          ],
          [
            viaCivil.year,
            viaCivil.month,
            viaCivil.day,
            viaCivil.hour,
            viaCivil.minute,
          ],
          reason: '$scale',
        );
      }
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
