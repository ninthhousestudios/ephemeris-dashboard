# PRD — Time-Series Mode

Status: planned
Arc: yojana `swe-dashboard/~N` (see arc for phase state)
Vocabulary: `CONTEXT.md`. Related: ADR-0001 (reactive projection), ADR-0002 (stateless engine).

## Problem

The dashboard is organised as *one Moment × many quantities* per tab. `swetest` is
organised as *one quantity × many Moments* (`-n` steps of `-s` size, columns chosen
with `-fSEQ`). The Table tab is the only surface that steps time, and it exposes the
smallest quantity set in the app: longitude, latitude, distance, longitude speed.

So everything the app can compute — phase angle, elongation, magnitude, disc
diameter, nodes, apsides, orbital elements, ΔT, sidereal time, equation of time,
ayanamsha, house cusps — is computable at exactly one Moment and cannot be put on a
time axis. That is the substance of the swetest capability gap.

A second, smaller problem: the Table tab's body picker (13 hardcoded bodies) diverges
from the Planets tab's (presets, extras, Uranians), so "which bodies can I chart over
time?" has a different answer from "which bodies can I compute?" and the user has to
know that.

## Non-goals

- Zodiac-sign display format (`swetest -fZ`). The app exposes calculations, not
  astrological interpretation. Explicitly rejected.
- Async/progressive computation. Recompute stays synchronous (ADR-0001 reactive
  projection). Large series are bounded by a row cap, not by moving off the main
  isolate.
- Time series for search-function tabs. See "Eligibility" below.

## Approach

Two designs were considered:

**A. Grow the Table tab** — reimplement every tab's outputs as Table columns.
**B. Per-tab time-series mode** — step the Moment and repeat that tab's own calculation.

B, decisively. Two facts make it cheap:

1. **The universal projection already exists.** All 17 tabs have a `*ToExportRows`
   function producing `ExportRow { String header; List<(String,String)> fields }` —
   a row identifier plus ordered named quantities. That is exactly swetest's
   `-fSEQ -hor` output model, already proven across every tab, built for CSV export.
2. **The computes are already Moment-parameterized.** Every pointwise tab has a pure
   `computeX(Ephemeris eph, {required double jdUt, ...})`; the provider supplies
   `jdUt: ctx.jdUt` at a single call site. Nothing about the compute layer needs to
   change.

Under A, every column added to a tab would have to be hand-copied into the Table tab
and then maintained in two places — the duplication the project constraints forbid.
Under B, adding a field to any tab's `ExportRow`s makes it appear in that tab's time
series automatically.

## Design

### Eligibility

- **Pointwise (eligible, 10 tabs):** Planets, Other Bodies, Stars, Phenomena,
  Nodes/Apsides, Planetocentric, Differential, Houses, Ayanamsa, Dates. These are
  `f(Moment) → values`, matching swetest's `-n`/`-s` stepping.
- **Search functions (not eligible):** Eclipses, Crossings, Rise/Set, Heliacal,
  Occultations. These already scan time and return *events*; their count is an event
  count, not a step count. swetest treats them the same way.
- **Stateless (N/A):** Math, Coordinates, Config — deliberately not Context-bound.

### Core abstraction

```dart
class Moment {
  final double ut;   // canonical
  final double et;   // derived via ΔT
}

CalcOutcome<T> runTabCalc<T>(Ref ref, {required T Function(Ephemeris, Moment) compute});

List<(Moment, CalcOutcome<T>)> runTabCalcSeries<T>(
  Ref ref, {
  required T Function(Ephemeris, Moment) compute,
  required SeriesSpec spec,
});
```

`Moment` carries both scales because `getOrbitalElements` and `calcPctr` take ET
while most calls take UT, and the Dates tab reports both.

**`AppliedGlobals` are Context-derived but not Moment-derived** — sidereal mode,
topocentric position, ephemeris source. So `runner.apply(globals)` stays *outside*
the step loop: one engine configuration, N calls. This is why the series is cheap.

### Result shape

The series yields `List<(Moment, CalcOutcome<T>)>` — the tab's **existing** typed
result per step. The grid then runs the tab's **existing** `*ToExportRows` on each
step. No new per-tab mapping code.

Column identity is the pair `(ExportRow.header, fieldLabel)` — e.g. `("Sun",
"Longitude")`. The column set is the union across steps, ordered by first appearance
in step 0. This handles shape drift (an errored step, a body that drops out) without
special-casing.

