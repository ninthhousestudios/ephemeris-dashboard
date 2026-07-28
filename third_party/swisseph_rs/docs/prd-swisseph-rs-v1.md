# PRD: swisseph_rs — drop-in Dart bindings to the pure-Rust Swiss Ephemeris

> **SUPERSEDED** by [prd-swisseph-rs-v2.md](./prd-swisseph-rs-v2.md) per
> [ADR-0002](./adr/0002-idiomatic-transliteration-over-drop-in-facade.md):
> the drop-in contract was dropped in favor of an idiomatic transliteration
> of the swisseph-rs Rust API. Retained for the domain analysis and the
> facade design rationale it records.

## Problem Statement

Applications built on swisseph.dart inherit the C Swiss Ephemeris's
process-global mutable state. Every isolate needs its own copy of the shared
library (the copy-the-.so hack), configuration must be defensively re-set
after every await point, and true concurrent sharing is impossible. swisseph-rs
was built to eliminate exactly this — a stateless, `Send + Sync`,
bit-compatible port — but there is no Dart binding for it, so Dart users
cannot benefit without rewriting their applications against a new API.

## Solution

A new pub package, `swisseph_rs` (directory `swisseph.rs.dart`), that is a
drop-in replacement for swisseph.dart: same ~93-method `SwissEph` API, same
result types, constants, and exception behavior, backed by `swisseph-ffi`
(the C ABI wrapper over swisseph-rs). A stateful facade emulates the
set-then-call API on the stateless engine: hot setters become per-call state,
cold setters become rebuild triggers on a lazily constructed handle. The
package ships native (build hook running cargo against a pinned git dep) and
web (Emscripten wasm32 build) in v1. The drop-in contract is proven by three
test legs: the ported swisseph.dart suite, a both-packages-in-one-process
differential harness organized by agreement class, and a full-scale port of
stress-test-0.2. As additive extensions, the package exposes `engineVersion`
and cross-isolate handle sharing (owner/view with copy-on-write detach).

## User Stories

