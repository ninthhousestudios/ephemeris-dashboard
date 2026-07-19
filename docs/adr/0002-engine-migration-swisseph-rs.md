---
status: accepted
---

# Engine migration: swisseph.dart → swisseph_rs (stateless Rust engine)

**The Swiss Ephemeris engine is now `swisseph_rs` — a stateless Rust library
accessed via Dart FFI.** The old `swisseph` (C FFI wrapper with process-wide
mutable globals) is removed. The `Ephemeris` interface seam is unchanged; only
the production adapter changed (`TracingSwissEph` → `TracingRustEph`).

## Context

The original engine (`package:swisseph` 0.2.0) exposed process-wide C globals:
ephemeris path, sidereal mode, topocentric position, JPL filename. These globals
drifted across `await` points and Android resume, requiring the "Synchronous
Applied Globals" invariant (ADR-0001 §Consequences) and defensive re-assertion
at every calculation boundary.

`swisseph_rs` wraps the same Swiss Ephemeris algorithms in a Rust library that
takes an `EphemerisConfig` at construction time. Each `rs.Ephemeris` instance
owns its state — there is no process-wide mutable surface. Config changes
produce a new instance (`_rebuildEngine()`); the old one is `.close()`d.

## Decision

Migrate to `swisseph_rs ^0.2.4` behind the existing `Ephemeris` seam:

1. **Adapter swap** — `TracingRustEph implements Ephemeris`. Holds a private
   `rs.Ephemeris _engine` rebuilt on any context-setter call. Config is
   assembled via `_buildConfig()` from adapter-local fields.
2. **Coexistence then cutover** — during development both packages coexisted;
   the cutover removed `package:swisseph` entirely. The `Ephemeris` interface
   and all tab code remained untouched.
3. **Invariant relaxation** — the "Applied Globals never set across an await"
   hazard no longer applies; what remains is the weaker (still true) statement
   that recompute stays synchronous for trace-slice coherence.

## Consequences

- The `Applied Globals` concept narrows from "process-wide C state" to
  "adapter-local config snapshot passed to the engine on construction."
  `AppliedGlobals` the value object still exists (runner uses it to diff and
  decide whether to rebuild), but the hazard it was named for is gone.
- No conditional-import split needed for web vs native — `swisseph_rs` handles
  platform dispatch internally.
- The `confined_external swisseph_rs allowed_in=lib/core/**` sutra constraint
  replaces the old `swisseph` confinement (enforcement-ledger row #1).
- ADR-0001's synchronous-recompute consequence is superseded by this ADR — the
  remaining synchronous guarantee is for trace-slice coherence, not C-state
  drift prevention.
