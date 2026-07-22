# Architecture Map

Living reference for agents planning tasks. Read this first; do targeted
`sutra_read` on specific symbols, not broad exploration sweeps.

Last updated: 2026-07-22 (swe-dashboard/47: remove the Call Trace subsystem).

## Provider graph (data flow)

```
ephemerisRunnerProvider (EphemerisRunner)
     │  owns RustEph (stateless rs.Ephemeris, per-instance config)
     │  apply(globals) diffs and calls reconfigure(config) if changed
     │  tabs receive the adapter as eph param (typed Ephemeris)
     │
effectiveContextProvider (EffectiveContext)
     │  merges contextBarState + flagBarState
     │  ← contextBarProvider + flagBarProvider
     │
appliedGlobalsProvider (AppliedGlobals)
     │  from effectiveContext + resolvedEphePath
     │  equatable cache key; toEphemerisConfig() builds rs.EphemerisConfig
```

## Calculation kernel (lib/core/calculation/)

| File | Key types | Role |
|------|-----------|------|
| `calc_outcome.dart` | `CalcOutcome<T>`, `CalcOk<T>`, `CalcSweError<T>` | Sealed result type. No "not run" variant — per ADR-0001, a tab's result provider is always a projection of the current Context. |
| `moment.dart` | `Moment` | An instant in both time scales: `ut` (canonical) and `et` (via engine ΔT, derived on first access so UT-only calculations pay nothing). `deltaT` is stored, not computed as `et - ut`, which loses precision at JD magnitudes. |
| `series_spec.dart` | `StepUnit`, `SeriesSpec`, `seriesSoftRowCap` (500), `seriesHardRowCap` (2000) | Start Moment + step value/unit + row count → `utAt(index)`. `effectiveRowCount` clamps to the hard cap; `warning` is the user-visible soft/hard-cap message. Months are still the 30.4375-day approximation (swe-dashboard/49). |
| `run_tab_calc.dart` | `runTabCalc<T>`, `runTabCalcWithOverrides<T>`, `runTabCalcSeries<T>`, `computeSeries<T>` | Free function (not a provider factory): apply globals → execute compute lambda → envelope in `CalcOutcome`. Synchronous. The compute lambda takes `(Ephemeris, Moment)`; the pointwise Moment is built from `effectiveContextProvider.jdUt`, so tabs no longer read the Context JD themselves. Per-item errors (e.g. one bad body in a list) are caught inside the lambda, `runTabCalc` only catches catastrophic `SweException`. `runTabCalcSeries` applies `AppliedGlobals` **once, outside the step loop** (they are Context-derived, not Moment-derived) and returns `List<(Moment, CalcOutcome<T>)>` — one outcome per step, so a failing step does not kill the series. `computeSeries` is the Riverpod-free loop, for tests. |

**Migrated to the kernel:** `planets`, `differential`, `phenomena`,
`planetocentric`, `nodes_apsides`, `stars`, `crossings`, `coordinates`,
`houses`, `rise_set`, `eclipses`, `table_view`, `dates`, `ayanamsa`,
`heliacal`.
Each has a pure `compute*` function + `_*CalcProvider` (via `runTabCalc`) →
`*ResultsProvider` (`CalcOutcome<T>`).
Watches `contextBarProvider` + `flagBarProvider` directly; no
`effectiveContextProvider` gate. Shared
`safeGetName` helper in `lib/core/body_utils.dart` (was duplicated in 4
provider files).

**Per-mode overrides (`runTabCalcWithOverrides`):** `ayanamsa` needs a
per-mode sidereal config override around each `getAyanamsaUt`. Uses
`AppliedGlobals.withSidMode()` to build per-mode config, then
`reconfigure` callback to swap the engine config per iteration. No
save/restore — each reconfigure is independent.

**Deliberate non-kernel tabs:** `math` is a JUSTIFIED EXCEPTION — a stateless
calculator over user-typed inputs; pure math (`degnorm`/`splitDeg`/…)
touching no Applied Globals, so no kernel/`CalcOutcome`. `config` is
OFF-PATTERN by design — a library-metadata reader (`libraryInfoProvider`) with
no Context dependency. Both carry doc comments pointing at swe-dashboard/14.

Richer result shapes among the search / multi-call tabs:
- `dates` and `rise_set` embed **per-field** error strings in their result
  type (all sub-calls run inside one compute lambda; a per-field `SweException`
  becomes an error string, never aborts the batch). `dates` also watches a
  per-tab `datesOverrideJdProvider` and captures `swe` for the
  `revjul`/`dayOfWeek` calendar utilities.
