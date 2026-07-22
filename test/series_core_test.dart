// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
import 'package:swe_dashboard/core/calculation/calendar_step.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/calculation/run_tab_calc.dart';
import 'package:swe_dashboard/core/calculation/series_spec.dart';
import 'package:swe_dashboard/core/context_state.dart' show EpheSource;
import 'package:swe_dashboard/core/ephemeris/applied_globals.dart';
import 'package:swe_dashboard/core/ephemeris/fake_ephemeris.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/swe_constants.dart';

const j2000 = 2451545.0;

SeriesSpec _spec({
  double start = j2000,
  double stepValue = 1.0,
  StepUnit unit = StepUnit.days,
  int rows = 5,
}) => SeriesSpec(
  start: Moment(ut: start, deltaT: 0),
  stepValue: stepValue,
  stepUnit: unit,
  rowCount: rows,
);

void main() {
  group('Moment', () {
    test('derives ET from UT via the engine deltaT', () {
      final fake = FakeEphemeris()..onDeltat = (jd) => 0.0008;

      final m = Moment.fromUt(j2000, fake);

      expect(m.ut, j2000);
      expect(m.et, closeTo(j2000 + 0.0008, 1e-12));
      expect(m.deltaT, closeTo(0.0008, 1e-12));
    });

    test('an explicit deltaT survives the constructor intact', () {
      // The lossy form is what this constructor exists to avoid: at Julian Day
      // magnitudes `et - ut` returns 0.000800000037997961 for an exact 0.0008.
      final exact = Moment(ut: j2000, deltaT: 0.0008);
      expect(exact.deltaT, 0.0008);

      final lossy = Moment.fromUtAndEt(ut: j2000, et: j2000 + 0.0008);
      expect(lossy.deltaT, isNot(0.0008));
      expect(lossy.deltaT, closeTo(0.0008, 1e-9));
    });

    test('does not touch the engine unless ET is asked for', () {
      var calls = 0;
      final fake = FakeEphemeris()
        ..onDeltat = (jd) {
          calls++;
          return 0.0008;
        };

      final m = Moment.fromUt(j2000, fake);
      expect(calls, 0);

      m.et;
      m.et;
      expect(calls, 1, reason: 'ET is derived once and cached');
    });
  });

  group('SeriesSpec', () {
    test('utAt steps forward from the start Moment', () {
      final spec = _spec(stepValue: 2.0);
      expect(spec.utAt(0), j2000);
      expect(spec.utAt(3), j2000 + 6.0);
    });

    test('a negative step value runs the series backward', () {
      final spec = _spec(stepValue: -1.0);
      expect(spec.utAt(2), j2000 - 2.0);
    });

    test('row count below the soft cap draws no warning', () {
      expect(_spec(rows: seriesSoftRowCap).warning, isNull);
      expect(_spec(rows: seriesSoftRowCap).effectiveRowCount, seriesSoftRowCap);
    });

    test('above the soft cap warns but still computes every row', () {
      final spec = _spec(rows: seriesSoftRowCap + 1);
      expect(spec.effectiveRowCount, seriesSoftRowCap + 1);
      expect(spec.warning, contains('$seriesSoftRowCap'));
    });

    test('seconds step by a fixed fraction of a day', () {
      final spec = _spec(stepValue: 30.0, unit: StepUnit.seconds);
      expect(spec.utAt(2), closeTo(j2000 + 60.0 / 86400.0, 1e-12));
    });

    test('above the hard cap clamps and says so', () {
      final spec = _spec(rows: seriesHardRowCap + 500);
      expect(spec.effectiveRowCount, seriesHardRowCap);
      expect(spec.warning, contains('capped'));
    });
  });

  group('calendar step units', () {
    // JD at 00:00 UT of the named civil date.
    const jan31y2000 = 2451574.5;
    const feb29y2000 = 2451603.5;
    const mar31y2000 = 2451634.5;
    const apr30y2000 = 2451664.5;
    const jan31y2001 = 2451940.5;
    const feb28y2001 = 2451968.5;

    test('a monthly step lands on the calendar date, clamping the day', () {
      final spec = _spec(start: jan31y2000, unit: StepUnit.months);

      expect(spec.utAt(0), jan31y2000);
      expect(spec.utAt(1), feb29y2000, reason: '31 Jan + 1 month, leap year');
      expect(spec.utAt(2), mar31y2000, reason: 'clamping is not sticky');
      expect(spec.utAt(3), apr30y2000);
    });

    test('February clamps to 28 in a common year', () {
      final spec = _spec(start: jan31y2001, unit: StepUnit.months);
      expect(spec.utAt(1), feb28y2001);
    });

    test('a negative monthly step walks the calendar backward', () {
      final spec = _spec(
        start: mar31y2000,
        stepValue: -1.0,
        unit: StepUnit.months,
      );
      expect(spec.utAt(1), feb29y2000);
    });

    test('a yearly step preserves month, day and time of day', () {
      const noonJan31y2000 = jan31y2000 + 0.5;
      final spec = _spec(start: noonJan31y2000, unit: StepUnit.years);
      expect(spec.utAt(1), jan31y2001 + 0.5);
    });

    test('29 February clamps to the 28th in the following year', () {
      final spec = _spec(start: feb29y2000, unit: StepUnit.years);
      expect(spec.utAt(1), 2451968.5, reason: '28 Feb 2001');
    });

    test('the time of day survives a calendar step', () {
      const fraction = 0.3141592653589793;
      final spec = _spec(start: jan31y2000 + fraction, unit: StepUnit.months);
      // 1e-9 days is 0.1 ms — the ulp of a double at Julian Day magnitudes,
      // which is the precision the start Moment itself carries.
      expect(spec.utAt(1) - feb29y2000, closeTo(fraction, 1e-9));
    });

    test('a multi-month step is a multiple from the start, not an iterated '
        'walk', () {
      final quarterly = _spec(
        start: jan31y2000,
        stepValue: 3.0,
        unit: StepUnit.months,
      );
      expect(quarterly.utAt(1), apr30y2000, reason: '31 Jan + 3 months');

      // Clamping is not associative, so an iterated walk lands elsewhere:
      // 31 Jan -> 29 Feb -> 29 Mar -> 29 Apr. Multiplying from the start is
      // the intended semantic and is what swetest does too — measured:
      // `-s3mo` from 31.1.2000 gives 31.01, 01.05, 31.07, 31.10, i.e.
      // base+3/+6/+9, not a drifting iteration.
      var iterated = jan31y2000;
      for (var i = 0; i < 3; i++) {
        iterated = StepUnit.months.advanceFrom(iterated, 1.0, 1);
      }
      expect(iterated, isNot(quarterly.utAt(1)));
      expect(iterated, apr30y2000 - 1, reason: '29 Apr, one day earlier');
    });

    test('twelve months advance exactly one year at every supported JD', () {
      // The conversion divides by 146097 and by 4/100/400, and Dart's `~/`
      // truncates toward zero. Before this was floored, everything below
      // JDN -32044 (~4800 BCE) jumped by 146463 days — inside the range the
      // standard ephemeris files cover (13201 BCE, JD ~= -3.1e6).
      for (var jdn = 2500000; jdn > -3200000; jdn -= 9973) {
        final delta = addCalendarMonths(jdn + 0.0, 12) - jdn;
        expect(
          delta,
          anyOf(365.0, 366.0),
          reason: 'twelve months from JDN $jdn advanced $delta days',
        );
      }
    });

    test('a yearly round trip returns the original day', () {
      // +12/-12 preserves the day of month everywhere except 29 February,
      // which clamps to the 28th and stays there — so the round trip is
      // either exact or exactly one day short, never anything else. Any
      // conversion error shows up here as an arbitrary offset.
      for (var jdn = 2500000; jdn > -3200000; jdn -= 9973) {
        final start = jdn + 0.0;
        final back = addCalendarMonths(addCalendarMonths(start, 12), -12);
        expect(
          start - back,
          anyOf(0.0, 1.0),
          reason: 'yearly round trip at JDN $jdn drifted ${start - back} days',
        );
      }
    });

    test('a fractional calendar step is rejected, not rounded', () {
      // Rounding 0.25 months produced day offsets [0, 0, 31, 31, 31, 31, 60]
      // — repeated dates then jumps, exported as if valid.
      expect(StepUnit.months.acceptsStepValue(0.25), isFalse);
      expect(StepUnit.years.acceptsStepValue(1.5), isFalse);
      expect(StepUnit.months.acceptsStepValue(3.0), isTrue);
      expect(StepUnit.months.acceptsStepValue(-1.0), isTrue);
      expect(StepUnit.days.acceptsStepValue(0.25), isTrue);
    });

    test('non-finite and zero step values are rejected for every unit', () {
      // `double.tryParse` returns NaN for "NaN" and Infinity for "Infinity"
      // and "1e400", all of which a user can type into the step field. On a
      // calendar unit they reached `.round()` and threw UnsupportedError,
      // which is not a SweException and so escaped the per-step guard.
      for (final unit in StepUnit.values) {
        expect(unit.acceptsStepValue(double.nan), isFalse, reason: '$unit NaN');
        expect(unit.acceptsStepValue(double.infinity), isFalse);
        expect(unit.acceptsStepValue(double.negativeInfinity), isFalse);
        expect(unit.acceptsStepValue(0.0), isFalse);
        expect(unit.acceptsStepValue(-0.0), isFalse);
        expect(unit.acceptsStepValue(1.0), isTrue);
        expect(unit.acceptsStepValue(-1.0), isTrue);
      }
    });

    test('calendar units are flagged as such', () {
      expect(StepUnit.months.isCalendar, isTrue);
      expect(StepUnit.years.isCalendar, isTrue);
      expect(StepUnit.days.isCalendar, isFalse);
      expect(StepUnit.weeks.isCalendar, isFalse);
    });
  });

  group('computeSeries', () {
    test('N steps produce N results at the stepped Moments', () {
      final fake = FakeEphemeris()..onDeltat = (jd) => 0.0;

      final steps = computeSeries(
        fake,
        _spec(rows: 4),
        (eph, moment) => moment.ut,
      );

      expect(steps, hasLength(4));
      expect(steps.map((s) => s.$1.ut), [
        j2000,
        j2000 + 1,
        j2000 + 2,
        j2000 + 3,
      ]);
      expect(steps.map((s) => (s.$2 as CalcOk<double>).value), [
        j2000,
        j2000 + 1,
        j2000 + 2,
        j2000 + 3,
      ]);
    });

    test('a throwing step yields CalcError for that step only', () {
      final fake = FakeEphemeris()..onDeltat = (jd) => 0.0;

      final steps = computeSeries(fake, _spec(rows: 3), (eph, moment) {
        if (moment.ut == j2000 + 1) {
          throw const InvalidArgException('no data for this step');
        }
        return moment.ut;
      });

      expect(steps, hasLength(3));
      expect(steps[0].$2, isA<CalcOk<double>>());
      expect(steps[2].$2, isA<CalcOk<double>>());
      final failed = steps[1].$2;
      expect(failed, isA<CalcError<double>>());
      expect((failed as CalcError<double>).message, 'no data for this step');
    });

    test('a non-Swiss throw is isolated to its own step too', () {
      // The guard is deliberately wider than SweException: a step that throws
      // a plain Dart error must not take the whole table down with it.
      final fake = FakeEphemeris()..onDeltat = (jd) => 0.0;

      final steps = computeSeries(fake, _spec(rows: 3), (eph, moment) {
        if (moment.ut == j2000 + 1) {
          throw StateError('not the engine');
        }
        return moment.ut;
      });

      expect(steps, hasLength(3));
      expect(steps[0].$2, isA<CalcOk<double>>());
      expect(steps[2].$2, isA<CalcOk<double>>());
      expect(steps[1].$2, isA<CalcError<double>>());
      expect(
        (steps[1].$2 as CalcError<double>).message,
        contains('not the engine'),
      );
    });

    test('a step whose Moment cannot be built still yields a row', () {
      // A NaN step value on a calendar unit throws UnsupportedError out of
      // `.round()` inside utAt — before compute is ever reached.
      final fake = FakeEphemeris()..onDeltat = (jd) => 0.0;

      final steps = computeSeries(
        fake,
        _spec(rows: 3, stepValue: double.nan, unit: StepUnit.months),
        (eph, moment) => moment.ut,
      );

      expect(steps, hasLength(3));
      expect(steps.map((s) => s.$2), everyElement(isA<CalcError<double>>()));
      expect(steps[1].$1.ut, isNaN, reason: 'the row is reported at a NaN UT');
    });

    test('the hard cap bounds the number of engine passes', () {
      final fake = FakeEphemeris()..onDeltat = (jd) => 0.0;
      var calls = 0;

      computeSeries(fake, _spec(rows: seriesHardRowCap + 1), (eph, moment) {
        calls++;
        return moment.ut;
      });

      expect(calls, seriesHardRowCap);
    });
  });

  group('engine configuration', () {
    test('a series does not reconfigure the engine per step', () {
      final runner = EphemerisRunner();
      addTearDown(runner.close);

      runner.apply(
        const AppliedGlobals(
          ephePath: null,
          epheSource: EpheSource.moshier,
          sidMode: null,
          userAyanT0: 0,
          userAyanValue: 0,
          topo: null,
          jplFile: null,
        ),
      );
      final engineBefore = runner.eph.engine;

      final steps = computeSeries(
        runner.eph,
        _spec(start: 2460412.5, rows: 10),
        (eph, moment) => eph.calcUt(moment.ut, seSun, seFlgSpeed).longitude,
      );

      expect(steps, hasLength(10));
      expect(
        identical(runner.eph.engine, engineBefore),
        isTrue,
        reason: 'AppliedGlobals are Context-derived, not Moment-derived',
      );
      final longitudes = steps
          .map((s) => (s.$2 as CalcOk<double>).value)
          .toList();
      expect(longitudes.toSet(), hasLength(10));
    });
  });
}
