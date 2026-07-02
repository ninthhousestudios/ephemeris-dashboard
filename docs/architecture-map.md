# Architecture Map

Living reference for agents planning tasks. Read this first; do targeted
`sutra_read` on specific symbols, not broad exploration sweeps.

Last updated: 2026-07-01 (post-Ephemeris seam + Calculation kernel).

## Provider graph (data flow)

```
sweProvider (SwissEph)          ← swe_service.dart, conditional import
     │
     ├── ephemerisRunnerProvider (EphemerisRunner)
     │        │  wraps SwissEph in TracingSwissEph
     │        │  exposes: run(globals, (eph) => ...), runScoped(override, body)
     │        │  tabs receive the tracer as eph param (typed Ephemeris)
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

## Calculation kernel (lib/core/calculation/)

| File | Key types | Role |
|------|-----------|------|
| `calc_outcome.dart` | `CalcOutcome<T>`, `CalcOk<T>`, `CalcSweError<T>` | Sealed result type. No "not run" variant — per ADR-0001, a tab's result provider is always a projection of the current Context. |
| `run_tab_calc.dart` | `runTabCalc<T>`, `runTabCalcScoped<T>`, `ScopedRun` | Free function (not a provider factory): tab-tag -> apply-globals -> execute compute lambda -> envelope in `CalcOutcome`. Synchronous. Each tab's result provider watches its own inputs and calls this with a compute lambda; per-item errors (e.g. one bad body in a list) are caught inside the lambda, `runTabCalc` only catches catastrophic `SweException`. Both variants funnel through a shared private `_runTabCalc` envelope. |

**Migrated to the kernel:** `planets`, `differential`, `phenomena`,
`planetocentric`, `nodes_apsides`, `stars`, `crossings`, `coordinates`,
`houses`, `rise_set`, `eclipses`, `table_view`, `dates`, `ayanamsa`,
`heliacal`.
Each has a pure `compute*` function + `_*CalcProvider` (via `runTabCalc`) →
`*ResultsProvider` (`CalcOutcome<T>`) + `*TraceProvider` (`CallTrace`).
Watches `contextBarProvider` + `flagBarProvider` directly; no
`effectiveContextProvider` or `calcSessionProvider` gate. Shared
`safeGetName` helper in `lib/core/body_utils.dart` (was duplicated in 4
provider files).

**Scoped-globals path (`runTabCalcScoped`):** `ayanamsa` needs a per-mode
`setSidMode` override around each `getAyanamsaUt`. `runTabCalcScoped` applies
the base Context globals once (establishing the restore target) then hands the
compute lambda a `ScopedRun` — the runner's `runScoped` capability — so each
mode's override is restored to the Context sidMode in a `finally` instead of
leaking into the process-wide C state. The lambda still only ever sees
`Ephemeris`, never `EphemerisRunner`, keeping the seam intact.

**Deliberate non-kernel tabs:** `math` is a JUSTIFIED EXCEPTION — a stateless
calculator over user-typed inputs; untraced pure math (`degnorm`/`splitDeg`/…)
touching no Applied Globals, so no kernel/`CalcOutcome`/trace. `config` is
OFF-PATTERN by design — a library-metadata reader (`libraryInfoProvider`) with
no Context dependency. Both carry doc comments pointing at swe-dashboard/14.

Richer result shapes among the search / multi-call tabs:
- `dates` and `rise_set` embed **per-field** error strings in their result
  type (all sub-calls run inside one compute lambda; a per-field `SweException`
  becomes an error string, never aborts the batch). `dates` also watches a
  per-tab `datesOverrideJdProvider` and captures `swe` for the untraced
  `revjul`/`dayOfWeek` calendar utilities.
- `eclipses` (count-loop) and `table_view` (bodies × time-steps) keep their
  loops inside the compute lambda. `table_view` has **no** `*TraceProvider`
  (the table has no "view code" affordance).
- `formatJdDateTime` in `lib/core/jd_utils.dart` is the single JD→date-string
  formatter (parameterized: seconds / utLabel / utcOffset / emptyPlaceholder /
  fallbackDigits); it replaced 6 near-duplicate copies across eclipses,
  heliacal, crossings, and table_view.

## Ephemeris subsystem (lib/core/ephemeris/)

| File | Key types | Role |
|------|-----------|------|
| `ephemeris.dart` | `Ephemeris` | Abstract interface — 4 context setters + ~35 calculation methods. The seam between tabs and the engine. |
| `tracing_swiss_eph.dart` | `TracingSwissEph` | Production adapter. `implements Ephemeris`. Wraps `SwissEph` delegate, records CallEntry for every interface method. |
| `fake_ephemeris.dart` | `FakeEphemeris` | Test adapter. `implements Ephemeris`. Optional `on*` callbacks per method; context setters record into `contextCalls`. |
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

## Code emission (lib/core/ephemeris/)

| File | Key types |
|------|-----------|
| `swe_symbol_catalog.dart` | `CodeTarget`, `TracedFunction` (39-value enum), `SymbolPair`, `SweSymbolCatalog` — single source of truth for SE constants and traced functions |
| `code_emitter.dart` | `CodeEmitter` (abstract), `CEmitter`, `DartEmitter` — renders CallTrace → C/Dart source via exhaustive switch on `TracedFunction` |

`TracedFunction` is the canonical registry of all traced SwissEph calls.
`CallEntry.functionName` is `TracedFunction` (not `String`), so both recording
(`TracingSwissEph`) and emission derive from the catalog. Emitter switches are
Dart 3 exhaustive switch expressions — a missing case is a compile error.
Constant lookups (bodies, flags, sidModes) use `CodeTarget`-parameterized
methods backed by unified `SymbolPair`-valued maps.

## Context subsystem (lib/core/)

| File | Key types |
|------|-----------|
| `context_state.dart` | `ContextBarState` — immutable: jdUt, lat, lon, alt, zodiacRef, origin, epheSource |
| `context_provider.dart` | `ContextBarNotifier` — edits context, produces ContextBarState. Individual setters: setDateTime, setJd, setUtcOffset, setLatitude, setLongitude, setAltitude, setCityLabel, setOrigin, etc. |
| `date_time_input.dart` | Shared helpers: fmtDate, fmtTime, fmtOffset, fmtCoord, parseDateFields, parseTimeFields, labeledField, dateTimeIconButton, showPreciseTimePicker |
| `calc_context.dart` | `EffectiveContext` — merges context + flags into iflag, jdUt, lat, lon, alt |
| `flag_definitions.dart` | `FlagDef`, `FlagGroup` — flag metadata, locked/toggle classification |
| `flag_state.dart` | `FlagBarState` — selected flags |
| `flag_provider.dart` | `FlagBarNotifier` — auto-links locked flags from context via ref.listen |
| `calc_session.dart` | `CalcSession` — legacy activation gate, being removed (swe-dashboard/15) |

## Context bar widgets (lib/widgets/context_bar/)

`ContextBar` is a thin composition shell (~310 lines) that arranges shared field
widgets into mobile (2-col, collapsible) and desktop (4-col, horizontal-scroll)
layouts. Each field is a self-contained `ConsumerStatefulWidget` owning its own
controller, focus node, and sync/commit logic.

| File | Widget |
|------|--------|
| `context_bar.dart` | `ContextBar` — layout shell, chart actions, calculate button |
| `context_date_field.dart` | `ContextDateField` — date text + calendar picker |
| `context_time_field.dart` | `ContextTimeField` — time text + clock picker; `showNowButton` param |
| `context_utc_field.dart` | `ContextUtcField` — UTC offset text + half-hour dropdown |
| `context_jd_field.dart` | `ContextJdField` — Julian Day text input |
| `context_location_field.dart` | `ContextLocationField(LocationFieldKind)` — lat/lon/alt/city, parameterized |
| `code_language_selector.dart` | `CodeLanguageSelector` — code emitter language picker |
| `origin_selector.dart` | `OriginSelector` — geocentric/topocentric/helio dropdown |
| `zodiac_ref_selector.dart` | `ZodiacRefSelector` — tropical/sidereal dropdown |
| `eq_ref_selector.dart` | `EqRefSelector` — equinox reference dropdown |
| `ayanamsa_selector.dart` | `AyanamsaSelector` — sidereal ayanamsa dropdown |
| `ephe_source_selector.dart` | `EpheSourceSelector` — ephemeris source dropdown |
| `file_in_use_indicator.dart` | `FileInUseIndicator` — loaded chart file badge |
| `labeled_dropdown.dart` | `LabeledDropdown<T>` — reusable labeled dropdown layout |

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
