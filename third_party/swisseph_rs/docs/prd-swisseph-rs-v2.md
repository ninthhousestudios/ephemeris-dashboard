# PRD: swisseph_rs v2 — idiomatic Dart transliteration of the swisseph-rs API

Supersedes [prd-swisseph-rs-v1.md](./prd-swisseph-rs-v1.md) (drop-in facade
design) per [ADR-0002](./adr/0002-idiomatic-transliteration-over-drop-in-facade.md).
Vocabulary: [CONTEXT.md](../CONTEXT.md).

## Problem Statement

Dart astrology code today talks to the Swiss Ephemeris through swisseph.dart —
a faithful wrapper over vendored C 2.10.03 that inherits every C-era wart:
integer constants that compile when misused, set-then-call temporal coupling,
six-slot result arrays whose meaning depends on flags, sentinel returns and
magic `-2` values for errors. We have since built swisseph-rs: a pure-Rust,
stateless, fully typed port that is bit-compatible with C 2.10.03 and already
made the idiomatic API redesign once (payload enums, newtype Julian days,
per-family result structs, rich error enum). Dart consumers cannot reach any
of that design; the only Dart surface available re-exposes the C shape. The
sole production consumer (arjuna's `arrow/swe`, 3 files / ~14 methods behind
its own facade) is cheap to migrate, so preserving the C shape buys nothing.

## Solution

`swisseph_rs`: a Dart package that transliterates the `swisseph::*` public
API symbol-for-symbol — one API design, expressed twice. Typed end to end:
sealed `Body` hierarchy, extension-type Julian days (`JdUt1`/`JdTt`) and flag
sets, immutable `EphemerisConfig`, per-family result classes, a sealed
`SweException` hierarchy mirroring `swisseph::Error` (circumpolar is a typed
exception, not a magic return). The full 63-method `Ephemeris` surface plus
pure free functions ship in v1, on native (FFI over a cargo build hook
pinning swisseph-ffi) and web (Emscripten wasm + wasm_ffi + MEMFS).
Correctness is proven by an oracle-mapped differential harness against
swisseph.dart (oracle version 2.10.03) under the established agreement
classes. Divergence from the Rust API is legal only via named systematic
rules; every public symbol declares its counterpart, machine-checked.

## User Stories

1. As an astrology app developer, I want to construct an `Ephemeris` from an
   immutable `EphemerisConfig`, so that a calculation's behavior is fully
   determined by values visible at the construction site.
2. As an astrology app developer, I want to compute planetary positions with
   `calcUt(JdUt1, Body, CalcFlags)` returning a typed `CalcResult`, so that I
   read `longitude` instead of guessing what `data[0]` means under my flags.
3. As an astrology app developer, I want `Body` to be a sealed hierarchy
   (`Body.sun`, `Body.asteroid(AsteroidId(433))`, `Body.fictitious(...)`,
   `Body.planetMoon(...)`), so that an invalid body is unrepresentable rather
   than a runtime integer error.
4. As an astrology app developer, I want flag sets with `operator |` and
   named constants (`CalcFlags.speed | CalcFlags.equatorial`), so that flag
   composition is readable and type-safe against mixing flag families.
5. As an astrology app developer, I want `JdUt1` and `JdTt` to be distinct
   extension types, so that passing a UT day where TT is expected is a
   compile error instead of a subtle ephemeris offset.
6. As an astrology app developer, I want `DateTime` ↔ `JdUt1` conversion
   helpers alongside the mirrored `utcToJd`/`jdToUtc`, so that I can enter
   and leave Julian-day space at the API edge without hand-rolling math.
7. As an astrology app developer, I want sidereal positions by passing
   `SiderealMode` in config or via the `*WithConfig` per-call variants, so
   that sidereal calculation is explicit at the call site with no ambient
   mode to forget to reset.
8. As an astrology app developer, I want topocentric positions via a
   `TopoPosition` in config or per-call config override, so that observer
   location is data, not hidden setter state.
9. As an astrology app developer, I want to declare asteroid and planet-moon
   bodies in `EphemerisConfig`, so that all file I/O happens at construction
   and calculation latency is flat and predictable.
10. As an astrology app developer, I want house cusps from
    `houses`/`housesEx`/`housesEx2` with a `HouseSystem` enum and typed
    `HouseResult`/`AscMc`, so that house math is readable and exhaustive
    over supported systems.
11. As an astrology app developer, I want ayanamsa values from the
    `getAyanamsa*` family, so that sidereal frameworks beyond built-in modes
    can be constructed.
12. As an astrology app developer, I want rise/set/transit via `riseTrans`
    and `riseTransTrueHor` with typed results, and a
    `CircumpolarBodyException` I can catch with an `on` clause, so that the
    polar edge case is explicit control flow instead of a magic `-2`.
13. As an astrology app developer, I want solar/lunar eclipse and occultation
    searches (`solEclipseWhenGlob/Loc/Where/How`, `lunEclipseWhen/WhenLoc/How`,
    `lunOccultWhenGlob/Loc/Where`) returning typed per-family results, so
    that eclipse work stops decoding positional double arrays.
