# SWE Dashboard — Project Guidelines

## What This Is

Flutter cross-platform GUI for the Swiss Ephemeris via [swisseph_rs](https://pub.dev/packages/swisseph_rs) (stateless Rust engine, per-instance config). Pure astronomical values, no interpretation. Riverpod for state management (StateNotifier, no codegen).

## Project Structure

```
lib/
  main.dart, app.dart              # Entry point, MaterialApp
  core/                            # Shared state & services
    swe_service.dart               #   sweProvider (SweUtils), initSweEphePath
    context_state.dart             #   Immutable ContextBarState
    context_provider.dart          #   ContextBarNotifier (JD/DateTime/location)
    calc_context.dart              #   EffectiveContext (merges context + flags)
    active_tab.dart                #   activeTabIdProvider (selected tab tracking)
    flag_definitions.dart          #   FlagDef, FlagGroup, auto-managed flags
    flag_state.dart, flag_provider #   FlagBarState/Notifier
    display_format.dart            #   DMS/Decimal/Raw formatters
    jd_utils.dart                  #   JD <-> DateTime conversion
  layout/                          # Shell, tabs, responsive breakpoints
  tabs/                            # Per-tab UI + providers (planets, houses, ayanamsa)
  widgets/                         # Reusable widgets (context_bar, flag_bar, result_card)
  chart_formats/                   # File format parsers (.chtk, .jhd, .aaf, etc.)
  theme/                           # Dark/light/cosmic/forest themes
test/goldens/                      # Golden image tests (54 PNGs)
```

## Architecture: Zoom & Responsive Scaling

This app supports browser-style zoom via `MediaQuery.textScalerOf`. All UI must remain functional across zoom levels. These rules are non-negotiable:

### Cards and Grids
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
  is exactly the product of one compute pass.
  (Supersedes the ADR-0001 "Applied Globals never set across an await" hazard —
  that hazard is gone with stateless `swisseph_rs`; see ADR-0002.)
- **JD is canonical** — the Moment is a Julian Day; civil date/time/offset is a
  derived, advisory view. Editing a civil field computes a new Moment.
- **Locked Flags are a pure function of the Context** — one source of truth, not a
  hand-maintained set.
- **swisseph_rs behind the Ephemeris seam** — reach the engine through the `Ephemeris`
  interface; `package:swisseph_rs` is confined to `lib/core/**` (forbidden in
  `lib/tabs/` and `lib/widgets/` — blocking; enforced by `.sutra/rules.toml`,
  constants re-exported via `lib/core/swe_constants.dart`).

## Running

```bash
flutter run -d linux    # or macos, windows, chrome
flutter test test/goldens/ --update-goldens   # regenerate golden images
flutter test test/goldens/                    # compare against baselines
```

## Golden Tests

54 golden PNGs across 3 sizes (400x800 mobile, 800x1024 tablet, 1400x900 desktop) x 2 themes (light, dark). ContextBar and AppShell use `allowOverflow: true` because the context bar is intentionally wider than 400px mobile (it horizontal-scrolls).

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
