# wasm spike: Emscripten build of swisseph-ffi + mmap-over-MEMFS validation

**Date:** 2026-07-07
**Task:** swisseph-rs-dart/24
**Verdict: GO**

## Environment

- Emscripten 6.0.2, Rust 1.87 (wasm32-unknown-emscripten target)
- swisseph-ffi rev 14a1df6 (swisseph-rs 0.2.0)
- Node.js v26.4.0 (test harness)

## Build

`cargo build --target wasm32-unknown-emscripten -p swisseph-ffi --release` compiles
cleanly, including `memmap2` (which is `cfg(unix)` — Emscripten qualifies).

Linking with `emcc` requires `RUSTFLAGS="-C panic=abort"` to avoid
`__cpp_exception` symbol references from Rust's default unwinding. This is
standard for all Emscripten wasm targets.

Final link command:
```
emcc libswisseph_ffi.a -o swisseph_ffi.js \
  -s MODULARIZE=1 -s ALLOW_MEMORY_GROWTH=1 -s FORCE_FILESYSTEM=1 \
  -s EXPORTED_FUNCTIONS='[...]' -s EXPORTED_RUNTIME_METHODS='["FS",...]' -O2
```

## Results

### Moshier path (no files)

`swisseph_new` + `swisseph_calc_ut(Sun, J2000)` — **works**.

| Component | Value |
|-----------|-------|
| lon       | 280.368919675 |
| lat       | 0.000232327 |
| dist      | 0.983327645 |
| lon_speed | 1.019432094 |

### Swiss file path (mmap over MEMFS)

Two `.se1` files staged into Emscripten MEMFS via `FS.writeFile`, then
`swisseph_new(config{source=Swiss, ephe_path="/ephe"})` + `swisseph_calc_ut` — **works**.

| Component | Value |
|-----------|-------|
| lon       | 280.368918699 |
| lat       | 0.000227411 |
| dist      | 0.983327625 |
| lon_speed | 1.019434163 |

Moshier vs Swiss differ at the expected ~1e-6 level (different algorithms).
Both produce the correct Sun position for J2000 (~Cap 10).

### How mmap works on MEMFS

Emscripten shims `mmap` for MEMFS by allocating heap memory and copying the
file contents. This is not zero-copy but is functionally identical for
read-only access. swisseph-rs only reads (never writes) the mmap region, so
this is fine. No upstream patches needed.

## Artifact size

| Artifact | Raw | Gzipped |
|----------|-----|---------|
| swisseph_ffi.wasm | 580 KB | 273 KB |
| swisseph_ffi.js (Emscripten glue) | 60 KB | 17 KB |
| **Total** | **640 KB** | **290 KB** |
| Native .so (linux, comparison) | 1.1 MB | — |

Plus ephemeris files if using Swiss source (sepl_18.se1 = 473 KB,
semo_18.se1 = 1.3 MB — one epoch each; Moshier path needs zero files).

## What works, what needs patching

### Works out of the box
- Full C ABI (`swisseph_new`, `swisseph_calc_ut`, `swisseph_free`, etc.)
- `memmap2` compiles and functions over MEMFS
- Swiss ephemeris file reading via mmap
- Moshier (no-file) path
- Engine construction, calculation, destruction lifecycle

### Required build flags
- `RUSTFLAGS="-C panic=abort"` (standard for Emscripten targets)
- `emcc -s FORCE_FILESYSTEM=1` (MEMFS for staging .se1 files)
- `emcc -s ALLOW_MEMORY_GROWTH=1` (ephemeris files increase heap)
- `emcc -s MODULARIZE=1` (for clean JS module loading)

### No patches needed
- No upstream changes to swisseph-rs
- No feature flags to add/remove
- No mmap shims or alternative file access paths

## Go/no-go

**GO.** The Emscripten build path is straightforward, the C ABI works
end-to-end through MEMFS, and artifact size is reasonable. The web integration
slice can proceed with this approach.
