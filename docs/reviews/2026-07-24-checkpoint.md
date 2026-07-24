# Checkpoint Review — swe_dashboard @ b087532 (2026-07-24)

**Verdict (both passes, independently): continue with adjustments.**

This is the synthesis. The two source reviews are:

- [`2026-07-24-checkpoint-architecture.md`](2026-07-24-checkpoint-architecture.md) — vidhi-deepen pass, 7 ranked deepening candidates
- [`2026-07-24-checkpoint-review.md`](2026-07-24-checkpoint-review.md) — code review pass, 11 YAML findings + 5 slop items

Scope: all of HEAD (50 commits, no prior tags), after the series/calendar/time-scale/
occultation/heliacal/rise-set arc. Verification green: 279/279 tests, analyze clean,
format clean. All four governed invariants were checked against source by the review
pass and hold.

## Convergent root causes

**1. Cross-cutting glue is hand-replicated per tab — and the copies are already
diverging.** The architecture pass identified the structure: the deep-module refactor
fixed the *calculation* path, but the *Result presentation* path (card fields, export
rows, series wiring, body pickers) was never named as a module, so every cross-cutting
feature is applied 10–14× by hand (candidates 1–3). The review pass found the bugs
this has already caused: a diverged private `_describeBodyError` that lost the
moon-file hint, the Dates tab rendering a different date than the context bar for the
same Moment, rise/set exports that stopped matching the screen, and the
series-provider select-tuple policy maintained in ten places. Highest-leverage
convergence in the review.

**2. Persistence round-trips are asymmetric and untested.** The review found the
concrete high-severity bug (sidereal `projection` and `userAyanT0IsUt` are saved and
loaded but never applied on restore; the chosen JPL file isn't persisted at all); the
architecture pass found the structure that guarantees recurrence (four
hand-synchronized lists per field across three files, jaccard 0.60 co-change, blast
radius 102, zero direct tests — candidate 4). Fix the bug now, adopt the codec to
make the class of bug impossible.

**3. The engine flag surface has no owner** (review pass only, but same "unnamed
module" disease). Four call families re-derive "which iflag bits do I forward" and
four got it wrong differently: heliacal never sets `OPTICAL_PARAMS` (its four optical
inputs are completely inert) and never forwards the Ephemeris Source bits; the
meridian-distance RA feed keeps sidereal/J2000/no-nut bits (≈ ayanamsha-sized error
under a sidereal Context, confidence medium pending the test extension); `& 0xF`
wrongly includes `SEFLG_HELCTR` at three sites.

**4. The `swe_service` triplet** — architecture candidate 5 (bootstrap module,
name-parity contract, cognitive-34 hotspot) and review slop item 3 (`_listEpheAssets`
duplicated verbatim) hit the same file pair from both angles.

## Fix order — waves (one commit per wave)

### Wave A — correctness (do before the next feature arc)

| # | Item | Source |
|---|---|---|
| A1 | Restore `projection` + `userAyanT0IsUt` in `restoreFromPersistence`; persist `jplFilename`; add the full round-trip test | review: persistence-restore, jpl-filename |
| A2 | Heliacal flags: set `HeliacalFlags.opticalParams`, forward ephe bits, watch flagBar; swetest `-opt` parity test | review: heliacal-optical, heliacal-ephe-source |
| A3 | `flag_masks.dart` in the kernel (`epheMask`, `frameOfDateFlag` stripping J2000/no-nut); fix the meridian RA feed in the three body tabs; **first** extend `planets_horizontal_invariance_test` with sidereal + J2000 rows to convert the medium-confidence finding into a fact | review: horizontal-meridian, epheflag-mask |

A1 and A2 are afternoon-sized. A3 needs the test extension before the change.

### Wave B — contract/UX consistency (small, independent)

- Eclipse type filter: hide/disable in Local scope (review: eclipse-type-filter)
- JD field: revert + snackbar on unparseable entry, mirroring b087532's date/time fix (review: jd-field-invalid-entry)
- Dates tab: thread `ctx.calendar` into `computeDates`/entry fields, or label the card "Gregorian" (review: dates-tab-calendar)
- Wrap `runner.apply` in the series variants of `runTabCalc` (review: series-apply-envelope)
- Single active-tab provider — removes the hand-mirrored duplicate and the widget-layer cycle (architecture candidate 6; cheap enough to live here rather than in the deepening wave)

### Wave C — slop batch (one commit)

Review slop list items 1–5: write-only `ContextBarState.dateTime` + `setDateTime` +
`removeUtcOffset`; planets' diverged `_describeBodyError`; duplicated
`_listEpheAssets`; rise/set export through `formatJdDateTime` (retire
`RiseSetDateTime`); `localNoon` `_nonZero` inconsistency.

### Wave D — architectural deepening (HITL: grill before implementing)

Ranked per the architecture pass; 1–2 are sequenced (2 is a cheap dry run of 1's
projection), 3–5 independent.

| # | Candidate | Kills |
|---|---|---|
| D1 | Quantity schema per tab (cards + export + series columns from one `QuantityRow` definition, plus a shared `ResultCardGrid`) | the 50–78% sibling-tab lockstep |
| D2 | Series wiring into kernel (`seriesSteps`) + `SeriesView` owns the Moment-label policy | 10× select-tuple policy, 11× `momentLabel` lambda; also review finding series-boilerplate |
| D3 | Body Selection module in core + shared `BodyPicker` | the 17-file import SCC; 6 picker copies |
| D4 | Context persistence field codec | the 4-place-per-field silent-miss pattern (structural follow-up to A1) |
| D5 | Ephemeris Source bootstrap module (reshape the `swe_service` triplet; note ADR-0002 wording friction, no reopen) | name-parity contract; cognitive-34 hotspot |
| D7 | Chart dir-listing model out of the depth-7 build | low priority; take opportunistically |

## Blocking vs follow-up

Nothing blocks in the release-gate sense (checkpoint verdict is *continue with
adjustments*), but **Wave A is "before the next feature arc"**: A1 and A2 are silent,
user-visible wrong-results bugs; A3 is a wrong-result bug in every sidereal Context.
Waves B–C are ordinary tickets. Wave D shapes the next refactor arc and should go
through grilling before any implementation.

## Process notes

- `sutra_dead` is unreliable for Dart (misses intra-file private references; all
  test files listed unreachable). The review pass confirmed the caveat and found its
  dead code by grep instead. Worth a sutra issue.
- The two passes overlapped almost nowhere except the series-boilerplate item —
  consistent with the two-pass design's premise.
