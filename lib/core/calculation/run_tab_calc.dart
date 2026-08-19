// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph_rs/swisseph_rs.dart' show SweException;

import '../calc_context.dart';
import '../context_provider.dart';
import '../ephemeris/applied_globals.dart';
import '../ephemeris/ephemeris.dart';
import '../ephemeris/runner.dart';
import 'calc_outcome.dart';
import 'moment.dart';
import 'series_settings.dart';
import 'series_settings_provider.dart';
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
}) => _runTabCalcSeries(
  ref,
  settings,
  (eph, moment, _, _) => compute(eph, moment),
);

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
}) => _runTabCalcSeries(ref, settings, compute);

/// Shared body of the two series entry points.
///
/// The prologue — configuring the engine and building the Context Moment the
/// series starts from — happens before any step exists, and both halves can
/// throw [SweException]. That failure is not a property of one step, so it
/// cannot be reported like one; left uncaught it escaped the provider and took
/// down the subtree, while the card path ([_runTabCalc]) turned the identical
/// throw into a [CalcError]. Here it becomes a CalcError on every row, so the
/// series stays inside the outcome envelope and the table renders the reason.
///
/// The row count comes from [SeriesSettings] rather than the [SeriesSpec],
/// because on this path there is no spec — the same clamp [SeriesSpec] applies.
List<(Moment, CalcOutcome<T>)> _runTabCalcSeries<T>(
  Ref ref,
  SeriesSettings settings,
  T Function(
    Ephemeris eph,
    Moment moment,
    AppliedGlobals baseGlobals,
    void Function(AppliedGlobals) reconfigure,
  )
  compute,
) {
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final jdUt = ref.watch(effectiveContextProvider.select((c) => c.jdUt));
  final calendar = ref.watch(contextBarProvider.select((c) => c.calendar));

  final SeriesSpec spec;
  try {
    runner.apply(globals);
    spec = settings.specFrom(Moment.fromUt(jdUt, runner.eph), calendar);
  } on SweException catch (e) {
    return List.generate(
      settings.rowCount.clamp(1, seriesHardRowCap),
      (_) => (_unbuiltMoment, CalcError<T>(e.message)),
    );
  }

  return computeSeries(
    runner.eph,
    spec,
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

/// A tab's per-step calculation: the pure `(Ephemeris, Moment)` compute.
typedef StepCompute<T> = T Function(Ephemeris eph, Moment moment);

/// [StepCompute] with the per-step engine reconfiguration hook — see
/// [runTabCalcSeriesWithOverrides].
typedef StepComputeWithOverrides<T> =
    T Function(
      Ephemeris eph,
      Moment moment,
      AppliedGlobals baseGlobals,
      void Function(AppliedGlobals) reconfigure,
    );

/// The whole of a tab's series provider: the settings for [tabId], the
/// series-mode gate, and the run.
///
/// [compute] is a *factory* rather than the compute itself so that a tab whose
/// series is switched off subscribes to nothing but its series settings. The
/// factories (`_planetsCompute` and friends) watch the tab's own selections,
/// and evaluating one eagerly would make every unrelated selection change
/// re-run a provider that is only going to return no steps.
List<(Moment, CalcOutcome<T>)> seriesSteps<T>(
  Ref ref,
  String tabId, {
  required StepCompute<T> Function() compute,
}) => _seriesSteps(
  ref,
  tabId,
  (settings) => runTabCalcSeries(ref, compute: compute(), settings: settings),
);

/// [seriesSteps] for a tab that varies the engine configuration per step —
/// see [runTabCalcSeriesWithOverrides].
List<(Moment, CalcOutcome<T>)> seriesStepsWithOverrides<T>(
  Ref ref,
  String tabId, {
  required StepComputeWithOverrides<T> Function() compute,
}) => _seriesSteps(
  ref,
  tabId,
  (settings) => runTabCalcSeriesWithOverrides(
    ref,
    compute: compute(),
    settings: settings,
  ),
);

/// Shared gate of the two series-provider entry points.
///
/// The watch/read split is the subtle part, and the reason this lives in one
/// place: only the four fields that *shape* the series are watched, while the
/// settings are then read whole. Hiding a quantity or switching the export
/// layout writes to the same [SeriesSettings] object, and watching it whole
/// would recompute the entire series for a display-only edit.
List<(Moment, CalcOutcome<T>)> _seriesSteps<T>(
  Ref ref,
  String tabId,
  List<(Moment, CalcOutcome<T>)> Function(SeriesSettings settings) run,
) {
  ref.watch(
    seriesSettingsProvider(
      tabId,
    ).select((s) => (s.enabled, s.stepValue, s.stepUnit, s.rowCount)),
  );
  final settings = ref.read(seriesSettingsProvider(tabId));
  // `const`, not `[]`: the empty list is canonicalised, so a provider that
  // re-evaluates with the series still off yields a value `==` to its previous
  // one and Riverpod notifies nobody. A fresh `[]` is never `==` to the last
  // one, and every step edit made while the series is off would rebuild the tab.
  if (!settings.enabled) return const [];
  // A run the user just triggered is held back one frame (same canonical empty
  // list as the disabled case) so the view can paint its "Calculating…"
  // placeholder before the synchronous step loop blocks the isolate. The flag is
  // set by the series controls and cleared by the view once the placeholder is
  // up; see [seriesCalculatingProvider].
  if (ref.watch(seriesCalculatingProvider(tabId))) return const [];
  return run(settings);
}
