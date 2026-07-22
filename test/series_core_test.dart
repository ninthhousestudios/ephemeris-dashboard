// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
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
  start: Moment(ut: start, et: start),
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

    test('a multi-month step matches repeated single steps', () {
      final quarterly = _spec(
        start: jan31y2000,
        stepValue: 3.0,
        unit: StepUnit.months,
      );
      final monthly = _spec(start: jan31y2000, unit: StepUnit.months);
      expect(quarterly.utAt(1), monthly.utAt(3));
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

    test('a throwing step yields CalcSweError for that step only', () {
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
      expect(failed, isA<CalcSweError<double>>());
      expect((failed as CalcSweError<double>).message, 'no data for this step');
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
