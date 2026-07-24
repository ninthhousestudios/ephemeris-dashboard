# Checkpoint Review — Architecture Pass (2026-07-24)

Scope: all of HEAD at `b087532`, per review pack `/tmp/review-pack-swe-dashboard-2026-07-24`.
Method: vidhi-deepen (candidates only — no grilling loop run; this is the architecture
pass of a two-pass review, the parallel code-review pass owns correctness/slop/naming).
Vocabulary: domain terms per `CONTEXT.md`, architecture terms per vidhi-deepen
`LANGUAGE.md` (module / interface / seam / depth / leverage / locality).

## Verdict (checkpoint form)

**Continue with adjustments.** The deep-module refactor delivered what it promised at
the calculation layer: the kernel (`runTabCalc*`, `CalcOutcome`, `Moment`,
`SeriesSpec`), the Ephemeris seam (real — three adapters: `RustEph`, `FakeEphemeris`,
plus per-mode reconfigure hooks), and the tab registry are genuinely deep and the
governed invariants hold in the code I read. The residual disease the code intel
flagged — sibling tabs co-changing at 50–78% — is real, but it has moved: it no longer
lives in the calculation path, it lives in the **Result presentation path** (card
fields, export rows, series wiring, body pickers), which the refactor never named as a
module. Candidates 1–3 below are the high-leverage cuts; 4–7 are smaller but cheap.

None of the candidates contradicts ADR-0001 or ADR-0002. One friction note against
ADR-0002 is recorded under candidate 5 (it does not warrant reopening the ADR).

---

## Candidate 1 — One quantity schema per tab: derive cards, export rows, and series columns from a single Result presentation

**Rank: highest leverage.** This is the root of the cross-tab lockstep signal.

**Files**
- All 14 kernel tabs: `lib/tabs/*/{*_tab.dart,*_provider.dart}` (16 provider files
  define a `*ToExportRows`; the tab files hand-write parallel `ResultField` lists —
  planets_tab alone carries ~10, nodes_apsides_tab 26)
- `lib/widgets/result_card.dart`, `lib/widgets/horizontal_fields.dart`,
  `lib/core/calculation/horizontal_coords.dart`, `lib/core/calculation/series_table.dart`,
  `lib/core/export_service.dart`

**Shallow-module evidence**
Every tab renders its **Result**'s quantities twice, in two hand-maintained parallel
encodings:

1. *Card view*: a hand-written `List<ResultField>` in `_buildResultCards` (label,
   formatted value, raw value), e.g. `planets_tab.dart:234–373` with its `isXyz`
   format branching inline.
2. *Export/series view*: a `*ToExportRows` function in the provider (label, formatted
   value), e.g. `phenomenaToExportRows`. Series columns and the `QuantityPicker`
   labels derive from these (`seriesFieldLabels` in `series_table.dart:123`), so the
   series grid and the cards agree only by manual discipline.

The smoking gun is that the codebase already institutionalized the duplication:
`horizontal_fields.dart` documents itself as the "widget-side twin of the kernel's
`horizontalExportRows`" — the shared horizontal-coords helper had to be written
*twice*, once per encoding, and every tab that adopts it wires both. The same happened
for house position (swe-dashboard/58) and will happen for every future cross-cutting
quantity. That is exactly the co-change signature the intel found: adding one quantity
touches compute + card fields + export rows (+ picker behavior) × N tabs, with no
static edge between the copies. Labels are stringly coupled — a label typo in one
encoding silently splits a series column from its card field.

The per-tab error/empty rendering is also copied 14×: the
`switch (outcome) { CalcError → Center(text), CalcOk → empty-check → LayoutBuilder
cols (1200/600 breakpoints) → cardWidth arithmetic → Wrap of ResultCards }` block
appears near-verbatim in every tab (`maxWidth > 1200` alone appears 10×).

**Deletion test**: delete any one tab's `*ToExportRows` and its card-field list — the
same quantity list reappears, hand-encoded, in the neighboring 13 tabs. Complexity
reappears across N callers: the missing module was earning nothing because it doesn't
exist yet.

**Proposed deeper module**
A **Result presentation** module per tab: one pure function from the tab's typed
Result to a list of presented quantities, from which *both* encodings derive.

