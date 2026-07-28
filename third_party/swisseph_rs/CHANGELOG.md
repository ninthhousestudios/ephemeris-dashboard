## 0.3.0

- The web WASM artifacts now ship as Flutter package assets. `wasm/swisseph_ffi.js`
  and `wasm/swisseph_ffi.wasm` are declared under a `flutter: assets:` block, so a
  Flutter consumer receives both files from the resolved `swisseph_rs` version with
  no copy step, and the new `wasmAssetPath` constant names where the bundler puts
  them: `await initializeWasm(wasmAssetPath)`.

  **Delete any vendored `web/swisseph_ffi.js` / `web/swisseph_ffi.wasm` from your
  app.** Hand-copied glue was the only delivery mechanism through 0.2.9 and it had
  no link to the version in `pubspec.yaml`: bumping the dependency updated the Dart
  loader in `lib/` and left the copied binaries untouched. That is why the 0.2.8
  fix for the resizable-`ArrayBuffer` class of bug (Web Crypto and `TextDecoder`
  both reject views onto a growable `WebAssembly.Memory`) did not reach an app whose
  pubspec already said `^0.2.9` — the pubspec bump was never the delivery path. The
  failure is web-only, release-only and browser-version-dependent (older embedded
  Chromium still hands out a non-resizable buffer), and the `.wasm` is byte-identical
  across 0.2.7–0.2.9 because the fixes are glue-only, so "the wasm didn't change" is
  true and useless as a diagnostic. Bundled assets make the skew unrepresentable
  instead of detectable.

  Cost: Flutter's asset system has no per-platform filtering, so every consumer
  carries ~924 KB on every platform, including native builds that never load it.

  Non-Flutter web consumers (plain `package:web` apps, no asset bundler) still copy
  both files and pass their own path; `initializeWasm` is unchanged.

## 0.2.9

- Bumped swisseph-ffi to `d8ef3bb` (swisseph-rs 0.1.8), which fixes an
  infinite Newton loop in crossing refinement against DE441 ephemeris files.
  0.1.6 introduced that fix along with `swisseph::Error::NoConvergence`, which
  the FFI now maps to the new append-only code `-17`, surfaced in Dart as
  `NoConvergenceException`. 0.1.7 and 0.1.8 carry that mapping plus a
  correction to the generated C header's `swisseph_azalt` signature; neither
  changes an ABI this package consumes.
- Added `NoConvergenceException`, the counterpart to
  `swisseph::Error::NoConvergence`. It joins the `SweException` hierarchy, so
  exhaustive switches over `SweException` need a new arm.

## 0.2.8

- Fixed web builds throwing `TypeError: The provided ArrayBufferView value
  must not be resizable` on every `Ephemeris` construction in current Chrome.
  Under `ALLOW_MEMORY_GROWTH`, WASM memory is exposed as a resizable
  ArrayBuffer, and Web Crypto rejects views backed by one — so the engine's
  first entropy request (16 bytes, inside `swisseph_new`) threw. The WASM
  module loaded fine, so the failure landed on first use rather than at
  startup. Fixed at the source via an `--js-library` override of Emscripten's
  `$initRandomFill` (`wasm/lib-random-fill.js`), so generated glue fills a
  plain buffer and copies. The `.wasm` binary is unchanged.
- Fixed `initializeWasm()` hanging forever instead of throwing when the glue
  script fails to load. The pre-load used `modulePath` verbatim while
  `wasm_ffi` resolves an extensionless path to `<path>.js`, so the documented
  default (`'swisseph_ffi'`) fetched a 404; awaiting only `onLoad` then hung
  indefinitely. The pre-load now mirrors the extension resolution and rejects
  on load error.
- Fixed `initializeWasm()` appending a second `.js` to glue URLs that carry a
  query string, e.g. a cache-busted `swisseph_ffi.js?v=1`. The extension is
  now resolved from the parsed URI's last path segment, matching how
  `wasm_ffi` decides.
- Fixed `loadEpheFile()`/MEMFS being silently dead when `initializeWasm()`
  was given a `..`-relative `modulePath`. `wasm_ffi`'s script dedup compares
  a tag's *resolved* URL against the raw string with `endsWith`, so any
  relative path got a second glue tag injected; the re-executed glue stripped
  the module-capture wrapper and every MEMFS call threw
  `StateError('Emscripten module not available.')`. The capture is now an
  accessor property on `globalThis` that survives any number of glue
  executions, and only the active initialization attempt may publish a
  module — a post-initialization consumer instantiating the glue for its own
  purposes can no longer redirect this package's filesystem handle.
