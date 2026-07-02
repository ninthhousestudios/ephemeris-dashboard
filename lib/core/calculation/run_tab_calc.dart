import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../calc_context.dart';
import '../ephemeris/applied_globals.dart';
import '../ephemeris/ephemeris.dart';
import '../ephemeris/runner.dart';
import '../ephemeris/trace_model.dart';
import 'calc_outcome.dart';

/// A per-item scoped-globals run: applies [override] to the C state, runs
/// [body], then restores the base Context globals in a `finally`. Mirrors
/// `EphemerisRunner.runScoped` but is the only slice of the runner a tab's
/// compute lambda ever sees — the lambda gets `Ephemeris`, never the runner.
typedef ScopedRun =
    R Function<R>(
      void Function(Ephemeris eph) override,
      R Function(Ephemeris eph) body,
    );

/// Shared envelope: tab-tag -> apply-globals -> execute -> trace/CalcOutcome.
/// Both [runTabCalc] and [runTabCalcScoped] funnel through here so the trace
/// slicing and error handling live in exactly one place. [execute] receives
/// the runner and the resolved base globals; the public variants decide how
/// they hand the engine to their callers.
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
    outcome = CalcOk(execute(runner, globals));
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
}) => _runTabCalc(ref, tabTag, (runner, g) => runner.run(g, compute));

/// Scoped-globals path: applies base globals (so each scoped override restores
/// to the current Context) then hands [compute] the runner's scoped-run
/// capability for per-item C-global overrides (e.g. ayanamsa sidMode). The base
/// `runner.run(g, ...)` establishes `_last = globals`, so each `runScoped`'s
/// `finally` re-applies the base globals.
///
/// Restore is exact only for the C-globals the base Context actually sets. For
/// sidMode specifically: `AppliedGlobals.sidMode` is null under a tropical
/// Context, and `EphemerisRunner._apply` skips a null sidMode (SwissEph has no
/// "unset" — the C sidMode persists). So under a tropical Context the last
/// per-item sidMode is *not* reset and outlives the batch. This is inert —
/// sidMode is only consulted when `SEFLG_SIDEREAL` is set, which a tropical
/// Context never does — and self-heals the moment the Context turns sidereal
/// (globals change → `_apply` runs). Under a sidereal Context the restore is
/// exact. Do not rely on the C sidMode reflecting the Context after this call
/// unless the Context is sidereal.
({CalcOutcome<T> outcome, CallTrace trace}) runTabCalcScoped<T>(
  Ref ref, {
  required String tabTag,
  required T Function(ScopedRun scoped) compute,
}) => _runTabCalc(
  ref,
  tabTag,
  (runner, g) => runner.run(g, (_) => compute(runner.runScoped)),
);