- Interface (kernel side, pure — no widgets, no engine):
  ```dart
  class QuantityField {
    final String label;      // single source for card, export, series column, picker
    final String value;      // formatted per DisplayFormat
    final double? rawValue;  // for the raw-value affordance on cards
  }
  class QuantityRow {        // one body / one house / one row
    final String header;     // ExportRow.header today
    final String? subtitle;  // 'calcUt(4)' etc.
    final String? error;     // per-item error replaces fields, both encodings
    final List<QuantityField> fields;
  }
  List<QuantityRow> Function(T result, DisplayFormat fmt, ...) — the one per-tab function.
  ```
  `ExportRow` becomes a trivial projection (`(label, value)`), `ResultField`s another
  (`label, value, rawValue`). `horizontalQuantityFields(...)` replaces the twin pair.
- Widget side, once: a `ResultCardGrid` widget owning the `CalcOutcome` switch, the
  empty message, the responsive column/cardWidth arithmetic, and the per-card
  overlay slot (the remove-body ✕ button becomes a `Widget Function(QuantityRow)?`).
- What it hides: format branching (`isXyz`, DMS/decimal), per-item error rendering
  parity between cards and grids, label identity across the four consumers, the
  responsive grid recipe (currently also a CLAUDE.md zoom-rule compliance burden
  copied 14×).

**Expected payoff**
- *Locality*: a new cross-cutting quantity = one schema entry per tab (or one shared
  helper), not compute+card+export edits × 14. The 50–78% hidden coupling between
  sibling tabs should collapse to genuinely shared files.
- *Leverage*: card view, CSV/TSV export, series grid, and quantity picker all move
  together by construction; the label-drift failure mode becomes impossible.
- *Tests*: the presentation becomes a pure-function test surface — assert quantities
  for a scripted `FakeEphemeris` result once per tab, with card/export parity free by
  construction instead of untested. Today card field lists are only exercised by
  widget-pumping.

---

## Candidate 2 — Absorb the series wiring into the kernel and `SeriesView`

**Rank: second.** Same disease, narrower cut; sequence it with (or after) candidate 1.

**Files**
- 10+ `*SeriesProvider` blocks (`lib/tabs/*/*_provider.dart`, e.g.
  `stars_provider.dart:422–437`, `phenomena_provider.dart:112–127`)
- 11 `_buildSeries` methods + 11 identical `momentLabel:` lambdas
  (`lib/tabs/*/*_tab.dart`)
- `lib/core/calculation/run_tab_calc.dart`, `lib/widgets/series_view.dart`

**Shallow-module evidence**
Rolling a tab into series mode is documented as "four pieces, all of them small"
(architecture-map §Wiring a tab into series mode) — but three of the four pieces are
the *same* code pasted per tab:

- The `*SeriesProvider` is ~15 lines, identical modulo tab id and compute lambda:
  `select((s) => (enabled, stepValue, stepUnit, rowCount))` → re-read → enabled gate →
  `runTabCalcSeries(ref, compute, settings)`. The subtle part — watching the settings
  *tuple* but reading the full settings so hidden-label changes don't recompute — is
  exactly the kind of invariant that should live once, not survive 10 copy-pastes.
- `_buildSeries` is ~30 lines, identical modulo four identifiers: watch format/steps,
  define `rows`, map each step through `outcome.map(rows)`, and pass the *same*
  `momentLabel: (m) => formatJdDateTime(swe, m.ut, showLabel: false, view: clockView,
  fallbackDigits: 4)` lambda — 11 verbatim copies. The Moment-column rendering policy
  (Context clock view, NaN fallback) is a global policy masquerading as a per-tab
  parameter.

**Deletion test**: deleting any one `*SeriesProvider` or `_buildSeries` reveals no
tab-specific knowledge beyond `(tabId, compute, rows)` — pure pass-through.

**Proposed deeper module**
- Kernel: `List<(Moment, CalcOutcome<T>)> seriesSteps<T>(Ref ref, String tabId,
  {required Compute<T> compute})` — owns the settings watch/read split and the
  enabled gate. Each `*SeriesProvider` body becomes one line. (A `WithOverrides`
  variant keeps the Ayanamsa hook.)
- Widget: `SeriesView` drops its `momentLabel` parameter and computes the Moment
  label itself (it is already a Consumer over `tabId`; `clockView`/`swe` are
  providers, not tab facts). Optionally it takes typed steps + a `rows` function so
  the `outcome.map(rows)` fold also lives once.
- What it hides: the recompute-avoidance select trick, the enabled gate, the Moment
  label policy, the step→rows fold.

**Governed-invariant check**: this *strengthens* "Moment comes from the series step,
never the Context" — the number of places that could get it wrong shrinks from 10+ to
1, and `runTabCalcSeries` remains the sole Context-JD reader.