- Fixed the glue's string decoding throwing `TypeError: The provided
  ArrayBuffer value must not be resizable` for strings longer than 16 bytes
  (same Chrome resizable-memory change as above — `TextDecoder` refuses
  views into a resizable heap). The Swiss-file path was the first to return
  a string that long. Patched via an idempotent post-processing step in
  `wasm/build.sh` (`.slice()` instead of `.subarray()` when the heap is
  resizable), matching what newer Emscripten does upstream.
- `initializeWasm()` is now bounded end to end: 30 s for the glue script
  load and 60 s for module instantiation (which includes the sibling `.wasm`
  fetch), each failing with a `TimeoutException` instead of hanging on a
  server that accepts the connection and never responds. A failed
  initialization releases the single-flight latch, so it may be retried.

Web consumers who added a `crypto.getRandomValues` workaround to their
`index.html` for the resizable-buffer error can remove it after upgrading;
the fix now ships inside the package's WASM glue.

Note for anyone else shipping an Emscripten module: this is not specific to
this package. emcc 6.0.2 still emits an unguarded
`crypto.getRandomValues(HEAPU8.subarray(...))` for non-`SHARED_MEMORY`
builds, so any module built with `ALLOW_MEMORY_GROWTH` hits it on current
Chrome. Bumping the Emscripten SDK does not fix it.

## 0.2.7

- Fixed `nodAps`/`nodApsUt` for numbered asteroids (e.g. Eros 433) with the
  Swiss ephemeris backend. The internal position provider was constructed with
  empty asteroid and planet-moon file lists, causing `EphemerisNotAvailable`
  errors. Also includes `calcPctr` alias normalization for asteroid bodies.
  Bumped swisseph-ffi to `a4cf744`.

## 0.2.6

- Fixed `calcPctr` for main asteroid bodies (Chiron, Pholus, Ceres, Pallas,
  Juno, Vesta). The internal position provider was missing the main asteroid
  file set, causing `BeyondEphemerisLimits` errors for these bodies even when
  `.se1` files were present. Bumped swisseph-ffi to `c3c27cb`.

## 0.2.5

- Fixed asteroid file parsing for MPC numbers > 22767 (e.g. Quaoar 50000).
  2-byte `ipl[]` entries were sign-extended from i16, wrapping body IDs above
  32767 to negative values and causing "ephemeris not available" errors despite
  valid files on disk. Bumped swisseph-ffi to `b6a9f82`.

## 0.2.4

- **Breaking:** `getAyanamsaEx`, `getAyanamsaExWithConfig`, and
  `getAyanamsaUt` now return `({double ayanamsa, CalcFlags flagsUsed})`
  instead of bare `double`, exposing ephemeris-fallback information.

## 0.2.3

- Added `siderealTime` and `siderealTime0` methods on `Ephemeris` for
  Greenwich Apparent Sidereal Time (GAST).
- Added `cotrans` and `cotransWithSpeed` free functions for ecliptic ↔
  equatorial coordinate transformation.
- Bumped swisseph-ffi to `64bc1533` (adds `swisseph_cotrans` /
  `swisseph_cotrans_sp` FFI exports).

## 0.2.2

- Build hook: Android and iOS cross-compilation support. Maps
  `targetOS`/`targetArchitecture` to Rust target triples, wires the NDK
  clang linker for Android, and fails early with an actionable message
  when a `rustup` target is missing. Desktop path unchanged.

## 0.2.1

- Fixed web: `loadEpheFile` threw "Emscripten module not available" because
  the raw Emscripten module instance was never stored for `getEmscriptenFS()`.
  `initializeWasm` now pre-loads the glue script and wraps the factory to
  capture the module in `__swissephRsModule` before `DynamicLibrary.open`
  consumes it.
- Added `web` dependency (used by `loader_web.dart` for script injection).

## 0.2.0

- Added `fixstar2WithConfig` and `fixstar2UtWithConfig` for per-call sidereal
  and topocentric overrides on fixed-star computations.

## 0.1.1

- Added proper copyright notes to LICENSE and source files.

## 0.0.1-dev

- Initial development release.
- Full transliteration of the swisseph-rs Rust API: positions, houses,
  ayanamsa, eclipses, occultations, rise/set, crossings, fixed stars,
  heliacal, phenomena, nodes/orbits, horizon, refraction, date/time.
- Native platforms via Cargo build hook.
- Web platform via prebuilt wasm artifact.
- Cross-isolate engine sharing via `Ephemeris.share()`.
