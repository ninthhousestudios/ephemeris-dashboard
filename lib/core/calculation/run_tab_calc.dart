// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph_rs/swisseph_rs.dart' show SweException;

import '../calc_context.dart';
import '../ephemeris/applied_globals.dart';
import '../ephemeris/ephemeris.dart';
import '../ephemeris/runner.dart';
import '../ephemeris/trace_model.dart';
import 'calc_outcome.dart';

({CalcOutcome<T> outcome, CallTrace trace}) _runTabCalc<T>(
  Ref ref,
  String tabTag,
  T Function(EphemerisRunner runner, AppliedGlobals globals) execute,
) {
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final ectx = ref.watch(effectiveContextProvider);
  runner.setTabTag(tabTag);

  final entriesBefore = runner.traceEntries.length;
  CalcOutcome<T> outcome;
  try {
    runner.apply(globals);
    outcome = CalcOk(execute(runner, globals));
  } on SweException catch (e) {
    outcome = CalcSweError(e.message);
  }

  final List<CallEntry> captured = List.unmodifiable(
    runner.traceEntries.skip(entriesBefore),
  );
  runner.traceEntries.clear();

  final trace = CallTrace(
    entries: captured,
    context: ectx,
    capturedAt: DateTime.now(),
  );

  return (outcome: outcome, trace: trace);
}

({CalcOutcome<T> outcome, CallTrace trace}) runTabCalc<T>(
  Ref ref, {
  required String tabTag,
  required T Function(Ephemeris eph) compute,
}) => _runTabCalc(ref, tabTag, (runner, _) => compute(runner.tracing));

({CalcOutcome<T> outcome, CallTrace trace}) runTabCalcWithOverrides<T>(
  Ref ref, {
  required String tabTag,
  required T Function(
    Ephemeris eph,
    AppliedGlobals baseGlobals,
    void Function(AppliedGlobals) reconfigure,
  )
  compute,
}) => _runTabCalc(ref, tabTag, (runner, baseGlobals) {
  return compute(runner.tracing, baseGlobals, (overrideGlobals) {
    runner.apply(overrideGlobals);
  });
});
