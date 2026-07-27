# SWE Dashboard — Project Guidelines

## What This Is

Flutter cross-platform GUI for the Swiss Ephemeris via [swisseph_rs](https://pub.dev/packages/swisseph_rs) (stateless Rust engine, per-instance config). Pure astronomical values, no interpretation. Riverpod for state management (StateNotifier, no codegen).

## Architecture: Zoom & Responsive Scaling

This app supports browser-style zoom via `MediaQuery.textScalerOf`. All UI must remain functional across zoom levels. These rules are non-negotiable:

### Cards and Grids
- Render body chips through `BodyChip`/`BodyChoiceChip` (`lib/widgets/body_chips.dart`),
  bound to a `BodySelection` — do not hand-roll a `FilterChip` + toggle in a tab
- Render result cards through `ResultCardGrid` (`lib/widgets/result_card_grid.dart`) — do not
  re-paste a `LayoutBuilder`/`Wrap`/`cardWidth` block into a tab (swe-dashboard/92)
- Use `Wrap` + `SingleChildScrollView`, never `GridView` with fixed aspect ratios
- Compute card width from `LayoutBuilder` constraints; let cards size to intrinsic content height
- Fixed aspect ratios break at fractional scale factors due to sub-pixel rounding

### Labels and Text
- Use plain `Text` widgets with intrinsic width — never `SizedBox(width: N)` for labels
- If a fixed width is truly unavoidable, floor it: `(N * scale).floorToDouble()`

### Scale Factor Access
- Use `MediaQuery.textScalerOf(context).scale(1.0)` for the current multiplier
- Tab bar heights must be computed in the parent's `build()` via `PreferredSize` wrapper (not in the `preferredSize` getter, which has no `BuildContext`)

### Overflow Prevention
- Wrap dense horizontal bars (e.g. context bar, chip selector rows) in `SingleChildScrollView(scrollDirection: Axis.horizontal)` with a min width for extreme zoom
- Prefer `Flexible`/`Expanded` over fixed-width `SizedBox` inside `Row` widgets
- `ClipRect` does **not** suppress sub-pixel overflow errors — fix the sizing instead

## Key Architecture Decisions

1. **Reactive projection (ADR-0001)** — Results are a pure function of the Context and Flags, recomputed on change. No explicit Calculate button, no staleness.
2. **Stateless engine (ADR-0002)** — `RustEph` wraps `rs.Ephemeris` with adapter-local config; no process-wide C globals. Config changes rebuild the engine instance.
3. **Locked Flags** (formerly "auto-managed flags") — sidereal, topocentric, helio, bary, ephe-source flags are a pure function of the Context; the context bar owns them (shown as disabled chips with lock icon)
4. **Flag bar uses `ref.listen`** (not `ref.watch` in notifier) for auto-linking to avoid infinite loops
5. **swisseph_rs from pub.dev** — not a local path dependency

## Architecture refactor (in progress)

The app is being refactored into deep, testable modules. Vocabulary: `CONTEXT.md`.
Decisions: `docs/adr/`. Plan: `docs/prd/deep-module-refactor.md` (yojana `swe-dashboard/4`).
Architecture map: `docs/architecture-map.md` (provider graph, file roles, call patterns).
Use `CONTEXT.md` terms in code, tests, and commits (Context, Moment, Ephemeris vs
Ephemeris Source, Calculation/Result, Locked/Toggle Flag, Chart).

### Planning protocol

When planning a refactor task (vidhi-plan), do NOT launch a broad exploration agent.
Instead:

1. Read `docs/architecture-map.md` (~2k tokens) for the stable layout.
2. Do targeted `sutra_read` calls on the specific symbols the task names.
3. Only delegate exploration to a subagent when the answer set is genuinely unknown
   (e.g. "find all callers of X across the codebase").

Update the architecture map when a task changes the module structure or provider graph.

### Governed invariants

These are enforced or tracked. Graph constraints live in `.sutra/rules.toml`
(guarded by `sutra-guard` on Edit/Write); routing of record is
`docs/enforcement-ledger.md`. The behavioral ones below are not graph-expressible
— honor them:

- **Synchronous recompute** — each recompute is synchronous, so a tab's result
  is exactly the product of one compute pass (and each series step of one step
  pass). The Call Trace clause that once co-motivated this is gone with the trace
  subsystem (swe-dashboard/47); the invariant now rests on ADR-0001 (reactive
  projection: result is a pure function of the Context, no staleness) alone.
  (The ADR-0001 "Applied Globals never set across an await" hazard is separately
  gone with stateless `swisseph_rs`; see ADR-0002.)
- **JD is canonical** — the Moment is a Julian Day; civil date/time/offset is a
  derived, advisory view. Editing a civil field computes a new Moment.
- **Moment comes from the series step, never the Context** — in series mode a
  compute is repeated over the step Moments, whose start is the Context Moment
  (JD canonical) but whose subsequent values are *not*. This is structural, not
  linted: the pure computes take `(Ephemeris, Moment)` with no `ref`, so they
  cannot read the Context; and `runTabCalcSeries` (run_tab_calc.dart) is the sole
  place that reads the Context JD — it owns the step loop and feeds each
  `Moment` in, so there is no per-tab loop for a `ctx.jdUt` to leak into. A
  `forbidden_pattern` banning `jdUt`/`jdEt` under `lib/tabs/**` was considered and
  rejected: those identifiers are legitimate vocabulary there (compute params fed
  from `moment.ut`, and the Dates tab's own `jdUt`/`jdEt` result fields), so the
  ban would be unsound. See enforcement ledger row 17.
- **Locked Flags are a pure function of the Context** — one source of truth, not a
  hand-maintained set.
- **Core defines the body selections; tabs consume them** — every selection is a
  `BodySelection` enum value in `lib/core/body_selection.dart`, and the
  engine-config aggregation folds over `BodySelection.values`. A tab must not
  declare a body-selection provider of its own: that is what made "new tab
  forgets to register" a silent broken engine config, and it is why
  `core-must-not-import-tabs` is blocking (swe-dashboard/85). Body lists and
  chip labels come from `BodyCatalog`, not tab-local consts.
- **swisseph_rs behind the Ephemeris seam** — reach the engine through the `Ephemeris`
  interface; `package:swisseph_rs` is confined to `lib/core/**` (forbidden in
  `lib/tabs/` and `lib/widgets/` — blocking; enforced by `.sutra/rules.toml`,
  constants re-exported via `lib/core/swe_constants.dart`).

## Layout Tests

**There are no golden image tests.** Don't add any. Snapshot baselines were
tried twice and removed twice: they spent three separate defects being green
against images nobody compared (swe-dashboard/63), and once genuinely working
they failed on ~1% cosmetic drift after every unrelated UI edit while never
catching a bug. Verification of *appearance* is Josh's, by eye. Verification of
*layout correctness* is `test/layout_invariants_test.dart`, which fails on facts
rather than pixels.

Harness mechanics (the sweep's shape, `_knownOverflows`, `pumpAppWidget`, the
`FlutterError.onError` ordering rule) live in `test/CLAUDE.md`, which loads when
you work under `test/`.

## Agent skills

### Issue tracker

Yojana (local MCP task graph). See `docs/agents/issue-tracker.md`.

### Triage labels

Default vidhi vocabulary (no overrides). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout. See `docs/agents/domain.md`.

## SwissEph state & frames

With `swisseph_rs`, engine config is adapter-local (per-instance `EphemerisConfig`),
not process-wide C globals. The drift-across-await hazard documented in
~/soft/manas/docs/lessons/swisseph-state-discipline.md no longer applies to this
app (see ADR-0002). The lessons doc remains relevant for any project still on the
C-FFI `swisseph` package. Longitude frame confusion (tropical/sidereal,
ecliptic/equatorial) still applies — the Ephemeris seam's context setters gate this.
