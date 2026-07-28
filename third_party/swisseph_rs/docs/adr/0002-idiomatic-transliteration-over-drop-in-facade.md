---
status: accepted
---

# Idiomatic transliteration of the Rust API instead of a drop-in facade

ADR-0001 committed to emulating swisseph.dart's stateful set-then-call API so
existing consumers could swap packages unchanged. An audit showed exactly one
production consumer (arjuna's `arrow/swe` facade: 3 files, ~14 methods), while
the emulation machinery — ConfigState, rebuild triggers, copy-on-write views,
asteroid auto-registration — was the hardest, most defect-prone part of the
design, built solely to recreate C warts on an engine deliberately designed
without them. We dropped the drop-in contract and instead transliterate the
`swisseph::*` Rust API symbol-for-symbol into Dart: one API design expressed
twice, full 63-method surface, with divergence only via named systematic
rules (Result → sealed `SweException` hierarchy, bitflags → extension-type
flag sets, payload enums → sealed classes, newtypes → extension types,
snake_case → camelCase).

## Considered options

- **Keep the drop-in facade** (ADR-0001): rejected — its only beneficiary is
  one internal facade that is cheap to migrate; its cost was permanent.
- **Freer Dart-first redesign**: rejected — two API designs to maintain, and
  every swisseph-rs evolution would need a translation decision instead of a
  mechanical delta.

## Consequences

- config_state, rebuild triggers, views/CoW, and asteroid auto-registration
  have no successor: `Ephemeris` is constructed once from an immutable
  `EphemerisConfig` (asteroids declared up front) and closed once.
- Cross-isolate sharing is refcounted at the FFI boundary: swisseph-ffi gains
  `swisseph_share` (an internal `Arc` clone), `swisseph_free` becomes a
  refcount drop. Every instance owns its handle equally; any close order is
  safe; the owner/view asymmetry disappears.
- Every public Dart symbol declares its Rust counterpart in a fixed-format
  dartdoc line, machine-checked by a totality test; the differential harness
  keeps swisseph.dart (C 2.10.03) as oracle via per-method oracle mappings
  (direct / composite / engine-trusted).
- No `version()` method ("2.10.03" compat lie dies); `engineVersion` reports
  the loaded Rust crate. No environment variables (swisseph-rs reads none).
- arjuna's `arrow/swe` migrates deliberately — the PRD-v1 backlog tied to the
  facade design (config_state, auto-registration, owner/view CoW) is wontfixed
  in yojana with this ADR as the citation.
