---
status: accepted
---

# Results are a reactive projection of the Context (no explicit Calculate trigger)

**Results are a pure function of the Context (Moment, Location, frame) and Flags,
recomputed automatically whenever either changes.** There is no Calculate button,
no activation gate, and no "stale / out of sync" state — by construction, the
displayed values always reflect the current Context. The Context defaults to a
sensible Moment ("now") and the last-used Location so every tab shows live Results
from the first frame.

This supersedes the original design (recorded in CLAUDE.md as "Explicit Calculate
button — calculations run on demand, not on every state change"). That decision was
never fully realized: the code already recomputed reactively via `ref.watch`, and
the button survived only as a one-time activation gate plus a text-field flush. The
half-implemented split was a source of confusion, and the reactive behavior is the
one users prefer.

## Considered options

- **Explicit trigger** (rejected): would require a visible staleness indicator to
  show that selected options no longer match displayed values — accidental
  complexity the reactive model removes entirely.
- **Hybrid** (rejected): cheap tabs reactive, expensive search tabs explicit-only.
  Reintroduces exactly the two-model split we are removing.

## Consequences

- The calculation kernel's outcome type is `Ok | SweError` — there is no `NotRun`
  state.
- Each recompute must remain **synchronous** so the **Applied Globals** (process-wide
  Swiss Ephemeris C state) cannot drift across await points.
- Recompute is naturally debounced by the input-commit boundary: Context fields
  commit on blur/enter/picker-select, not per-keystroke. If a specific expensive tab
  still janks, it debounces locally — this never reintroduces a global trigger.
