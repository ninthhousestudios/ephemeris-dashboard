# Architecture Map

Living reference for agents planning tasks. Read this first; do targeted
`sutra_read` on specific symbols, not broad exploration sweeps.

Last updated: 2026-06-30 (pre-Ephemeris-seam refactor).

## Provider graph (data flow)

```
sweProvider (SwissEph)          ← swe_service.dart, conditional import
     │
     ├── ephemerisRunnerProvider (EphemerisRunner)
     │        │  wraps SwissEph in TracingSwissEph
     │        │  exposes: run(globals, (eph) => ...), runScoped(override, body)
     │        │  tabs receive the tracer as eph param (currently typed SwissEph)
     │        │
     │        └── callTraceProvider (CallTrace?)
     │                 reads runner.traceEntries + effectiveContext
     │                 gated by calcSession.version (legacy, being removed)
     │
     ├── effectiveContextProvider (EffectiveContext)
     │        merges contextBarState + flagBarState
     │        ← contextBarProvider + flagBarProvider
     │
     └── appliedGlobalsProvider (AppliedGlobals)
              from effectiveContext + resolvedEphePath
              runner._apply() sets these into SwissEph C state
```

## Ephemeris subsystem (lib/core/ephemeris/)

| File | Key types | Role |
|------|-----------|------|
| `tracing_swiss_eph.dart` | `TracingSwissEph` | Production adapter. `implements SwissEph`. Wraps delegate, records CallEntry for ~35 traced methods. ~50 untraced forwarding methods. |
| `trace_model.dart` | `CallEntry`, `CallTrace`, `TraceSlice`, `CallCategory` | Immutable trace data. Category: context/flags/calc/teardown. |
| `runner.dart` | `EphemerisRunner`, `ephemerisRunnerProvider`, `appliedGlobalsProvider`, `callTraceProvider` | Owns the TracingSwissEph singleton. `run()` applies globals then passes tracer to callback. |
| `applied_globals.dart` | `AppliedGlobals` | Value object: ephePath, sidMode, topo, jplFile. |

## Conditional-import split (native/web)

```
swe_service.dart          ← public API: sweProvider, initSweEphePath
  imports swe_service_io.dart      (native: dart:io, loads FFI library)
       if (js_interop) swe_service_stub.dart  (web: throws UnsupportedError)
```

`sweProvider` returns `SwissEph` (concrete FFI type). On web, `_preloadedSwe` is
set by `SwissEph.load()` in `initSweEphePath()` before `runApp()`. On native
desktop, `createDesktopSwissEph()` loads the library synchronously.

## Tab calling patterns

Tabs access the engine two ways:

1. **Via runner.run** (traced): `runner.run(globals, (eph) => eph.calcUt(...))`.
   The `eph` is `TracingSwissEph`, inferred-typed (not explicitly `SwissEph`).
   Methods used: calcUt, calcPctr, houses, getAyanamsaUt, deltat, sidTime,
   nodApsUt, getOrbitalElements, fixstar2Ut, azAlt, azAltRev, cotrans, refrac,
   phenoUt, riseTrans, solCrossUt, moonCrossUt, moonCrossNodeUt, helioCrossUt,
   heliacalUt.

2. **Direct on swe** (untraced): `swe.getPlanetName(body)`, `swe.revjul(jd)`,
   `swe.degnorm(x)`, `swe.houseName(hsys)`, etc. Pure utilities and metadata.
   **Known trace gap:** eclipses_provider.dart calls eclipse methods directly on
   `swe`, bypassing the runner entirely.

## Code emission (lib/core/ephemeris/ + lib/core/emitters/)

| File | Key types |
|------|-----------|
| `swe_symbol_catalog.dart` | `SweSymbolCatalog` — maps SE constants/functions to per-target renderings |
| `c_emitter.dart` | `CEmitter` — renders CallTrace → C source |
| `dart_emitter.dart` | `DartEmitter` — renders CallTrace → Dart source |

Emitters consume a `TraceSlice` (filtered CallTrace) and the Symbol Catalog.

## Context subsystem (lib/core/)

| File | Key types |
|------|-----------|
| `context_state.dart` | `ContextBarState` — immutable: jdUt, lat, lon, alt, zodiacRef, origin, epheSource |
| `context_provider.dart` | `ContextBarNotifier` — edits context, produces ContextBarState |
| `calc_context.dart` | `EffectiveContext` — merges context + flags into iflag, jdUt, lat, lon, alt |
| `flag_definitions.dart` | `FlagDef`, `FlagGroup` — flag metadata, locked/toggle classification |
| `flag_state.dart` | `FlagBarState` — selected flags |
| `flag_provider.dart` | `FlagBarNotifier` — auto-links locked flags from context via ref.listen |
| `calc_session.dart` | `CalcSession` — legacy activation gate, being removed (swe-dashboard/15) |

## Test files (tracing/ephemeris related)

| File | Tests |
|------|-------|
| `test/tracing_swiss_eph_test.dart` | TracingSwissEph: traced methods record CallEntry, untraced don't, error path, tab tag |
| `test/ephemeris_runner_tracing_test.dart` | EphemerisRunner: _apply records setup, run/runScoped delegation, clearTrace, numeric accuracy |
| `test/trace_model_test.dart` | CallEntry, CallTrace, TraceSlice filtering |
| `test/c_emitter_test.dart` | CEmitter rendering |
| `test/dart_emitter_test.dart` | DartEmitter rendering |
| `test/swe_symbol_catalog_test.dart` | SweSymbolCatalog mappings |
| `test/goldens/*.dart` | Widget golden image tests (54 PNGs, 3 sizes x 2 themes) |

## Tabs (lib/tabs/)

16 tab directories, each with `*_tab.dart` (UI) + `*_provider.dart` (state/calc):
planets, houses, ayanamsa, dates, nodes_apsides, stars, coordinates, phenomena,
rise_set, crossings, heliacal, eclipses, differential, planetocentric,
table_view, math, config.
