import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../calc_context.dart';
import '../ephemeris/ephemeris.dart';
import '../ephemeris/runner.dart';
import '../ephemeris/trace_model.dart';
import 'calc_outcome.dart';

/// Owns the tab-tag -> apply-globals -> execute -> envelope wiring shared by
/// every tab's calculation provider. Resolves the runner and Applied Globals
/// from [ref] itself — callers never touch `EphemerisRunner` directly, which
/// keeps `lib/tabs/**` from reaching past the kernel into
/// `core/ephemeris/runner.dart`. Synchronous by construction.
///
/// Bundles the `CallTrace` produced by this exact invocation alongside the
/// outcome — entries appended to the runner during [compute] — so a tab's
/// "view code" affordance is keyed to the same dependencies as the result
/// it's showing, instead of a separately-cached trace that can go stale or
/// be missing before any legacy activation has run.
({CalcOutcome<T> outcome, CallTrace trace}) runTabCalc<T>(
  Ref ref, {
  required String tabTag,
  required T Function(Ephemeris eph) compute,
}) {
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final ectx = ref.watch(effectiveContextProvider);
  runner.setTabTag(tabTag);

  final entriesBefore = runner.traceEntries.length;
  CalcOutcome<T> outcome;
  try {
    outcome = CalcOk(runner.run(globals, compute));
  } on SweException catch (e) {
    outcome = CalcSweError(e.message);
  }

  final trace = CallTrace(
    entries: List.unmodifiable(runner.traceEntries.skip(entriesBefore)),
    context: ectx,
    capturedAt: DateTime.now(),
  );

  return (outcome: outcome, trace: trace);
}