14. As an astrology app developer, I want crossing searches (`solcross`,
    `mooncross`, `mooncrossNode`, `helioCross` and UT variants), so that
    ingress and node-crossing charts are first-class searches.
15. As an astrology app developer, I want fixed-star positions, magnitudes,
    and names via the `fixstar2*` family and `Star`/`StarCatalog` types, so
    that star work uses structured identity instead of comma-string parsing.
16. As an astrology app developer, I want heliacal event calculations
    (`heliacalUt`, `heliacalPhenoUt`, `visLimitMag`, `heliacalAngle`,
    `topoArcusVisionis`) with typed results, so that visibility work is
    possible without decoding 50-slot arrays.
17. As an astrology app developer, I want nodes/apsides (`nodAps`,
    `nodApsUt` with `NodApsMethod`), orbital elements
    (`getOrbitalElements`, `orbitMaxMinTrueDistance`), phenomena
    (`pheno`/`phenoUt`), and Gauquelin sectors, so that the full analytical
    surface of the engine is reachable from Dart.
18. As an astrology app developer, I want azimuth/altitude transforms and
    refraction (`azalt`, `azaltRev`, `refrac`, `refracExtended`) plus the
    date/time utilities (`julday`, `revjul`, `dayOfWeek`, `utcTimeZone`,
    `deltaT`, `timeEqu`, `lmtToLat`/`latToLmt`, `getPlanetName`), so that no
    workflow needs a second astronomy dependency.
19. As an astrology app developer, I want per-call engine override via the
    `CalcFlags` JPLEPH/SWIEPH/MOSEPH bits with C's precedence, so that I can
    mix engines call-by-call against one handle exactly like the Rust crate.
20. As an astrology app developer, I want every error surfaced as a specific
    `SweException` subclass mirroring the `swisseph::Error` variants, so
    that I can catch `BeyondEphemerisLimitsException` distinctly from
    `FileNotFoundException` with ordinary Dart `on` clauses.
21. As a server developer, I want `ephemeris.share()` to hand a token to
    another isolate that materializes as a co-equal `Ephemeris` over the
    same refcounted engine, so that N workers share one loaded ephemeris
    with flat memory and any close order is safe by construction.
22. As a server developer, I want `close()` to be idempotent with a
    `NativeFinalizer` backstop per instance, so that leaked instances
    degrade to GC pressure instead of native memory leaks.
23. As a Flutter web developer, I want the same API on web via the wasm
    build with `loadEpheFile` staging files into MEMFS before construction,
    so that web and native code paths differ only at the loader seam.
24. As a Flutter web developer, I want native-only APIs (`share`) to throw
    `UnsupportedError` on web, so that platform gaps fail loudly at the
    call site instead of silently misbehaving.
25. As a library maintainer, I want every public symbol to carry a
    fixed-format `Counterpart:` dartdoc line with a totality test, so that
    the transliteration rule is a machine-checked invariant rather than
    reviewer memory.
26. As a library maintainer, I want the rust shim to pin swisseph-ffi to an
    exact git rev with bumps as reviewed one-line changes, so that the
    engine under the bindings never moves silently.
27. As a library maintainer, I want `engineVersion` to report the loaded
    Rust crate version at runtime, so that support issues can identify the
    actual engine binary in the field.
28. As a test engineer, I want a differential harness driving swisseph_rs
    and swisseph.dart in one process through a total oracle map (direct /
    composite / engine-trusted per public method), so that every method's
    verification story is declared and undeclared methods fail the build.
29. As a test engineer, I want every compared value assigned exactly one
    agreement class (bitwise / positional / boundary / search), so that
    tolerance decisions are visible policy, not per-test improvisation.
30. As a test engineer, I want the `*WithConfig` variants verified as
    composite mappings against oracle set-then-call sequences, so that the
    config-marshalling seam — where facade-era bugs would have lived — is
    exercised deliberately.
31. As a test engineer, I want stress-test-0.2 rewritten against the new
    API (100 isolates over a shared engine, agreement checks at scale), so
    that the refcounted sharing design is proven under production-shaped
    load.
32. As a test engineer, I want the libaditya 545-value cross-validation
    green against the new API, so that an independent third dataset guards
    the whole stack.
33. As an arjuna developer, I want a migration of `arrow/swe`'s facade
    (~14 methods, 3 files) to swisseph_rs, so that the sole production
    consumer proves the API on real workloads and swisseph.dart can retire
    from the dependency tree.

## Implementation Decisions

- **Transliteration rule** (CONTEXT.md) governs the whole surface: the Dart
  public API mirrors `swisseph::*` symbol-for-symbol; deviation is legal
  only via the named systematic divergences (Result → sealed exceptions,
  bitflags → extension-type flag sets, payload enums → sealed classes,
  newtypes → extension types, snake_case → camelCase, `&Ephemeris` free fns
  → methods only, additive `DateTime` helpers). Full 63-method `Ephemeris`
  surface plus pure free functions in v1.
