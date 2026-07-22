// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph_rs/swisseph_rs.dart' show SweException;

import '../ephemeris/applied_globals.dart';
import '../ephemeris/ephemeris.dart';
import '../ephemeris/runner.dart';
import 'calc_outcome.dart';

CalcOutcome<T> _runTabCalc<T>(
  Ref ref,
  T Function(EphemerisRunner runner, AppliedGlobals globals) execute,
) {
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);

  try {
    runner.apply(globals);
    return CalcOk(execute(runner, globals));
  } on SweException catch (e) {
    return CalcSweError(e.message);
  }
}

CalcOutcome<T> runTabCalc<T>(
  Ref ref, {
  required T Function(Ephemeris eph) compute,
}) => _runTabCalc(ref, (runner, _) => compute(runner.eph));

CalcOutcome<T> runTabCalcWithOverrides<T>(
  Ref ref, {
  required T Function(
    Ephemeris eph,
    AppliedGlobals baseGlobals,
    void Function(AppliedGlobals) reconfigure,
  )
  compute,
}) => _runTabCalc(ref, (runner, baseGlobals) {
  return compute(runner.eph, baseGlobals, (overrideGlobals) {
    runner.apply(overrideGlobals);
  });
});