Rejected: having the series produce `ExportRow`s directly. It discards the typed
result and forces any future non-grid consumer to re-derive it.

### Error granularity

Two levels, already separated:

- **Step-level** — `CalcOutcome` per step; a failed step renders as an error row.
- **Body-level** — stays each tab's own business, unchanged. swetest's behaviour is
  "print the error for that body, continue"; the Table tab already does this per
  cell. Whether every pointwise tab does needs a per-tab check during rollout.

### Step semantics

Units: seconds, minutes, hours, days, weeks, months, years — a superset of swetest's
`s/m/d/mo/y`. Negative step value means backward (swetest `-bwd`).

**Months and years are calendar-aware** (swe-dashboard/49): `StepUnit.advanceFrom`
converts the Julian Day to a civil date, adds whole months, clamps the day of month
and converts back, preserving the time of day. The old `StepUnit.months = 30.4375`
days approximation made a monthly ephemeris drift off the calendar date (1 Jan,
31 Jan, 2 Mar, …) where swetest's `-s3mo` steps calendar months. The conversion is
pure Dart integer JDN math in `core/calculation/calendar_step.dart` rather than a
`revjul`/`julday` round-trip, so the series core stays engine-free and unit-testable.

### UI

- **Shared `SeriesBar`**: start (= Context Moment, read-only, stated), step value,
  step unit, row count. `StepUnit` lifts out of `table_view_provider.dart` into core.
- **Mode toggle is per-tab**, persisted per-tab. A global toggle would be a no-op or
  actively confusing on the 7 ineligible tabs.
- **Quantity picker**: generic, built from step-0's field labels, default all-on.
  This is the Table tab's `Columns` chip row generalized, and it is what keeps
  Phenomena × 8 bodies × 5 quantities = 40 columns tolerable.
- **Grid**: two-axis `SingleChildScrollView`, honouring the zoom rules in
  `CLAUDE.md` — intrinsic sizing, no fixed aspect ratios, no fixed-width label
  boxes. A sticky Moment column is desirable but deferred.

### Performance

Cost is `steps × per-step cost`, and per-step cost varies by an order of magnitude
(Planets: one call per body; Nodes/Apsides: `nod_aps` + `get_orbital_elements` +
`orbit_max_min_true_dist` per body). Recompute is synchronous, so a large series
would freeze the UI.

Bound it: soft row cap ~500 with a warning, hard cap ~2000. Removing the Call Trace
(below) deletes a per-call `Map<String,Object?>` allocation, the largest constant
factor available.

### Export

`ExportService` already consumes `List<ExportRow>`, so both swetest layouts are pure
functions over data we already have:

- **vertical** — one row per (step, body); swetest default
- **horizontal** — one row per step, bodies flattened across; swetest `-hor`

The grid renders horizontal; export offers both. Leading fields per row: JD and
formatted date, as the Table tab already does.

### Golden tests

Series mode defaults **off**, so the 54 existing goldens are untouched. Add a minimal
series golden set — one tab × 2 themes × 1 size — rather than 3 × 2 per tab.

## Call Trace removal (prerequisite)

The Call Trace subsystem is **fully dead**. Every tab exposes a `xTraceProvider`,
`app_shell` points `activeTraceSourceProvider` at it, `activeTabTraceProvider` reads
it — and nothing reads `activeTabTraceProvider`. The only consumer of
`sliceByCategory` / `sliceByTraceId` / `sliceByTab` is `test/trace_model_test.dart`,
a test for code with no caller. It fed a code-view feature that was removed; the
trace was kept speculatively.

Cost of keeping it:

- ~126 trace references inside the 1720-line `tracing_rust_eph.dart` — the wrapping
  is the bulk of that file
- a `Map<String,Object?>` allocated and discarded on **every** ephemeris call, which
  is exactly the tax a feature that calls the engine 100× more often should not pay
- the only genuine design compromise in this work (N× trace entries per series pass,
  forcing a "capture step 0 only" rule and an ADR to justify it)

Remove it. Git retains it; the `Ephemeris` seam is the obvious reinstatement point.
`runTabCalc` returns `CalcOutcome<T>` instead of `({outcome, trace})`;
`TracingRustEph` → `RustEph`; delete `trace_model.dart`, `swe_symbol_catalog.dart`,
`active_tab_trace.dart`, `trace_model_test.dart`, `TabDescriptor.traceProvider`, and
the 17 `xTraceProvider`s.