- **Modules**: `types` — every pure-Dart declaration (sealed `Body`, enums,
  flag and Julian-day extension types, `EphemerisConfig`, result classes,
  `SweException` hierarchy); zero FFI imports, isolation-testable. `bindings`
  — FFI declarations only, native/web halves behind conditional-import
  barrels (wasm_ffi on web). `marshal` — the only meeting point of Dart and
  FFI types: config packing, result unpacking, `(code, errBuf)` → typed
  exception. `ephemeris` — the `Ephemeris` class and free functions, thin
  bodies (marshal, call, unmarshal, throw).
- **Errors**: sealed `SweException` base, one subclass per `SweErrorCode`
  variant (1:1 with `swisseph::Error`), constructed from code + message;
  payloads ride in the message for v1. `Panic` code maps to a distinct
  exception representing an engine bug.
- **Lifecycle**: construction opens all configured files and throws typed
  exceptions; no mutation, no rebuilds, no env vars (`ephePath` explicit).
  `close()` idempotent; use-after-close throws `StateError`;
  `NativeFinalizer` backstop.
- **Sharing**: swisseph-ffi gains `swisseph_share` (internal `Arc` clone) and
  `swisseph_free` becomes a refcount drop — an upstream prerequisite task in
  swisseph-rs. `share()` produces an isolate-sendable token; every instance
  owns its handle equally. Native-only; `UnsupportedError` on web.
- **Versioning**: no `version()` method; top-level `engineVersion` reads
  `swisseph_version`. "2.10.03" appears only as oracle version in test
  vocabulary.
- **Native build**: build hook runs cargo against a shim crate pinning
  swisseph-ffi to an exact git rev of ninthhousestudios/swisseph-rs.
- **Web build**: `wasm32-unknown-emscripten` target reusing the wasm_ffi +
  MEMFS seams proven by swisseph.dart; `loadEpheFile` stages ephemeris files
  before construction; mmap-over-MEMFS validation is the front-loaded spike.
- **Counterpart discipline**: fixed-format dartdoc line on every public
  symbol; totality test walks the public API and fails on missing or
  unknown declarations.

## Testing Decisions

- A good test asserts external behavior: numbers returned, exceptions
  thrown, never module internals. The oracle for behavior is swisseph.dart
  driving vendored C 2.10.03; the oracle for API shape is `swisseph::*`.
- **types**: pure-Dart unit tests, no FFI — flag algebra, Julian-day and
  `DateTime` conversions, config validation, exception construction from
  (code, message) pairs.
- **marshal**: round-trip tests over the FFI structs (config in, results
  out), including the error path for every `SweErrorCode`.
- **Counterpart totality test**: public-API walk asserting every symbol
  declares a counterpart.
- **Differential harness**: total oracle map (direct / composite /
  engine-trusted with reason); every compared value in exactly one
  agreement class; unclassified comparisons and unmapped methods fail by
  design. Composite mappings drive oracle set-then-call sequences against
  `*WithConfig` calls. Prior art: swisseph.dart's own suite (ported
  scenarios become harness cases) and the agreement-class tolerances
  established in the v1 cycle.
- **stress-test-0.2 rewrite**: 100 isolates over one shared engine via
  `share()`, full-surface sweep, agreement checks at scale — the normative
  proof of refcounted sharing.
- **libaditya cross-validation**: 545-value dataset green against the new
  API.
- **Web**: wasm spike validates mmap-over-MEMFS before any web work builds
  on it; web test leg asserts `UnsupportedError` on native-only surface.

## Out of Scope

- Drop-in compatibility with swisseph.dart — dead per ADR-0002; arjuna's
  `arrow/swe` migrates deliberately (story 33), everything else is tests.
- Structured exception payloads across the FFI boundary — future additive
  step (typed fields join existing exception classes without breakage).
- JPL ephemeris files on web (MEMFS size; carried from v1).
- Any Dart-only API surface beyond the `DateTime` helpers — if it is not in
  `swisseph::*`, it is not in this package.
- Isolate pools, worker scheduling, async wrappers — quiver's layer, not
  this package's.
- Performance parity guarantees with the C-backed package (Rust Swiss-file
  single-call is ~2.6× C; documented, not contracted).

## Further Notes

- The swisseph-ffi `Arc` sharing change is the only upstream code
  prerequisite; it lands in swisseph-rs as its own reviewed task before the
  Dart sharing surface builds on it.
- Name proximity to swisseph.dart (`calcUt`, `riseTrans`) is coincidence of
  shared C ancestry, not contract — the counterpart is always the Rust
  symbol. This still makes arjuna's migration mostly mechanical.
- Top technical risk is unchanged from v1: mmap-over-MEMFS under
  Emscripten. The spike stays front-loaded before web integration work.
- The enforcement ledger and sutra seed are re-derived from this PRD in the
  decompose/seed passes that follow; v1's ledger rows tied to facade claims
  are retired with ADR-0002 as citation.
