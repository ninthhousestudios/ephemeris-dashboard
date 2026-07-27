# Architecture Map

Living reference for agents planning tasks. Read this first; do targeted
`sutra_read` on specific symbols, not broad exploration sweeps.

Last updated: 2026-07-23 (swe-dashboard/75: time-scale entry {UT1, TT, UTC} on
the civil time input. `TimeScale` enum on `ContextBarState` (persisted,
advisory — never in a compute); `JdUtils.civilToJdUt`/`jdUtToCivil` own the
scale-aware civil↔JD mapping, `SweUtils.utcToJd`/`jdUt1ToUtc` expose the
engine's date surface, `TimeScaleSelector` in the OPTIONS grid).

Earlier (swe-dashboard/69: horizontal coordinates (azimuth,
altitude, zenith, meridian distance) added to all three body tabs — card toggle
+ series quantity. Shared `horizontalCoordsOf` kernel helper + `horizontal_fields`
widget; `HousePosControls` renamed to `BodyDisplayControls` and now hosts both
the house-position and horizontal toggles).

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
| `calc_outcome.dart` | `CalcOutcome<T>`, `CalcOk<T>`, `CalcError<T>` | Sealed result type. No "not run" variant — per ADR-0001, a tab's result provider is always a projection of the current Context. |
| `moment.dart` | `Moment` | An instant in both time scales: `ut` (canonical) and `et` (via engine ΔT, derived on first access so UT-only calculations pay nothing). `deltaT` is stored, not computed as `et - ut`, which loses precision at JD magnitudes. |
| `series_spec.dart` | `StepUnit`, `SeriesSpec`, `seriesSoftRowCap` (500), `seriesHardRowCap` (2000) | Start Moment + step value/unit + row count → `utAt(index)`. `effectiveRowCount` clamps to the hard cap; `warning` is the user-visible soft/hard-cap message. `StepUnit.advanceFrom` owns the step arithmetic: seconds–weeks are a fixed span of days, months/years step the civil calendar. `StepUnit.acceptsStepValue` is the single gate on step-value input (rejects zero, non-finite, and fractional values on calendar units) — `advanceFrom` must stay total and cannot refuse, so every input path has to ask. |
| `calendar_step.dart` | `addCalendarMonths`, `daysInMonth` | Calendar arithmetic on a Julian Day, in pure Dart integer JDN math (no engine, so series unit tests need no native library). Preserves the time of day and clamps the day of month (31 Jan + 1 month = 28/29 Feb). Clamping is deliberate and is *not* swetest's rule — swetest rolls "31 February" over to 2 March. The goal is the capability, not swetest's exact output. Honours a `Calendar` (Julian/Gregorian variants of the JDN math); under `Calendar.auto` a step re-derives the calendar per resulting date, so a monthly series crosses the Oct 1582 reform gap the way swetest does. |
| `calendar.dart` | `Calendar` (auto/gregorian/julian) | Pure enum: which calendar civil dates read/render on. View-layer only — the Moment (JD) stays canonical. `isGregorianForCivil`/`isGregorianForJd` drive the two conversion directions; `auto` matches swetest (Julian before 15 Oct 1582, gap dates read Julian). Threaded into `JdUtils` (civil entry/display) and `calendar_step` (series stepping); Context-owned via `ContextBarState.calendar`. |
| `flag_masks.dart` | `epheMask`, `epheSourceFlag`, `tropicalEclipticFlag`, `frameOfDateFlag`, `isFrameOfDate`, `equinoxShiftMask`, `isEquinoxOfDate` | The iflag vocabulary, in one place (swe-dashboard/80). `epheSourceFlag` is the argument the engine's bare-ephemeris-flag functions want (riseTrans, the eclipse searches, `heliacalUt`) — `iflag & 0xF` was the wrong spelling, since 8 is `SEFLG_HELCTR`. `tropicalEclipticFlag` strips sidereal/XYZ/**equatorial** (the last is essential: without it, Equatorial-mode RA/Dec reaches `SE_ECL2HOR`); `frameOfDateFlag` also strips J2000/no-nut, and is the contract of everything that combines a body position with an Earth-orientation quantity of the Moment. |
| `horizontal_coords.dart` | `HorizontalCoords`, `horizontalCoordsOf`, `meridianRaOf`, `horizontalExportRows` | The `swe_azalt` (ecl→hor) recipe behind the Ephemeris seam (swe-dashboard/69), shared by the body tabs (Planets/Other Bodies/Stars). Az/true+apparent altitude/zenith distance from `azAlt`, meridian distance from GMST + RA. Fed a tropical ecliptic-of-date position via `frameOfDateFlag`; `meridianRaOf` re-reads the RA of date when the Context frame is not (the *displayed* RA/Dec deliberately stays in the Context frame). Returns `HorizontalCoords.nan` on any engine error. `hasValue` (azimuth non-NaN) is the single gate every consumer uses. Card fields via `lib/widgets/horizontal_fields.dart`. |
| `house_pos.dart` | `HousePosInputs`, `housePosInputs`, `housePosOf`, `houseNumberOf`, `housePositionDegrees` | The `swe_house_pos` recipe (swetest `-fGgj`, swe-dashboard/58) behind the Ephemeris seam, shared by the body tabs (Planets/Other Bodies/Stars). ARMC from a `houses` call, obliquity from `SE_ECL_NUT`, body position via `frameOfDateFlag` (`swe_house_pos` is handle-free and tropical, and its ARMC is of date). `houseNumberOf` = `j.floor()`, `housePositionDegrees` = `(j-1)*30`. |
| `series_table.dart` | `SeriesStep`, `SeriesColumn`, `SeriesTableRow`, `SeriesTable`, `buildSeriesTable`, `seriesFieldLabels` | Folds `List<(Moment, CalcOutcome<List<ExportRow>>)>` into a grid. Column identity is the pair `(ExportRow.header, field label)`; the column set is the union across steps in first-appearance order, so an errored step or a body that drops out leaves a hole in its row instead of shifting columns. `hiddenLabels` filters by field label (the quantity picker is per-quantity, not per-body). Pure — no widgets, no engine. |
| `series_settings.dart` | `SeriesSettings` | Per-tab series-mode state: `enabled`, step value/unit, row count, and the *hidden* label set (stored as hidden so all-on is the default and a quantity added later appears switched on). No start Moment — the Context owns it. |
| `series_settings_provider.dart` | `SeriesSettingsNotifier`, `seriesSettingsProvider` (family, keyed by `TabDescriptor.id`) | Owns and persists one tab's settings. The step-value rules live here, not in the widget: `setStepValue` refuses a value the unit rejects, `setStepUnit` snaps via `StepUnit.snapStepValue` and returns what it took. Keyed by a plain String so `lib/core` stays free of `lib/layout`. |
| `run_tab_calc.dart` | `runTabCalc<T>`, `runTabCalcWithOverrides<T>`, `runTabCalcSeries<T>`, `computeSeries<T>` | Free function (not a provider factory): apply globals → execute compute lambda → envelope in `CalcOutcome`. Synchronous. The compute lambda takes `(Ephemeris, Moment)`; the pointwise Moment is built from `effectiveContextProvider.jdUt`, so tabs no longer read the Context JD themselves. Per-item errors (e.g. one bad body in a list) are caught inside the lambda, `runTabCalc` only catches catastrophic `SweException`. `runTabCalcSeries` takes `SeriesSettings` (the shape) and builds the start Moment from the Context itself, so a tab cannot supply a start; it applies `AppliedGlobals` **once, outside the step loop** (they are Context-derived, not Moment-derived) and returns `List<(Moment, CalcOutcome<T>)>` — one outcome per step, so a failing step does not kill the series. `computeSeries` is the Riverpod-free loop, for tests. |

**Migrated to the kernel:** `planets`, `differential`, `phenomena`,
`planetocentric`, `nodes_apsides`, `stars`, `crossings`, `coordinates`,
`houses`, `rise_set`, `eclipses`, `dates`, `ayanamsa`,
`heliacal`.
Each has a pure `compute*` function + `_*CalcProvider` (via `runTabCalc`) →
`*ResultsProvider` (`CalcOutcome<T>`).
Watches `contextBarProvider` + `flagBarProvider` directly; no
`effectiveContextProvider` gate. Shared
`safeGetName` helper in `lib/core/body_utils.dart` (was duplicated in 4
provider files).

**Per-mode overrides (`runTabCalcWithOverrides` / `runTabCalcSeriesWithOverrides`):**
`ayanamsa` needs a per-mode sidereal config override around each
`getAyanamsaUt`. Uses `AppliedGlobals.withSidMode()` to build per-mode config,
then the `reconfigure` callback to swap the engine config per iteration. No
save/restore — each reconfigure is independent. This is the sanctioned seam
that keeps `lib/tabs/` off `runner.dart` (rule `tabs-use-kernel-not-runner`);
the series variant added for the multi-user-defined feature carries the same
hook through the step loop.

`ayanamsa` also owns a list of user-defined ayanamshas
(`userAyanamsasProvider` → `UserAyanamsaNotifier`, entries keyed by a stable
int id): the tab lets the user add/edit/remove arbitrarily many SE_SIDM_USER
comparisons, separate from the single context-bar user-defined ayanamsha that
drives the other tabs.

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
- `eclipses` (count-loop) keeps its loop inside the compute lambda.
- `formatJdDateTime` in `lib/core/jd_utils.dart` is the single JD→date-string
  formatter (parameterized: `view` (ClockView) / seconds / showLabel /
  emptyPlaceholder / fallbackDigits); it replaced 6 near-duplicate copies across
  eclipses, heliacal, and crossings, plus rise_set's `formattedWithLocal`. UT is
  always the base render; the companion clock is shown in parentheses when it
  differs (with its own date only when it crosses midnight vs UT).
- `output_clock.dart` | `OutputClock` (standard/lmt/lat), `ClockView`.
  Pure leaf: which companion clock is shown alongside UT. UT is canonical;
  the clock only shifts the *displayed* instant (LMT = ut + longitude/15h,
  LAT = LMT + equationOfTime via `SweUtils.timeEqu`, matching swetest -lmt/-lat).
  Global `outputClockProvider` + derived `clockViewProvider` (bundles clock +
  Context longitude + utcOffset) live in `display_format.dart`; the `ClockSelector`
  dropdown sits in the context-bar OPTIONS grid. View-layer only, like Calendar.

## Ephemeris subsystem (lib/core/ephemeris/)

| File | Key types | Role |
|------|-----------|------|
| `ephemeris.dart` | `Ephemeris` | Abstract interface — ~35 calculation methods (no context setters). The seam between tabs and the engine. |
| `rust_eph.dart` | `RustEph` | Production adapter. `implements Ephemeris`. Wraps `rs.Ephemeris` (stateless Rust engine); `reconfigure(EphemerisConfig)` swaps engine. A thin pass-through — no stored config state. |
| `fake_ephemeris.dart` | `FakeEphemeris` | Test adapter. `implements Ephemeris`. Optional `on*` callbacks per method. |
| `runner.dart` | `EphemerisRunner`, `ephemerisRunnerProvider`, `appliedGlobalsProvider` | Owns the RustEph singleton (exposed as `eph`). `apply(globals)` diffs AppliedGlobals, calls `reconfigure` if changed. |
| `applied_globals.dart` | `AppliedGlobals` | Equatable value object: ephePath, sidMode, topo, jplFile. `toEphemerisConfig()` builds `rs.EphemerisConfig`. `withSidMode()` for per-mode overrides. |

## Ephemeris Source bootstrap (`lib/core/ephe/`)

Startup staging — where the `.se1` files come from — is its own module. It is
the app's only conditional-import split, and it is *only* about staging: engine
dispatch needs no split (ADR-0002).

```
bootstrap.dart      ← EpheBootstrap (value), epheBootstrapProvider, bootstrapEpheSource()
  imports staging_io.dart          (native: dart:io, probe execution + asset extraction)
       if (js_interop) staging_web.dart   (web: WASM init + MEMFS load)
probes.dart         ← EpheProbe taxonomy + nativeEpheProbes(PlatformFacts) — pure, no I/O
```

| File | Key symbols | Role |
|------|-------------|------|
| `probes.dart` | `EpheProbe` (sealed: `DirectoryProbe`, `PackageConfigProbe`, `AssetExtractionProbe`), `PlatformFacts`, `nativeEpheProbes`, `epheAssetVersion` | The *ordering policy*: which platform looks where, in what sequence. Pure function of `PlatformFacts`, so every platform's plan is asserted from one test process (`test/ephe/probes_test.dart`). |
| `staging_io.dart` | `stageEpheSource`, `isValidEpheDir`, `currentPlatformFacts` | Executes the plan. First probe yielding a dir with a `.se1` wins; then seeds `<appSupport>/ephe`. |
| `staging_web.dart` | `stageEpheSource` | Loads WASM, pushes bundled assets into MEMFS at `/ephe`. No managed dir. |
| `bootstrap.dart` | `EpheBootstrap`, `StagingFailure`, `epheBootstrapProvider`, `bootstrapEpheSource` | The result as a value: `bundledPath`, `managedPath`, `webFilenames`, `hasEpheFiles`, `failures`/`stagingFailed`. |

A **miss** and a **failure** are different things, and the value keeps them
apart (swe-dashboard/90). A miss is how staging normally narrows down — most
probes miss on any platform, and a build that legitimately ships no `.se1`
files misses every one. A failure means something broke: a corrupt package
config, an asset that would not extract. Each probe classifies its own errors
in `_execute`, because only the probe knows which is which; a blanket catch
one level up cannot tell them apart, and reporting both as "no ephemeris
files" is what made a packaging regression invisible.

Staging never aborts startup — Moshier is a real ephemeris, so a broken probe
leaves a usable app. Failures are collected, logged via `debugPrint`, carried
on `EpheBootstrap.failures`, and shown in the Config tab's library info.
`hasEpheFiles == false` does not imply healthy; check `stagingFailed`.

`main()` awaits `bootstrapEpheSource()` once and installs the result via
`epheBootstrapProvider.overrideWithValue` (the `sharedPrefsProvider` pattern).
The provider throws when unset, so a scope that forgets the override fails
loudly instead of silently reporting "no ephemeris files". Widget tests get it
from `epheBootstrapOverride` in `test/support/widget_fixtures.dart`.

`stageEpheSource` is the single name that must exist on both sides of the
conditional import, and its return type is checked at the call site — a
drifting stub is a compile error, not a runtime surprise.

Consumers read the value, never a global: `resolvedEphePathProvider` and
`ephemerisScanProvider` (`ephe/`), `contextBarProvider` (injects `hasEpheFiles`
into `ContextBarNotifier`), `libraryInfoProvider` (config tab), and the
Ephemeris Manager screen.

## SweUtils

`swe_utils_provider.dart` holds `sweProvider`, which returns `SweUtils`
(utility calls backed by the runner's `rs.Ephemeris`). Nothing else — Source
staging lives in `ephe/` above.

## Tab calling patterns

Tabs access the engine two ways:

1. **Via runTabCalc**: `runTabCalc(ref, compute: (eph) => eph.calcUt(...))`.
   The `eph` is `RustEph`, inferred-typed as `Ephemeris`.
   Methods used: calcUt, calcPctr, houses, housePos, getAyanamsaUt, deltat, sidTime,
   nodApsUt, getOrbitalElements, fixstar2Ut, azAlt, azAltRev, cotrans, refrac,
   phenoUt, riseTrans, solCrossUt, moonCrossUt, moonCrossNodeUt, helioCrossUt,
   heliacalUt.

2. **Via SweUtils**: `swe.getPlanetName(body)`, `swe.revjul(jd)`,
   `swe.degnorm(x)`, `swe.houseName(hsys)`, etc. Pure utilities and metadata,
   delegated to the runner's `rs.Ephemeris` instance.

## Context subsystem (lib/core/)

| File | Key types |
|------|-----------|
| `context_state.dart` | `ContextBarState` — immutable: jdUt, calendar, timeScale, lat, lon, alt, zodiacRef, origin, epheSource |
| `time_scale.dart` | `TimeScale` (ut1/tt/utc) — pure enum: which time scale the civil date/time is entered/displayed on (swetest `-ut`/`-t`/`-utc`). View-layer only, like `Calendar`; the Moment stays a UT1 JD. Threaded into `JdUtils.civilToJdUt`/`jdUtToCivil` (the scale-aware civil↔JD mapping), Context-owned via `ContextBarState.timeScale`. |
| `context_provider.dart` | `ContextBarNotifier` — edits context, produces ContextBarState. Individual setters: setDateTime, setJd, setCalendar, setTimeScale, setUtcOffset, setLatitude, setLongitude, setAltitude, setCityLabel, setOrigin, etc. `setDateTime`/`setJd` read/render civil fields on the current calendar; `setCalendar` re-renders the displayed date from the (canonical) jdUt. The date/time fields commit through `setJd` (having mapped scale-civil → UT1 via `JdUtils.civilToJdUt`). |
| `date_time_input.dart` | Shared helpers: fmtDate, fmtTime, fmtOffset, fmtCoord, parseDateFields, parseTimeFields, labeledField, dateTimeIconButton, showPreciseTimePicker, showInvalidEntry (the revert-and-report snackbar every context-bar entry field uses) |
| `calc_context.dart` | `EffectiveContext` — merges context + flags into iflag, jdUt, lat, lon, alt |
| `flag_definitions.dart` | `FlagDef`, `FlagGroup` — flag metadata, locked/toggle classification |
| `flag_state.dart` | `FlagBarState` — selected flags |
| `flag_provider.dart` | `FlagBarNotifier` — auto-links locked flags from context via ref.listen |
| `active_tab.dart` | `activeTabProvider` (`StateProvider<AppTab>`) — the single source of truth for which tab is on screen, seeded from persistence; `activeTabIdProvider` is a derived `Provider<String>` over its `.name`. Lives in core, not `app_shell.dart`, because non-shell widgets set it (the file-in-use indicator jumps to Charts) and reaching it through the shell is what made app_shell → context_bar → file_in_use_indicator a cycle (swe-dashboard/81). |

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
| `clock_selector.dart` | `ClockSelector` — output-clock dropdown (Standard/LMT/LAT; Standard uses the Context UTC offset, 0 = UT), drives `outputClockProvider` |
| `time_scale_selector.dart` | `TimeScaleSelector` — time-scale dropdown (UT1/TT/UTC) for the civil time input; drives `ContextBarState.timeScale`. Tooltip surfaces the ΔT-vs-ephemeris consequence |
| `context_jd_field.dart` | `ContextJdField` — Julian Day text input |
| `context_location_field.dart` | `ContextLocationField(LocationFieldKind)` — lat/lon/alt/city, parameterized |
| `origin_selector.dart` | `OriginSelector` — geocentric/topocentric/helio dropdown |
| `zodiac_ref_selector.dart` | `ZodiacRefSelector` — tropical/sidereal dropdown |
| `eq_ref_selector.dart` | `EqRefSelector` — equinox reference dropdown |
| `ayanamsa_selector.dart` | `AyanamsaSelector` — sidereal ayanamsa dropdown; user-defined opens `showUserAyanamsaDialog` |
| `user_ayanamsa_dialog.dart` | `showUserAyanamsaDialog` — SE_SIDM_USER params (t0, value, `jdisut`) for the context-bar user-defined ayanamsha (the Ayanamsa tab edits its own list inline, not via this dialog) |
| `projection_selector.dart` | `ProjectionSelector` — sidereal projection plane (SE_SIDBIT_ECL_T0 / SSY_PLANE), disabled when tropical |
| `ephe_source_selector.dart` | `EpheSourceSelector` — ephemeris source dropdown |
| `file_in_use_indicator.dart` | `FileInUseIndicator` — loaded chart file badge |
| `labeled_dropdown.dart` | `LabeledDropdown<T>` — reusable labeled dropdown layout |

## Series widgets (lib/widgets/)

Shared across every eligible tab — they take a `tabId` string and data, never a
tab-specific type, so rolling a tab into series mode is wiring, not new UI.
Sizing follows the CLAUDE.md zoom rules: horizontal-scrolling chip bars,
two-axis scroll and intrinsic column widths in the grid.

| File | Widget |
|------|--------|
| `series_bar.dart` | `SeriesBar(tabId, {trailing})` — mode toggle, read-only start (= Context Moment), step value + unit chips, row count, row-cap warning. Start is read-only because the Context owns the Moment. Optional `trailing` renders on the same row in both modes; the widget adapts its own content to the mode (see `BodyDisplayControls`). |
| `quantity_picker.dart` | `QuantityPicker` — chip row over field labels; pure (labels + hidden set + callback). |
| `house_system_dropdown.dart` | `HouseSystemDropdown({width})` — the one app-wide house-system selector, driving `selectedHouseSystemProvider` + persistence. Used by the Houses tab and `BodyDisplayControls`. |
| `body_display_controls.dart` | `BodyDisplayControls({tabId, housePosToggle, horizontalToggle})` — the body tabs' `SeriesBar.trailing` (renamed from `HousePosControls`, swe-dashboard/69). Card mode: the "Horizontal coords" and "House position" toggles + house-system dropdown while house position is on. Series mode: both are picker quantities, so no toggles — only the house-system dropdown whenever House/House Pos is an active picker quantity. |
| `horizontal_fields.dart` | `horizontalResultFields(HorizontalCoords, DisplayFormat)` — the horizontal-frame `ResultField`s for a single-Moment card, gated by each tab's card toggle. Widget-side twin of the kernel's `horizontalExportRows`. |
| `result_section.dart` | `ResultSection(title, subtitle, flagHex, fields)` + `sectionsToExportRows` — a card's worth of a Result, and its projection into `ExportRow`s. A tab builds its sections once and uses them for *both* encodings (cards and CSV/series columns/quantity chips), so a label or formatter has one home. Adopted by the five tabs that had bespoke unshared field lists and had drifted (swe-dashboard/91: `datesSections`, `eclipseSections`, `diffSections`, `phenomenaSections`, `heliacalSections`); the other tabs already shared a label source of their own (`coordLabels()`, `coordResultToFields`, math's card→export map). |
| `series_grid.dart` | `SeriesGrid` — renders a `SeriesTable`. Moment column + one column per quantity; an `Error` column appears only when some step failed, and errored rows show `—` in the quantity cells. Sticky Moment column deliberately deferred. |
| `series_view.dart` | `SeriesView(tabId, steps, momentLabel)` — picker over grid, wired to `seriesSettingsProvider`. The one widget a tab drops in. Shrink-wraps (`MainAxisSize.min`, no flex child): `AppShell.body` is a `SingleChildScrollView`, so tab content is laid out under unbounded height and an `Expanded` here throws. |

### Wiring a tab into series mode

The Planets tab is the worked example (swe-dashboard/51); Other Bodies and
Stars were rolled out in swe-dashboard/53; Phenomena, Nodes/Apsides,
Planetocentric, and Differential in swe-dashboard/54; Houses, Ayanamsa, and
Dates in swe-dashboard/55 — all eligible tabs now have series mode. Ayanamsa's
lifted compute captures `runner`/`globals` from ref for per-mode `reconfigure`,
using `runTabCalc` instead of `runTabCalcWithOverrides`. Dates ignores the
override JD in series mode (the Context Moment is the series start). Four
pieces, all of them small:

1. **Lift the compute binding** out of the single-Moment provider into a
   `_xCompute(ref)` returning `T Function(Ephemeris, Moment)`, so both modes
   run the identical calculation.
2. **Add `xSeriesProvider`** — `ref.watch(seriesSettingsProvider(AppTab.x.name))`,
   return `const []` when not enabled (recompute is synchronous; a series behind
   a switched-off toggle would tax every Context change), else
   `runTabCalcSeries(ref, compute: _xCompute(ref), settings: settings)`. It
   yields the tab's **typed** result per step, not `ExportRow`s.
3. **Drop in `SeriesBar(tabId: AppTab.x.name)`** above the results divider.
4. **Branch the results body** on `seriesSettingsProvider(...).select((s) => s.enabled)`,
   projecting each step through the tab's existing `xToExportRows` with
   `CalcOutcome.map` and handing the result to `SeriesView`.

## Test files (ephemeris related)

| File | Tests |
|------|-------|
| `test/rust_eph_test.dart` | RustEph: every calculation family, reconfigure, sidereal/topocentric config |
| `test/ephemeris_runner_test.dart` | EphemerisRunner: apply configures engine, skips on unchanged globals, numeric accuracy |
| `test/layout_invariants_test.dart` | Overflow/zoom sweep: 18 surfaces x 3 viewports x 5 text scales. No golden images exist — see CLAUDE.md "Layout Tests" |

## Tab registry (lib/layout/)

| File | Key types | Role |
|------|-----------|------|
| `tab_definitions.dart` | `AppTab` | Enum: label, icon, hasFlags, isMore. Identity for persistence. |
| `tab_descriptor.dart` | `TabDescriptor` | Runtime wiring: content builder, flagBarTrailing. Delegates label/icon/hasFlags to AppTab. |
| `tab_registry.dart` | `tabRegistry`, `tabDescriptorMap` | Ordered list + lookup map. Single source of truth for tab ordering and wiring. Only file that imports tab widgets/providers. |

The shell (`app_shell.dart`) iterates the registry — no tab-specific imports,
no switch statements. Format-toggle trailing widgets (planets, houses,
otherBodies, planetocentric) are `ConsumerWidget`s in their respective tab files.
`test/tab_registry_test.dart` enforces completeness (every AppTab has a descriptor).

## Tabs (lib/tabs/)

17 tab directories, each with `*_tab.dart` (UI) + `*_provider.dart` (state/calc):
planets, houses, ayanamsa, dates, nodes_apsides, stars, coordinates, phenomena,
rise_set, crossings, heliacal, eclipses, differential, planetocentric,
math, config, plus ephemeris_manager (widget, not a tab directory).
