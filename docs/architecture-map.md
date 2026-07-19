# Architecture Map

Living reference for agents planning tasks. Read this first; do targeted
`sutra_read` on specific symbols, not broad exploration sweeps.

Last updated: 2026-07-19 (swe-dashboard/32: engine migration docs, ADR-0002).

## Provider graph (data flow)

```
ephemerisRunnerProvider (EphemerisRunner)
     │  owns TracingRustEph (stateless rs.Ephemeris, adapter-local config)
     │  exposes: run(globals, (eph) => ...), runScoped(override, body)
     │  tabs receive the tracer as eph param (typed Ephemeris)
     │
effectiveContextProvider (EffectiveContext)
     │  merges contextBarState + flagBarState
     │  ← contextBarProvider + flagBarProvider
     │
appliedGlobalsProvider (AppliedGlobals)
     │  from effectiveContext + resolvedEphePath
     │  runner._apply() diffs and calls _rebuildEngine() if changed
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
`effectiveContextProvider` gate. Shared
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
| `ephemeris.dart` | `Ephemeris` | Abstract interface — context setters + ~35 calculation methods. The seam between tabs and the engine. |
| `tracing_rust_eph.dart` | `TracingRustEph` | Production adapter. `implements Ephemeris`. Wraps `rs.Ephemeris` (stateless Rust engine); rebuilds on config change. Records CallEntry for every interface method. |
| `fake_ephemeris.dart` | `FakeEphemeris` | Test adapter. `implements Ephemeris`. Optional `on*` callbacks per method; context setters record into `contextCalls`. |
| `trace_model.dart` | `CallEntry`, `CallTrace`, `TraceSlice`, `CallCategory` | Immutable trace data. Category: context/flags/calc/teardown. |
| `runner.dart` | `EphemerisRunner`, `ephemerisRunnerProvider`, `appliedGlobalsProvider` | Owns the TracingRustEph singleton. `run()` applies globals (rebuilds engine if config changed) then passes tracer to callback. |
| `applied_globals.dart` | `AppliedGlobals` | Value object: ephePath, sidMode, topo, jplFile. Used for diffing — triggers `_rebuildEngine()` on change. |

## Conditional-import split (native/web)

```
swe_service.dart          ← public API: sweProvider, initSweEphePath
  imports swe_service_io.dart      (native: dart:io, resolves ephe path)
       if (js_interop) swe_service_stub.dart  (web: WASM init + MEMFS)
```

`sweProvider` returns `SweUtils` (untraced utility calls backed by the runner's
`rs.Ephemeris`). `initSweEphePath()` resolves or extracts ephemeris data files
at startup — on web it loads the WASM module and stages `.se1` files into MEMFS;
on native it locates the bundle or dev-mode package path.

## Tab calling patterns

Tabs access the engine two ways:

1. **Via runner.run** (traced): `runner.run(globals, (eph) => eph.calcUt(...))`.
   The `eph` is `TracingRustEph`, inferred-typed as `Ephemeris`.
   Methods used: calcUt, calcPctr, houses, getAyanamsaUt, deltat, sidTime,
   nodApsUt, getOrbitalElements, fixstar2Ut, azAlt, azAltRev, cotrans, refrac,
   phenoUt, riseTrans, solCrossUt, moonCrossUt, moonCrossNodeUt, helioCrossUt,
   heliacalUt.

2. **Via SweUtils** (untraced): `swe.getPlanetName(body)`, `swe.revjul(jd)`,
   `swe.degnorm(x)`, `swe.houseName(hsys)`, etc. Pure utilities and metadata,
   delegated to the runner's `rs.Ephemeris` instance.

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
| `active_tab.dart` | `activeTabIdProvider` — tracks currently selected tab |
| `active_tab_trace.dart` | `activeTraceSourceProvider`, `activeTabTraceProvider` — StateProvider indirection: app_shell sets the per-tab trace source on tab switch; flag bar watches the derived provider |

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
| `test/tracing_rust_eph_test.dart` | TracingRustEph: traced methods record CallEntry, untraced don't, error path, tab tag |
| `test/ephemeris_runner_tracing_test.dart` | EphemerisRunner: _apply records setup, run/runScoped delegation, tab tagging, numeric accuracy |
| `test/trace_model_test.dart` | CallEntry, CallTrace, TraceSlice filtering |
| `test/c_emitter_test.dart` | CEmitter rendering |
| `test/dart_emitter_test.dart` | DartEmitter rendering |
| `test/swe_symbol_catalog_test.dart` | SweSymbolCatalog mappings |
| `test/goldens/*.dart` | Widget golden image tests (54 PNGs, 3 sizes x 2 themes) |

## Tab registry (lib/layout/)

| File | Key types | Role |
|------|-----------|------|
| `tab_definitions.dart` | `AppTab` | Enum: label, icon, hasFlags, isMore. Identity for persistence. |
| `tab_descriptor.dart` | `TabDescriptor` | Runtime wiring: content builder, traceProvider, flagBarTrailing. Delegates label/icon/hasFlags to AppTab. |
| `tab_registry.dart` | `tabRegistry`, `tabDescriptorMap` | Ordered list + lookup map. Single source of truth for tab ordering and wiring. Only file that imports tab widgets/providers. |

The shell (`app_shell.dart`) iterates the registry — no tab-specific imports,
no switch statements. Format-toggle trailing widgets (planets, houses,
tableView, planetocentric) are `ConsumerWidget`s in their respective tab files.
`test/tab_registry_test.dart` enforces completeness (every AppTab has a descriptor).

## Tabs (lib/tabs/)

18 tab directories, each with `*_tab.dart` (UI) + `*_provider.dart` (state/calc):
planets, houses, ayanamsa, dates, nodes_apsides, stars, coordinates, phenomena,
rise_set, crossings, heliacal, eclipses, differential, planetocentric,
table_view, math, config, plus ephemeris_manager (widget, not a tab directory).
