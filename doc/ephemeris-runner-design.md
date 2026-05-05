# Ephemeris Runner — Design Sketch

Date: 2026-05-05
Status: proposal, not implemented

## Problem

Three places mutate Swiss Ephemeris C globals; nothing coordinates them.

| Mutator | Where | What it sets |
|---|---|---|
| `EffectiveContext._applyGlobals` | `lib/core/calc_context.dart:55` | `setSidMode`, `setTopo`, `setJplFile` |
| `ephePathApplyProvider` (side effect in `build`) | `lib/core/swe_service.dart:70` | `setEphePath` |
| `_probeSeFile` (scanner) | `lib/core/ephe/scanner.dart:134` | `setEphePath` to probe dir |
| `ayanamsaProvider` (per-mode loop) | `lib/tabs/ayanamsa/ayanamsa_provider.dart:68` | `setSidMode` to each enumerated mode |

The "only `EffectiveContext` sets globals" claim in `calc_context.dart:46`
is already wrong. Worse, `EffectiveContext.calculate()` is a vestigial
seam: every caller invokes it as a no-op (`(s, jd, flags) => null`) just
to trigger `_applyGlobals`, then calls `swe.method(...)` directly. If we
deleted `calculate()` tomorrow and inlined `_applyGlobals` into each
provider, behavior would be identical. Deletion test: fails.

Tabs that currently use the no-op pattern: planets, table_view,
differential, phenomena, crossings, nodes_apsides, houses, stars,
heliacal, eclipses, rise_set, planetocentric. Twelve providers, each
with the same dead callback.

## Goals

1. **One real choke point** for SE calls that depend on C globals. Globals
   set, then call, then result returned, in one place.
2. **Pure utilities stay raw.** `degnorm`, `revjul`, `julday`,
   `splitDeg`, `cotrans`, `refrac`, `deltat`, `getPlanetName`,
   `houseName`, `version`, `dayOfWeek`, `sidTime`, `lmtToLat`,
   `latToLmt`, `radNorm`, `radMidp`, `degMidp` don't touch globals — no
   need to gate them.
3. **Scoped overrides** for the ayanamsa enumeration and the scanner
   probe, so they don't poison the next "real" calculation's globals.
4. **Trace seam.** When v2 tracing arrives, both setup calls
   (`setEphePath`, `setSidMode`, `setTopo`, `setJplFile`) and per-call
   invocations (`calcUt`, `houses`, `phenoUt`, ...) get recorded
   structurally. Design must leave a place for that without committing
   to the trace data shape now.

## Proposal

### Core type: `AppliedGlobals`

A value type that represents the C-global state the runner should
maintain. Subset of `EffectiveContext` plus the ephe path:

```dart
// lib/core/ephemeris/applied_globals.dart

class AppliedGlobals {
  const AppliedGlobals({
    required this.ephePath,        // null = Moshier (no ephe files)
    required this.sidMode,         // null = tropical/none
    required this.userAyanT0,
    required this.userAyanValue,
    required this.topo,            // null = geocentric
    required this.jplFile,         // null = no JPL file selected
  });

  final String? ephePath;
  final int? sidMode;              // -1/null = none; 255 = user-defined
  final double userAyanT0;
  final double userAyanValue;
  final ({double lon, double lat, double alt})? topo;
  final String? jplFile;

  /// Project an [EffectiveContext] + resolved ephe path onto the global
  /// subset. Done once per `run()` call.
  factory AppliedGlobals.fromContext(EffectiveContext ctx, String? ephePath) {
    return AppliedGlobals(
      ephePath: ephePath,
      sidMode: ctx.zodiacRef == ZodiacRef.sidereal && ctx.ayanamsa >= 0
          ? ctx.ayanamsa
          : null,
      userAyanT0: ctx.userAyanT0,
      userAyanValue: ctx.userAyanValue,
      topo: ctx.origin == Origin.topocentric
          ? (lon: ctx.longitude, lat: ctx.latitude, alt: ctx.altitude)
          : null,
      jplFile: ctx.epheSource == EpheSource.jpl ? ctx.jplFilename : null,
    );
  }

  // operator ==, hashCode by all fields — runner skips re-applying when
  // globals haven't changed since the last `run()`.
}
```

### Core type: `EphemerisRunner`