This lands **first**, as its own phase. It touches the same files the series work
touches, but it is delete-only and trivially reviewable; mixing it into a signature
change would hide the interesting part of the diff inside the mechanical part.

## Governed invariant

Inside a series, the Moment must come from the series step, never from the Context.
The pure computes have no `ref` and no Context access, so they cannot violate this
structurally. The residual risk is a *provider* passing `ctx.jdUt` instead of the
step Moment inside the loop.

Enforce by making `jdUt`/`jdEt` core-only vocabulary: `Moment` exposes `.ut`/`.et`,
and tab-layer compute parameters are renamed to match. Then any occurrence of the
identifier `jdUt` or `jdEt` under `lib/tabs/**` is by definition a Context read:

```toml
[[constraint]]
kind = "forbidden_pattern"
name = "moment-only-from-series-step"
query = '((identifier) @match (#match? @match "^jd(Ut|Et)$"))'
scope = "lib/tabs/**"
severity = "blocking"
provenance = "docs/prd/time-series-mode.md §Governed invariant"
```

Waivers: Dates and Differential have their own JD-entry field independent of the
Context (`overrideJd`). Query needs validation against tree-sitter-dart at seed time
per the note in `vidhi/language-rules/dart.toml`.

## What falls out for free

swetest's pseudo-planets `q` (ΔT), `y` (equation of time), `x` (sidereal time) and
`b` (ayanamsha) are exactly the Dates and Ayanamsa tabs. **Dates-in-series-mode and
Ayanamsa-in-series-mode close that gap with no new code.** Adding obliquity and
nutation (swe-dashboard/46) closes `o` and `n` too. The entire pseudo-body column
family comes from the generic mechanism.

## Quantity gaps (interleaved with rollout)

These need new computation before the series can surface them. Cheap ones land
alongside the tab they belong to, so each rolled-out tab demonstrates real parity
rather than only a working grid.

| swetest | Quantity | Home |
|---|---|---|
| `G g j` | house position / house number (`swe_house_pos` — never called anywhere) | Houses |
| `I i H h K k` | azimuth, altitude, apparent altitude per body | Planets (new quantity group) |
| `m z` | meridian distance, zenith distance | Planets (same group) |
| `W w q r` | distance in light years / km / relative / lunar parallax-sec | Planets, Other Bodies, Stars |
| `U u` | unit vectors ecliptical / equatorial | Planets, Other Bodies |
| `SS ss` | speed for all columns, not just longitude | all pointwise tabs |

## Table tab retirement

The Table tab becomes Planets-in-series-mode with a worse body picker. Its combined
bodies + extras + stars picker is the anomaly, not the feature; the migration lands
across Planets + Other Bodies + Stars.

Delete only after those three ship. Migrate the Table tab's persisted step settings
into the shared series settings. Net effect is a deletion of ~800 lines and the
removal of an existing capability inconsistency.

## Phases

| Phase | Content |
|---|---|
| **P0 — trace removal** | Delete the Call Trace subsystem. 17 providers + seam + tests. Delete-only. |
| **P1 — series core** | `Moment`, `runTabCalcSeries`, `SeriesSpec`, `SeriesBar`, grid widget, quantity picker, calendar-aware month/year stepping, row caps, dual-layout export. Pilot on Planets, verified against `swetest -p -n -s`. |
| **P2 — rollout** | Remaining 9 pointwise tabs, interleaved with the cheap quantity gaps above. |
| **P3 — retirement** | Delete the Table tab; migrate persisted settings. |
| **P4 — governance** | Seed the `moment-only-from-series-step` constraint; update `docs/architecture-map.md` and `docs/enforcement-ledger.md`. |

## Acceptance

- Every pointwise tab can produce an N-step ephemeris from the Context Moment.
- Output for Planets, Phenomena and Nodes/Apsides matches `swetest` for spot-checked
  date ranges and bodies.
- Monthly and yearly steps land on calendar dates, not 30.4375-day approximations.
- No `CallTrace` references remain in the codebase.
- The Table tab is gone and nothing regressed relative to it.
- `moment-only-from-series-step` is seeded and passing.