- `eclipses` (count-loop) and `table_view` (bodies × time-steps) keep their
  loops inside the compute lambda.
- `formatJdDateTime` in `lib/core/jd_utils.dart` is the single JD→date-string
  formatter (parameterized: seconds / utLabel / utcOffset / emptyPlaceholder /
  fallbackDigits); it replaced 6 near-duplicate copies across eclipses,
  heliacal, crossings, and table_view.

## Ephemeris subsystem (lib/core/ephemeris/)

| File | Key types | Role |
|------|-----------|------|
| `ephemeris.dart` | `Ephemeris` | Abstract interface — ~35 calculation methods (no context setters). The seam between tabs and the engine. |
| `rust_eph.dart` | `RustEph` | Production adapter. `implements Ephemeris`. Wraps `rs.Ephemeris` (stateless Rust engine); `reconfigure(EphemerisConfig)` swaps engine. A thin pass-through — no stored config state. |
| `fake_ephemeris.dart` | `FakeEphemeris` | Test adapter. `implements Ephemeris`. Optional `on*` callbacks per method. |
| `runner.dart` | `EphemerisRunner`, `ephemerisRunnerProvider`, `appliedGlobalsProvider` | Owns the RustEph singleton (exposed as `eph`). `apply(globals)` diffs AppliedGlobals, calls `reconfigure` if changed. |
| `applied_globals.dart` | `AppliedGlobals` | Equatable value object: ephePath, sidMode, topo, jplFile. `toEphemerisConfig()` builds `rs.EphemerisConfig`. `withSidMode()` for per-mode overrides. |

## Conditional-import split (native/web)

```
swe_service.dart          ← public API: sweProvider, initSweEphePath
  imports swe_service_io.dart      (native: dart:io, resolves ephe path)
       if (js_interop) swe_service_stub.dart  (web: WASM init + MEMFS)
```

`sweProvider` returns `SweUtils` (utility calls backed by the runner's
`rs.Ephemeris`). `initSweEphePath()` resolves or extracts ephemeris data files
at startup — on web it loads the WASM module and stages `.se1` files into MEMFS;
on native it locates the bundle or dev-mode package path.

## Tab calling patterns

Tabs access the engine two ways:

1. **Via runTabCalc**: `runTabCalc(ref, compute: (eph) => eph.calcUt(...))`.
   The `eph` is `RustEph`, inferred-typed as `Ephemeris`.
   Methods used: calcUt, calcPctr, houses, getAyanamsaUt, deltat, sidTime,
   nodApsUt, getOrbitalElements, fixstar2Ut, azAlt, azAltRev, cotrans, refrac,
   phenoUt, riseTrans, solCrossUt, moonCrossUt, moonCrossNodeUt, helioCrossUt,
   heliacalUt.

2. **Via SweUtils**: `swe.getPlanetName(body)`, `swe.revjul(jd)`,
   `swe.degnorm(x)`, `swe.houseName(hsys)`, etc. Pure utilities and metadata,
   delegated to the runner's `rs.Ephemeris` instance.

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
| `origin_selector.dart` | `OriginSelector` — geocentric/topocentric/helio dropdown |
| `zodiac_ref_selector.dart` | `ZodiacRefSelector` — tropical/sidereal dropdown |
| `eq_ref_selector.dart` | `EqRefSelector` — equinox reference dropdown |
| `ayanamsa_selector.dart` | `AyanamsaSelector` — sidereal ayanamsa dropdown |
| `ephe_source_selector.dart` | `EpheSourceSelector` — ephemeris source dropdown |
| `file_in_use_indicator.dart` | `FileInUseIndicator` — loaded chart file badge |
| `labeled_dropdown.dart` | `LabeledDropdown<T>` — reusable labeled dropdown layout |

## Test files (ephemeris related)

| File | Tests |
|------|-------|
| `test/rust_eph_test.dart` | RustEph: every calculation family, reconfigure, sidereal/topocentric config |
| `test/ephemeris_runner_test.dart` | EphemerisRunner: apply configures engine, skips on unchanged globals, numeric accuracy |
| `test/goldens/*.dart` | Widget golden image tests (54 PNGs, 3 sizes x 2 themes) |

## Tab registry (lib/layout/)

| File | Key types | Role |
|------|-----------|------|
| `tab_definitions.dart` | `AppTab` | Enum: label, icon, hasFlags, isMore. Identity for persistence. |
| `tab_descriptor.dart` | `TabDescriptor` | Runtime wiring: content builder, flagBarTrailing. Delegates label/icon/hasFlags to AppTab. |
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