```dart
// lib/core/ephemeris/runner.dart

class EphemerisRunner {
  EphemerisRunner(this._swe);

  final SwissEph _swe;
  AppliedGlobals? _last;

  /// Run a calculation against [globals]. Re-applies globals only if they
  /// differ from the last call (cheap optimization, also lets tracing
  /// distinguish "context changed" from "context unchanged").
  T run<T>(AppliedGlobals globals, T Function(SwissEph eph) body) {
    if (_last != globals) {
      _apply(globals);
      _last = globals;
    }
    return body(_swe);
  }

  /// Temporarily override globals (e.g. ayanamsa enumeration, scanner
  /// probe). Globals are reset to [_last] after [body] returns. If
  /// nothing has been applied yet, [override] runs against whatever the
  /// SwissEph instance currently has.
  T runScoped<T>(
    void Function(SwissEph eph) override,
    T Function(SwissEph eph) body,
  ) {
    override(_swe);
    try {
      return body(_swe);
    } finally {
      if (_last != null) _apply(_last!);
      // else: scoped before any run() — caller is responsible for the
      // pre-state being something they're OK leaving in place. In
      // practice this is the scanner at startup, where there's no
      // "active context" to restore to.
    }
  }

  void _apply(AppliedGlobals g) {
    if (g.ephePath != null) _swe.setEphePath(g.ephePath!);
    if (g.sidMode != null) {
      if (g.sidMode == 255) {
        _swe.setSidMode(255, t0: g.userAyanT0, ayanT0: g.userAyanValue);
      } else {
        _swe.setSidMode(g.sidMode!);
      }
    }
    if (g.topo != null) {
      _swe.setTopo(g.topo!.lon, g.topo!.lat, g.topo!.alt);
    }
    if (g.jplFile != null) _swe.setJplFile(g.jplFile!);
  }
}

final ephemerisRunnerProvider = Provider<EphemerisRunner>((ref) {
  return EphemerisRunner(ref.watch(sweProvider));
});

/// AppliedGlobals projection of the current effective context + resolved
/// ephe path. Watching this means a calc rebuilds when any of those
/// inputs change (which already matches what providers want).
final appliedGlobalsProvider = Provider<AppliedGlobals>((ref) {
  return AppliedGlobals.fromContext(
    ref.watch(effectiveContextProvider),
    ref.watch(resolvedEphePathProvider),
  );
});
```

### What goes away

- `EffectiveContext.calculate()` and `EffectiveContext._applyGlobals()` —
  deleted. `EffectiveContext` becomes a pure value type.
- `ephePathApplyProvider` (the side-effect-in-`build` provider with the
  13-line apologetic comment) — deleted. `setEphePath` only happens via
  the runner.
- The 12 `ectx.calculate(swe, (s, jd, flags) => null);` no-op calls — all
  inlined into runner calls.

### Tab integration

**Before:**

```dart
final planetsResultsProvider = Provider<List<PlanetResult>>((ref) {
  final ectx = ref.watch(effectiveContextProvider);
  final swe = ref.read(sweProvider);
  ectx.calculate(swe, (s, jd, flags) => null);  // dead callback

  for (final body in bodies) {
    final r = swe.calcUt(ectx.jdUt, body, ectx.iflag | seFlgSpeed);
    // ...
  }
});
```

**After:**

```dart
final planetsResultsProvider = Provider<List<PlanetResult>>((ref) {
  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);

  for (final body in bodies) {
    final r = runner.run(
      globals,
      (eph) => eph.calcUt(ectx.jdUt, body, ectx.iflag | seFlgSpeed),
    );
    // ...
  }
});
```

The body still uses raw `SwissEph` inside the closure. We're not
wrapping methods. The runner controls *when* a call happens relative to
global setup; it doesn't try to type-check every SE function.

### Ayanamsa enumeration (scoped override)

```dart
for (final sidMode in modes) {
  final value = runner.runScoped(
    (eph) => eph.setSidMode(sidMode, t0: t0, ayanT0: ayanValue),
    (eph) => eph.getAyanamsaUt(ectx.jdUt),
  );
  // ...
}
```

After the loop, `_last` is restored — next "real" calc on planets etc.
sees the user's actual sidereal mode, not whatever the loop ended on.

### Scanner probe (scoped override)

```dart
final fileData = runner.runScoped(
  (eph) {
    eph.setEphePath(probeDir);
    eph.calcUt(midJd, body, seFlgSwieph);
  },
  (eph) => eph.getCurrentFileData(fileNum),
);
```

