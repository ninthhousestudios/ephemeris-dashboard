# swisseph_rs

Idiomatic Dart transliteration of the swisseph-rs Rust API (pure-Rust Swiss
Ephemeris), bound via swisseph-ffi. Directory name `swisseph.rs.dart`; pub
package name `swisseph_rs`. Supersedes the earlier drop-in-replacement design
(see ADR-0002).

## Language

**Transliteration rule**:
The Dart public API mirrors `swisseph::*` symbol-for-symbol: same type names,
same method vocabulary (camelCased), same semantics. One API design, expressed
twice. A public Dart symbol that deviates from its counterpart without a
governing systematic divergence is a defect.
_Avoid_: "inspired by", "based on" (both imply license to drift)

**Counterpart**:
The Rust construct a public Dart symbol mirrors — every public Dart symbol has
exactly one, declared in a fixed-format dartdoc line
(`/// Counterpart: swisseph::Ephemeris::calc_ut`). The namespace is
`swisseph::` for engine-level symbols or `swisseph_ffi::` for FFI-boundary
symbols (e.g. `swisseph_ffi::swisseph_free`, `swisseph_ffi::SweErrorCode`).
Systematic divergences use `(systematic divergence: <name>)` instead of a
Rust path. A test walks the public API and fails on any symbol missing its
declaration or using an unrecognized namespace.

**Systematic divergence**:
A deviation class applied uniformly across the whole surface and documented
once, where Dart idiom demands a different mechanism: `Result<T, E>` → thrown
`SweException` subtypes; bitflags → extension-type flag sets; payload enums →
sealed classes; newtypes → extension types; snake_case → camelCase; Rust free
fns taking `&Ephemeris` → Dart methods only; additive `DateTime` ↔ `JdUt1`
helpers. Case-by-case divergence is not systematic.

**Engine version**:
The swisseph-rs crate version actually loaded at runtime, via the top-level
`engineVersion` getter (reads `swisseph_version`). The only runtime-queryable
version — the package itself is versioned by pubspec like any Dart package;
there is no `version()` method.

**Oracle**:
swisseph.dart driving vendored C Swiss Ephemeris 2.10.03 — the reference
implementation the differential harness compares against. "Oracle version" =
2.10.03, the version swisseph-rs is bit-compatible with.
_Avoid_: "compat baseline" (dead drop-in-era term), "the C version"

**Oracle mapping**:
The harness-owned declaration of how a public Dart method is verified:
*direct* (one swisseph.dart call, compare numbers), *composite* (a
set-then-call sequence on the oracle side — how every `*WithConfig` variant
verifies), or *engine-trusted* (no C call corresponds; correctness rests on
swisseph-rs's own C-parity suite plus pure-Dart unit tests — with the reason
declared). The map is total: an undeclared public method fails the harness
self-check, which walks the same public API as the counterpart test.

**Agreement class**:
The tolerance tier a compared value belongs to in the differential harness:
*bitwise* (pure math), *positional* (1e-9°), *boundary* (documented stateless
artifacts: deflection speed 1e-7°, Moshier osculating node speed 5e-6°/day,
SPEED3 at file boundaries), or *search* (iterative event-finding epsilons).
An unclassified comparison fails the harness by design.

**Handle**:
The opaque `SweEphemeris*` from `swisseph_new` or `swisseph_share` —
immutable, `Send + Sync`, an `Arc` clone at the FFI boundary. Every
`Ephemeris` owns its handle equally: `close()` drops one refcount (with a
`NativeFinalizer` backstop per instance), the last drop frees the engine.
Handles are never rebuilt; there is no configuration mutation of any kind and
no owner/share asymmetry.

**Share**:
`ephemeris.share()` → a token sendable to another isolate, materialized there
as a co-equal `Ephemeris` over the same engine (`swisseph_share` bumps the
refcount). Close order across instances is irrelevant by construction.
Native-only; throws `UnsupportedError` on web.

## Relationships

- Every public Dart symbol has exactly one **counterpart**; every deviation
  from it belongs to a named **systematic divergence**
- An **Ephemeris** holds exactly one **handle** from construction (or
  **share** materialization) to `close()` — configuration is immutable, so
  nothing can invalidate it, and refcounting makes any close order safe
- Every compared value in the differential harness belongs to exactly one
  **agreement class**
- Every public method carries an **oracle mapping** (or a documented reason
  it cannot have one)

## Example dialogue

> **Dev:** "Should `calcUt` also accept a plain `double` for convenience?"
> **Domain expert:** "No — its **counterpart** takes `JdUt1`, and loosening
> the type isn't a **systematic divergence**, it's drift. The additive
> `DateTime` helpers are the sanctioned convenience path."

## Flagged ambiguities

- "SwissEph" now means only the old package's class. The new API class is
  `Ephemeris`, mirroring its counterpart — never reuse the name `SwissEph`.
- "isolate safety" is trivial here: the handle is immutable and the Rust side
  is `Send + Sync`, so there is no per-isolate state to manage at all —
  unlike swisseph.dart's copy-the-.so hack.
- No environment variables: swisseph-rs never reads `SE_EPHE_PATH`, so
  neither does this package. `ephePath` is always explicit config.
- Alignment with swisseph.dart *names* is coincidence, not contract: many
  camelCased Rust names land near swisseph.dart's (`calcUt`, `riseTrans`),
  which eases migration, but the counterpart is always the Rust symbol.
- JPL ephemeris files on web are out of scope (PRD "Out of Scope"). MEMFS
  supports them mechanically but the file sizes (300 MB+) make web delivery
  impractical. Attempting to use JPL source on web throws the same
  `FileNotFoundException` as any missing ephemeris file.