**Expected payoff**
- *Locality*: changing series recompute policy or the Moment column rendering (e.g.
  the recent calendar/scale work, which is visible in the tabs' co-change history) is
  a one-file edit.
- *Leverage*: wiring tab #15 into series mode approaches the "one descriptor" ideal:
  a compute lambda and a `SeriesBar`/`SeriesView` drop-in with zero pasted plumbing.
- *Tests*: `seriesSteps` gets one unit test for the gate/select semantics instead of
  that behavior being untested ×10.

---

## Candidate 3 — A Body Selection module in `lib/core`: break the 17-file import cycle and deduplicate the body picker

**Rank: third.** This one is also the answer to the intel's cycle lead.

**Files**
- `lib/core/body_selection.dart` (the inversion), `lib/core/ephemeris/runner.dart`
- `lib/tabs/phenomena/phenomena_provider.dart`,
  `lib/tabs/planetocentric/planetocentric_provider.dart`,
  `lib/tabs/nodes_apsides/nodes_apsides_provider.dart` (cycle members)
- Picker UI copies: `planets_tab.dart`, `phenomena_tab.dart`, `nodes_apsides_tab.dart`,
  `differential_tab.dart`, `other_bodies_tab.dart`, `planetocentric_tab.dart`
- Body list data: `planets_provider.dart` (`defaultBodies`/`extraBodies`/
  `uranianBodies`), local `_standardBodies`/`_outerBodies`/`_uranianBodies` consts in
  phenomena/nodes tabs

**Shallow-module evidence**
The import cycle the intel flagged is one SCC of **17 files** spanning `lib/core` and
`lib/tabs`. The inverted edge is `lib/core/body_selection.dart` importing three tab
providers (`nodesBodyProvider`, `phenomenaBodiesProvider`,
`planetocentricBodiesProvider`) to aggregate which asteroid/planet-moon **Ephemeris
Source** files the engine config must declare (`swisseph_rs` fails engine creation on
a missing declared file). Core→tabs→core: `runner.dart` → `body_selection.dart` →
`phenomena_provider.dart` → `run_tab_calc.dart` → `runner.dart`. Consequences:

- Engine construction depends on every tab that grows a body selection, by hand-edit
  of a core file — a new body-selecting tab that forgets to register here silently
  produces a broken engine config for its asteroids/moons.
- The SCC destroys navigability: 17 files are one strongly-connected blob to any
  dependency-ordered tool or reader.
- Meanwhile the selection *state* is split arbitrarily: planets/other_bodies
  selections live in core (`body_selection.dart`), phenomena/planetocentric/nodes
  selections live in their tabs.

The picker *UI* over these selections (chip row + "More bodies" disclosure + Uranian
section + asteroid section + add-custom-asteroid/comet fields) is copy-pasted across
6 tab files with cosmetic drift (ints vs `(int, String)` tuples), and the body
*catalog* data is split between `planets_provider.dart` (imported cross-tab by
differential) and private consts duplicated in phenomena/nodes.

**Proposed deeper module**
A **Body Selection** module in `lib/core` (it is Context-adjacent state: which bodies
each tab computes for):

- Interface:
  - `bodySelectionProvider` — a family keyed by tab id (same pattern as
    `seriesSettingsProvider`, which already solved the "core keyed by plain String so
    core stays free of layout" problem), replacing the five scattered
    StateProviders. Tabs watch/set their own key; core aggregates over the family's
    known keys instead of importing tab files.
  - `selectedAsteroidMpcProvider` / `selectedPlanetMoonIdsProvider` keep their
    current interface (runner-facing), now derived without tabs imports.
  - A `BodyCatalog` value (sections: standard / outer / uranian / named asteroids)
    in core, replacing the planets_provider exports and the private tab consts.
  - One `BodyPicker` widget (chips + disclosure + sections + optional custom-entry
    row) over `(BodyCatalog, tabId)`.
- What it hides: the installed-file filtering against the **Ephemeris Source** scan,
  the MPC/moon id arithmetic, the chip/disclosure layout (and its zoom-rule
  compliance), the catalog's labels.

**Expected payoff**
- *Locality*: the SCC dissolves — `lib/core` regains a clean downward-only layering;
  a new body-selecting tab gets engine-config aggregation for free instead of by
  remembering to edit a core file.
- *Leverage*: six picker copies become one widget; catalog edits (new named asteroid)
  are one-place.
- *Tests*: the aggregation (selection → declared files) becomes a pure provider test;
  today it is only exercised through the app.

---

## Candidate 4 — A Context persistence codec: one entry per field instead of four hand-synchronized lists

**Files**
- `lib/core/persistence.dart` (`saveContextBar` 17 setters, `loadContextBar` 17
  guarded reads, plus flag/series/theme sections), `lib/core/context_provider.dart`
  (`restoreFromPersistence` — a third parallel 17-arm `copyWith`), `lib/core/context_state.dart`

**Shallow-module evidence**
Adding one field to `ContextBarState` requires synchronized edits in four places:
the state class, `saveContextBar`, `loadContextBar`, and `restoreFromPersistence` —
each keyed by a string that must match, each with its own default. A miss is silent
(the field just stops persisting); nothing tests the round trip. The intel confirms:
`persistence.dart` ↔ `context_state.dart` co-change at jaccard 0.60, and
`persistence.dart` has blast radius 102 because it is one god-file holding the codecs
of five unrelated state owners (context, flags, series, theme, house system) behind a
`Map<String, dynamic>` interface whose keys are an undocumented contract with each
caller.

**Deletion test**: deleting `loadContextBar` would force each field's parse+default
logic to reappear in `restoreFromPersistence` — the two are one function split across
two files, i.e. the module boundary is in the wrong place.

**Proposed deeper module**
A field-schema codec owned next to the state it persists:

- Interface: per state object, one declarative list of entries, e.g.
  `PrefField<ContextBarState, T>('ctx_origin', (s) => s.origin, (s, v) => s.copyWith(origin: v), EnumCodec(Origin.values, Origin.geocentric))`.
  `save(state)` and `restore(state) → state` both fold over the same list.
- `PersistenceService` shrinks to the `SharedPreferences` seam (`sharedPrefsProvider`)
  plus generic codec helpers; each state owner (context, flags, series settings)
  carries its own field list, collocated with the state class so the 0.60 co-change
  becomes same-file change.
- What it hides: key naming, enum-by-name parsing with defaults, the
  "jdUt/dateTime are never persisted" rule (kept — **JD is canonical** and the Moment
  restarts at "now"; the schema makes that exclusion visible as an absence in one
  list instead of an absence in three).

**Expected payoff**
- *Locality*: a Context field addition is one state-file edit; the silent-miss
  failure mode disappears.
- *Tests*: one generic round-trip test (`for each field: save → load → equal`) covers
  every current and future field automatically — impossible to write against today's
  shape without enumerating fields a fourth time.

---

## Candidate 5 — An Ephemeris Source bootstrap module: replace the `swe_service` triplet's name-parity contract

**Files**
- `lib/core/swe_service.dart`, `lib/core/swe_service_io.dart`,
  `lib/core/swe_service_stub.dart`

**Shallow-module evidence**
The native/web split is held together by the weakest interface in the app: three
top-level function names (`initNativeEphePath`, `initWasm`, `loadBundledEpheFiles`)
that must exist with matching signatures in two files, each throwing
`UnsupportedError` for the other platform's entries, with nothing enforcing parity
(intel: co-change 0.63/0.57, "nothing enforces stub parity"). `_listEpheAssets` is
duplicated verbatim in both. The results flow out through module-level mutable
globals (`_ephePath`, `_webEpheFilenames`) read via free getters (`hasEpheFiles`,
`bundledEphePath`) — a hidden interface fact: `initSweEphePath()` must have completed
before any consumer runs, and the dependency is invisible to the provider graph.
`initNativeEphePath` itself (cognitive 34, nesting 5) interleaves three independent
strategies — release-bundle probe, dev-mode probe (CWD assets, package_config walk),
and versioned asset extraction — in one 80-line function testable only end-to-end.

**Proposed deeper module**
An **Ephemeris Source bootstrap** module (it belongs conceptually in `lib/core/ephe/`
with the scanner/catalog — it locates/stages the Source files):

- Interface: one value type `EpheBootstrap { String? path; List<String> stagedFiles; }`
  produced by a single `Future<EpheBootstrap> bootstrapEpheSource()`; result installed
  into the provider graph (override in `main()`'s `ProviderScope`, the
  `sharedPrefsProvider` pattern) instead of module globals.
- Implementation: the conditional import remains (it is legitimately about
  `dart:io` availability for *staging*, not engine dispatch), but shrinks to one
  platform adapter each side. Native's strategy list becomes ordered data —
  `List<EpheProbe>` of (description, candidate-dir producer) folded over
  `_isValidEpheDir` — with the versioned extractor as the last strategy.
- What it hides: platform probing order, extraction versioning, MEMFS staging,
  the asset-manifest fallback list (currently duplicated).

**ADR-0002 friction note (not a request to reopen)**: the ADR states "No
conditional-import split needed for web vs native — swisseph_rs handles platform
dispatch internally," yet this split survives. It is not the *engine* split the ADR
meant — it stages Source files — but the ADR's wording invites someone to delete the
triplet wholesale. This candidate renames/reshapes it so the remaining split is
self-evidently about Source staging.

**Expected payoff**
- *Locality*: parity becomes a compile-time fact of one small adapter surface;
  the duplicated asset lister collapses.
- *Tests*: probes become unit-testable with temp dirs (today: cognitive-34 function
  with zero direct tests); the bootstrap-before-use ordering becomes a provider
  dependency instead of a convention.

---

## Candidate 6 — One active-tab module: two providers and a widget-layer cycle

**Files**
- `lib/layout/app_shell.dart` (`selectedTabProvider`, `StateProvider<AppTab>`,
  persisted), `lib/core/active_tab.dart` (`activeTabIdProvider`,
  `StateProvider<String>`), `lib/widgets/context_bar/file_in_use_indicator.dart`

**Shallow-module evidence**
The selected tab is two providers kept in sync by a hand-written mirror
(`app_shell.dart:49` writes `activeTabIdProvider` whenever `selectedTabProvider`
changes) — a second source of truth that is correct only while that one line
survives. Because the primary lives *inside the shell widget file*,
`file_in_use_indicator.dart` must import `app_shell.dart` to switch tabs, creating
the second import cycle the intel found
(`file_in_use_indicator → app_shell → context_bar → file_in_use_indicator`).

**Proposed deeper module**
One `activeTabProvider` (`StateProvider<AppTab>`, persisted) in a non-widget file —
`lib/core/active_tab.dart` is already the right home if `AppTab` is acceptable there,
else `lib/layout/active_tab.dart`; the String-id view becomes a derived
`Provider<String>` for the series-settings keying. The shell and the indicator both
consume it; the mirror line and the cycle disappear.

**Expected payoff**: small but pure win — deletes a sync invariant that can silently
break (a tab switched via the indicator vs. the rail must hit both providers), and
removes the last widget-layer SCC.

---

## Candidate 7 — Chart file browser: extract the directory-listing model from the depth-7 build

**Files**
- `lib/widgets/chart_file_dialog.dart` (343 lines; build nests Dialog →
  ConstrainedBox → Padding → Column → Expanded → Container → 4-way ternary →
  ListView.builder → GestureDetector → ListTile)

**Shallow-module evidence**
The filesystem model — list a directory, drop hidden entries, filter by the active
**Chart** format extensions, sort dirs-then-files case-insensitively, classify
entries for display — lives inline in widget state (`_loadDir`,
`_activeExtensions`) and is only testable by pumping a dialog against a real
filesystem. The nesting-7 build is a symptom: the 4-way loading/error/empty/list
ternary chain is state that belongs in the model.

**Proposed deeper module**
A pure `ChartDirListing` value (`entries: List<ChartDirEntry{path, name, isDir,
formatDescription}>`, `error`) built by a function of
`(List<FileSystemEntity>, Set<String> activeExtensions)`; the dialog keeps only
navigation state and rendering, and the ternary chain becomes a `switch` over a
sealed listing state. What it hides: hidden-file policy, sort order, extension
matching against `ChartIO`.

**Expected payoff**: modest — locality for the listing rules and a real unit-test
surface (sorting, filtering, hidden files) instead of none. Ranked last: the
widget is self-contained and the co-change intel (106 partners / 3 commits) is an
artifact of landing in large commits, not real coupling.

---

## Ranking summary

| # | Candidate | Leverage | Cost | Kills which intel signal |
|---|-----------|----------|------|--------------------------|
| 1 | Quantity schema per tab (cards+export+series from one definition) | Very high | Medium-high (14 tabs, mechanical after first two) | 50–78% sibling-tab hidden coupling |
| 2 | Series wiring into kernel + `SeriesView` owns Moment label | High | Low | Same, series slice |
| 3 | Body Selection module in core + shared `BodyPicker` | High | Medium | 17-file import cycle; picker duplication |
| 4 | Context persistence codec | Medium-high | Low-medium | persistence↔context_state 0.60 co-change; blast radius 102 |
| 5 | Ephemeris Source bootstrap | Medium | Low-medium | swe_service triplet parity; cognitive-34 hotspot |
| 6 | One active-tab module | Medium (cheap) | Very low | widget-layer cycle |
| 7 | Chart dir-listing model | Low-medium | Low | nesting-7 build |

Sequencing note: 1 and 2 overlap (2's `rows` fold is 1's projection); doing 2 first
is a cheap dry run, but the schema in 1 is the piece that actually collapses the
lockstep. 3, 4, 5, 6 are independent of each other and of 1–2.