Same restore behavior. Scanner can probe a candidate directory without
the next user calc accidentally reading from it.

### Pure utilities — keep raw

These do not touch globals:

```
degnorm, radNorm, splitDeg, degMidp, radMidp,
revjul, julday, lmtToLat, latToLmt, dayOfWeek, sidTime,
cotrans, refrac, deltat,
getPlanetName, houseName, version
```

The math tab, `jd_utils.dart`, the config tab, and incidental
`getPlanetName` calls inside other tabs continue calling
`ref.read(sweProvider).method(...)` directly. No runner, no globals
applied. The line is: **does this call read ephemeris files or
otherwise depend on a C global? Then go through the runner. Otherwise,
raw is fine.**

### Trace seam (deferred but reserved)

Two hook points the runner gives us:

1. `_apply(globals)` — emit a trace entry per setup call that fired
   (only when globals differ from last). Every call after that is
   labeled with the setup that preceded it.
2. `run()` and `runScoped()` — emit a trace entry per body invocation,
   wrapping result and error capture.

For v2, those become:

```dart
T run<T>(AppliedGlobals globals, T Function(SwissEph) body, {String? label}) {
  final tracer = _activeTracer; // set per Calculate press
  if (_last != globals) {
    final setupCalls = _diffApply(globals);
    tracer?.recordSetup(setupCalls);
    _last = globals;
  }
  // The "raw SwissEph passed to body" becomes "tracing proxy of SwissEph
  // passed to body" when a tracer is active. Proxy records each
  // invoked method as a typed CallEntry.
  return tracer == null
      ? body(_swe)
      : body(_tracedSwe(tracer));
}
```

This is what makes the codex-review's "tracing executes through this
seam" possible without rewriting tabs again.

## Migration order

1. Add `AppliedGlobals`, `EphemerisRunner`, `ephemerisRunnerProvider`,
   `appliedGlobalsProvider`. Old code untouched.
2. Convert one tab as a pilot — Planets, since it's the most-used and
   has the simplest call shape. Ensure golden tests pass.
3. Convert remaining no-op-pattern tabs in waves: phenomena,
   nodes_apsides, planetocentric, crossings, differential, table_view,
   houses, stars, heliacal, rise_set, eclipses (each one tab per commit;
   diff is small).
4. Convert ayanamsa to use `runScoped`. Delete the inline `setSidMode`
   logic in its provider.
5. Convert scanner to use `runScoped`. The scanner's `SwissEph` parameter
   becomes an `EphemerisRunner`.
6. Delete `ephePathApplyProvider`. Search for the `ref.read(ephePathApplyProvider)`
   call in `AppShell.initState` and remove it; the runner handles
   `setEphePath` on the next `run()`.
7. Delete `EffectiveContext.calculate()` and `_applyGlobals()`. Verify
   no remaining callers.

Each step is independently reviewable. After step 1, no behavior change.
After step 7, the seam is real.

## Open questions

- **Should `runScoped` accept an `AppliedGlobals` instead of a callback?**
  More uniform, but the ayanamsa enumeration only wants to override
  `sidMode`, not redo `ephePath`/`topo`/`jplFile` 60 times. The callback
  form is more flexible; the cost is that scoped overrides aren't
  trace-friendly without per-method recording (which we'd add when v2
  tracing lands anyway). Keep callback form.
- **Should the runner own the `SwissEph` instance** (replacing
  `sweProvider`), or just borrow it? Borrow, because pure-utility callers
  still need direct access. Two consumers of one underlying instance is
  fine.
- **Threading.** The whole app is single-isolate today; the runner's
  `_last` state is only safe under that assumption. Document it. If we
  ever move calculations off the UI isolate, each isolate gets its own
  runner.
- **What happens if `body` throws inside `run()`?** The exception
  propagates; `_last` is already updated (globals were applied before
  `body` ran). Next call will skip re-apply if globals match. That's
  correct — the C state IS what we set. No recovery needed.
- **Should config tab go through runner?** Currently it calls
  `swe.version()` and `swe.getPlanetName()` — both pure. Stay raw.

## Why this is the right size

It does not introduce a typed-call descriptor model (what Option C in
the codex review hinted at) — that's v2's job, not this wave's. This
wave gives v2 the seam to plug into without forcing the whole call
surface to be re-typed up front. If we tried to do both at once, this
wave would balloon and we'd be guessing at v2's call-entry shape before
we'd built it.