1. As a swisseph.dart user, I want to switch to swisseph_rs by changing only my dependency and import line, so that I get the stateless engine without rewriting any calling code.
2. As a chart-calculation service developer, I want to share one ephemeris handle across all isolates, so that I stop copying the shared library per isolate and paying per-isolate configuration discipline.
3. As a Dart developer, I want `setSidMode`/`setTopo`/`setLapseRate` to cost nothing in hot loops, so that per-chart configuration churn does not degrade throughput.
4. As an existing caller, I want `calcUt` with `seFlgMosEph`/`seFlgSwiEph`/`seFlgJplEph` to select the engine per call with C precedence, so that flag-driven engine switching keeps working unchanged.
5. As an existing caller, I want `setEphePath`, `setJplFile`, `setTidAcc`, `setDeltaTUserdef`, and `setAstroModels` to behave observably like C (taking effect on subsequent calls), so that configuration sequences ported from swisseph.dart remain correct.
6. As an app that deploys with the `SE_EPHE_PATH` environment variable, I want the facade to honor it when `setEphePath` was never called, so that I do not silently lose Swiss precision to the Moshier fallback.
7. As an astrology app author, I want to compute positions for asteroids (`seAstOffset + N`) without pre-declaring them, so that C's lazy asteroid-file semantics carry over.
8. As a version-gating caller, I want `version()` to return the compat baseline "2.10.03", so that feature checks written against the C library keep working.
9. As an operator debugging provenance, I want an `engineVersion` getter reporting the Rust crate version, so that I can tell which engine actually produced my numbers.
10. As a caller of methods that are meaningless on a stateless engine (`setInterpolateNut`, `getLibraryPath`), I want benign no-op/synthetic behavior, so that migrated code never breaks on harmless calls.
11. As a web developer, I want `SwissEph.load()` to work in the browser with the wasm build, so that my swisseph.dart web app migrates unchanged.
12. As a web developer, I want `loadEpheFile()` to push `.se1` bytes into the module filesystem, so that Swiss-precision calculations work in the browser exactly as they do today.
13. As a native consumer, I want `dart pub get` to build the Rust library automatically via the build hook, so that setup stays one command (given a Rust toolchain).
14. As a native consumer without rustup, I want a clear, actionable error from the build hook, so that I know exactly what to install.
15. As a Flutter/Android developer, I want the build hook to cross-compile for my target architecture, so that the package works in mobile builds.
16. As an error-handling caller, I want `SweException` thrown exactly where swisseph.dart throws (including crossing sentinels and eclipse conventions), and `riseTrans` circumpolar `-2` returned as a value, so that my error paths behave identically.
17. As a numerical-fidelity auditor, I want every compared value in the differential harness assigned to an agreement class (bitwise, positional, boundary, search), so that "the packages agree" has a precise, checkable meaning.
18. As a maintainer, I want the ported swisseph.dart test suite and the 545-value libaditya validation green against swisseph_rs, so that drop-in fidelity is proven by the old package's own expectations.
19. As a maintainer, I want a full-scale port of stress-test-0.2 (100 isolates, all methods, both engines), so that the facade holds up under the same concurrent load the C binding was proven under.
20. As a maintainer, I want a stress-test check that a shared handle produces bit-identical results across isolates, so that the headline stateless capability is demonstrated, not just claimed.
21. As a performance-sensitive user, I want per-isolate views of one owner's handle with safe ownership semantics (copy-on-write detach on rebuild triggers, close frees only owned handles), so that sharing can never produce a use-after-free.
22. As a user awaiting between configuration and calculation, I want facade state that cannot drift across await points, so that the defensive re-set discipline from swisseph.dart becomes unnecessary.
23. As a future contributor, I want the domain language (CONTEXT.md) and the facade decision (ADR-0001) documented, so that the design's non-obvious choices survive maintainer turnover.
24. As the package author, I want the Rust dependency pinned to a specific rev of the swisseph-rs git repo, so that engine upgrades are deliberate one-line bumps.

## Implementation Decisions

- Fork-and-swap genesis: package structure, result types, constants, barrel,
  conditional-import seams, and tests originate from swisseph.dart; the
  binding layer and method bodies are replaced. Public API deviations are
  forbidden; API growth is additive-only (drop-in contract).
- Seven modules: bindings (typed FFI lookups + config/sid-mode structs);
  config_state (the deep module: facade state, rebuild triggers, lazy handle
  construction, asteroid auto-registration, owner/view copy-on-write,
  env-path defaulting, close ownership); the SwissEph facade (~93 thin method
  bodies with arena marshalling and error mapping); loader seams (native/web
  conditional imports); the cargo build hook; wasm build infra (Emscripten);
  and the test legs.
- Facade state model per ADR-0001: sidereal mode, topocentric position, and
  lapse rate are per-call state forwarded as FFI parameters; ephe path, JPL
  file, tidal acceleration, deltaT override, astro models, and the declared
  asteroid set live in the handle config, and changing them invalidates the
  handle (rebuild triggers). The handle is rebuilt lazily on next use.
- Engine selection is per-call via iflag bits with C precedence
  (MOSEPH > JPLEPH > SWIEPH), falling back to the handle's config source;
  engine switching never rebuilds the handle.
- Asteroid auto-registration: first calc of an undeclared asteroid or
  planet-moon body grows the declared set and transparently rebuilds.
- Cross-isolate sharing is public API: an owner exposes its handle address; a
  view constructed from that address shares the handle for calculation, keeps
  its own per-call state, detaches via copy-on-write when it hits a rebuild
  trigger, and never frees handles it does not own. Native-only.
- version() returns the compat baseline "2.10.03"; engineVersion returns the
  Rust crate version. setInterpolateNut is a documented no-op; getLibraryPath
  returns the loaded library path synthetically.
