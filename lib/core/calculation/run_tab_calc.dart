// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph_rs/swisseph_rs.dart' show SweException;

import '../calc_context.dart';
import '../ephemeris/applied_globals.dart';
import '../ephemeris/ephemeris.dart';
import '../ephemeris/runner.dart';
import 'calc_outcome.dart';
import 'moment.dart';
import 'series_settings.dart';
import 'series_spec.dart';

CalcOutcome<T> _runTabCalc<T>(
  Ref ref,
  T Function(EphemerisRunner runner, AppliedGlobals globals, Moment moment)
  execute,
) {
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final jdUt = ref.watch(effectiveContextProvider.select((c) => c.jdUt));

  try {
    runner.apply(globals);
    return CalcOk(execute(runner, globals, Moment.fromUt(jdUt, runner.eph)));
  } on SweException catch (e) {
    return CalcError(e.message);
  }
}

CalcOutcome<T> runTabCalc<T>(
  Ref ref, {
  required T Function(Ephemeris eph, Moment moment) compute,
}) => _runTabCalc(ref, (runner, _, moment) => compute(runner.eph, moment));

CalcOutcome<T> runTabCalcWithOverrides<T>(
  Ref ref, {
  required T Function(
    Ephemeris eph,
    Moment moment,
    AppliedGlobals baseGlobals,
    void Function(AppliedGlobals) reconfigure,
  )
  compute,
}) => _runTabCalc(ref, (runner, baseGlobals, moment) {
  return compute(runner.eph, moment, baseGlobals, (overrideGlobals) {
    runner.apply(overrideGlobals);
  });
});

/// Runs [compute] once per step of the series described by [settings], each
/// step getting its own [CalcOutcome] so one failing step does not kill the
/// series.
///
/// The series starts at the Context Moment, built here rather than taken from
/// the caller: the Context owns the Moment (CLAUDE.md — JD is canonical), so a
/// tab-supplied start would be a second place to set it. [SeriesSettings]
/// carries only the shape of the series, which is the tab's to choose.
///
/// [AppliedGlobals] are Context-derived but not Moment-derived — sidereal
/// mode, topocentric position and ephemeris source do not change as the
/// Moment steps. So the engine is configured once, outside the loop.
List<(Moment, CalcOutcome<T>)> runTabCalcSeries<T>(
  Ref ref, {
  required T Function(Ephemeris eph, Moment moment) compute,
  required SeriesSettings settings,
}) {
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final jdUt = ref.watch(effectiveContextProvider.select((c) => c.jdUt));

  runner.apply(globals);
  return computeSeries(
    runner.eph,
    settings.specFrom(Moment.fromUt(jdUt, runner.eph)),
    compute,
  );
}

/// Series counterpart of [runTabCalcWithOverrides]: each step's [compute] gets
/// the base [AppliedGlobals] and a `reconfigure` hook, so a tab that compares
/// several engine configurations (e.g. Ayanamsa) can vary them per step
/// without reaching the runner directly. The base config is applied once
/// before the loop; per-step reconfiguration is the tab's own concern.
List<(Moment, CalcOutcome<T>)> runTabCalcSeriesWithOverrides<T>(
  Ref ref, {
  required T Function(
    Ephemeris eph,
    Moment moment,
    AppliedGlobals baseGlobals,
    void Function(AppliedGlobals) reconfigure,
  )
  compute,
  required SeriesSettings settings,
}) {
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final jdUt = ref.watch(effectiveContextProvider.select((c) => c.jdUt));

  runner.apply(globals);
  return computeSeries(
    runner.eph,
    settings.specFrom(Moment.fromUt(jdUt, runner.eph)),
    (eph, moment) => compute(eph, moment, globals, (o) => runner.apply(o)),
  );
}

/// The series loop, without Riverpod. The engine must already be configured.
///
/// Error contract, deliberately wider than the engine's: *anything* thrown
/// while building a step's Moment or running [compute] — a [SweException], but
/// equally a RangeError or an UnsupportedError out of a degenerate step value —
/// becomes a [CalcError] for that step alone, and the rest of the series still
/// computes. Per ADR-0001 a tab's result is a synchronous projection of the
/// Context, so an escaping throw costs the whole table rather than one row.
///
/// If the Moment itself could not be built, the row is reported at a NaN UT, so
/// the result length always matches [SeriesSpec.effectiveRowCount].
List<(Moment, CalcOutcome<T>)> computeSeries<T>(
  Ephemeris eph,
  SeriesSpec spec,
  T Function(Ephemeris eph, Moment moment) compute,
) {
  final steps = <(Moment, CalcOutcome<T>)>[];
  for (var i = 0; i < spec.effectiveRowCount; i++) {
    Moment? moment;
    try {
      moment = Moment.fromUt(spec.utAt(i), eph);
      steps.add((moment, CalcOk(compute(eph, moment))));
    } on SweException catch (e) {
      steps.add((moment ?? _unbuiltMoment, CalcError(e.message)));
    } catch (e) {
      steps.add((moment ?? _unbuiltMoment, CalcError(e.toString())));
    }
  }
  return steps;
}

/// Stand-in for a step whose UT could not be computed.
final _unbuiltMoment = Moment(ut: double.nan, deltaT: 0);
