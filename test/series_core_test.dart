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

    test('above the hard cap clamps and says so', () {
      final spec = _spec(rows: seriesHardRowCap + 500);
      expect(spec.effectiveRowCount, seriesHardRowCap);
      expect(spec.warning, contains('capped'));
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