- SE_EPHE_PATH from the environment is the default ephe path on native when
  setEphePath was never called; explicit setEphePath always wins.
- Error mapping preserves swisseph.dart observable behavior: negative FFI
  error codes throw SweException with the Rust-formatted message; crossing
  functions throw where the C sentinel convention made swisseph.dart throw;
  riseTrans circumpolar returns -2 as a value; eclipse functions return
  positive flag bitmasks. flags_used flows into the existing returned-flags
  fields.
- Native delivery: the build hook runs cargo against a shim crate pinning
  swisseph-ffi to a git rev of ninthhousestudios/swisseph-rs; the built
  library is registered as a code asset. Missing cargo produces an actionable
  error naming rustup.
- Web delivery: swisseph-ffi compiled to wasm32-unknown-emscripten so the
  existing wasm_ffi loader pattern and MEMFS-based loadEpheFile carry over;
  prebuilt js/wasm artifacts are committed as assets. The mmap-over-MEMFS
  spike is the first wasm deliverable and the project's top technical risk;
  fallback is a plain-read file path or byte-oriented config upstream.

## Testing Decisions

- A good test asserts observable behavior (returned values, thrown
  exceptions, returned flags) — never facade internals such as when the
  handle was rebuilt, except in config_state's own unit tests where the
  handle lifecycle IS the external behavior of that module.
- config_state gets dedicated unit tests against a fake handle factory:
  rebuild-trigger classification, lazy construction, auto-registration
  growth, copy-on-write detach, close-only-frees-owned, env-path defaulting.
  No ephemeris math involved.
- Leg 1: the ported swisseph.dart unit suite and the 545-value libaditya
  cross-validation run against swisseph_rs, with tolerance annotations where
  documented stateless boundaries bite (deflection speed, Moshier osculating
  node speed, SPEED3 at file boundaries).
- Leg 2: the differential harness dev-depends on both packages in one process
  (distinct native symbol namespaces), sweeps bodies × dates × flags ×
  ayanamsas × house systems × locations, and compares by agreement class:
  bitwise for pure math, positional at 1e-9, boundary at the documented
  epsilons, search epsilons for iterative event finding. A green harness is
  the normative test of the drop-in contract and the routine regression gate.
- Leg 3: stress-test-0.2 ported at full scale (100 isolates, all public
  methods, both engines) as a milestone event, with isolation checks
  reinterpreted as facade-state independence plus a new check that a shared
  handle yields bit-identical results across isolates.
- Prior art: swisseph.dart's existing test files, its libaditya validation
  suite, and stress-test-0.2; swisseph-rs golden-test tolerances for the
  boundary class.

## Out of Scope

- Any public-API deviation from swisseph.dart; an idiomatic-Dart API layer is
  a possible future package, not this one.
- Performance parity with C for single-call Swiss-file workloads (documented
  ~2.6×; thread scaling is the win, not single-call latency).
- JPL ephemeris on web; Flutter plugin packaging; asteroid coverage beyond
  the bundled set; EP4 reader; the v1 fixstar API; real setInterpolateNut
  behavior.
- Publishing mechanics to pub.dev (prebuilt binary hosting, package scoring)
  beyond keeping the package structurally publishable.

## Further Notes

- Domain language lives in CONTEXT.md (drop-in contract, compat baseline,
  facade, handle, rebuild trigger, per-call state, owner/view,
  auto-registration, agreement class). ADR-0001 records the stateful-facade
  decision and its consequences.
- The differential harness cannot catch environment-dependent defaulting
  (it always sets paths explicitly) — SE_EPHE_PATH parity is a design
  obligation, covered by config_state unit tests instead.
- swisseph.dart's vendored C is exactly 2.10.03, the same version swisseph-rs
  is bit-compatible with, so differential comparisons are apples-to-apples.
