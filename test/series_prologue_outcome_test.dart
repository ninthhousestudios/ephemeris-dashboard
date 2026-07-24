// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// The series prologue must stay inside the outcome envelope.
///
/// Configuring the engine and building the Context Moment both happen before
/// any step exists, and both can throw. The card path has always turned that
/// throw into a `CalcError`; the series path let it escape the provider, so an
/// engine config the runner rejected took down the whole subtree instead of
/// rendering a reason in the table. These pin that both paths now answer the
/// same way.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swisseph_rs/swisseph_rs.dart' show SweException;
import 'package:swisseph_rs/swisseph_rs.dart' as rs;

import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/calculation/run_tab_calc.dart';
import 'package:swe_dashboard/core/calculation/series_settings.dart';
import 'package:swe_dashboard/core/ephemeris/applied_globals.dart';
import 'package:swe_dashboard/core/ephemeris/ephemeris.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/persistence.dart';

/// A runner whose `apply` refuses the config — the shape of a bad ephemeris
/// path, an unsupported sidereal mode or a missing JPL file.
class _RefusingRunner extends EphemerisRunner {
  static const message = 'engine refused the config';

  @override
  void apply(AppliedGlobals globals) =>
      throw const rs.InvalidSiderealModeException(message);
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        ephemerisRunnerProvider.overrideWith((ref) {
          final runner = _RefusingRunner();
          ref.onDispose(runner.close);
          return runner;
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  const settings = SeriesSettings(enabled: true, rowCount: 4);

  int neverRuns(Ephemeris eph, Moment moment) =>
      fail('compute ran despite the prologue failing');

  test('runTabCalcSeries reports a refused config as a CalcError series', () {
    final provider = Provider(
      (ref) =>
          runTabCalcSeries<int>(ref, compute: neverRuns, settings: settings),
    );

    final rows = container.read(provider);

    expect(rows, hasLength(settings.rowCount));
    for (final (moment, outcome) in rows) {
      expect(outcome, isA<CalcError<int>>());
      expect((outcome as CalcError<int>).message, _RefusingRunner.message);
      expect(moment.ut.isNaN, isTrue, reason: 'no step Moment was ever built');
    }
  });

  test('runTabCalcSeriesWithOverrides reports it the same way', () {
    final provider = Provider(
      (ref) => runTabCalcSeriesWithOverrides<int>(
        ref,
        compute: (eph, moment, _, _) => neverRuns(eph, moment),
        settings: settings,
      ),
    );

    final rows = container.read(provider);

    expect(rows, hasLength(settings.rowCount));
    expect(
      rows.every((r) => r.$2 is CalcError<int>),
      isTrue,
      reason: 'the overrides variant let the throw escape the envelope',
    );
  });

  test('the exception never escapes the provider', () {
    final provider = Provider(
      (ref) =>
          runTabCalcSeries<int>(ref, compute: neverRuns, settings: settings),
    );

    // The regression: reading the provider threw, which in the app tore down
    // every widget watching it rather than showing the error in the table.
    expect(() => container.read(provider), returnsNormally);
    expect(() => container.read(provider), isNot(throwsA(isA<SweException>())));
  });
}
