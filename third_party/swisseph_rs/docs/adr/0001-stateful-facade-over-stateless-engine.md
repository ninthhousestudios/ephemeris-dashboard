---
status: superseded by ADR-0002
---

# Stateful facade over the stateless Rust engine

swisseph.dart's public API is set-then-call (`setSidMode` → `calcUt`) because
the C library it wraps keeps process-global state. swisseph-rs deliberately has
no mutable state — config is frozen at `Ephemeris::new`. To be a drop-in
replacement, `swisseph_rs` re-creates the stateful API as a Dart-side facade:
setters write per-instance Dart fields; sidereal mode, topo position, and lapse
rate are forwarded as per-call FFI parameters; only values that live in
`SweConfig` (`setEphePath`, `setJplFile`, `setTidAcc`, `setDeltaTUserdef`,
`setAstroModels`, asteroid auto-registration) invalidate and lazily rebuild the
opaque handle. We chose facade emulation over exposing the stateless API
directly (not drop-in — the entire point of the package) and over rebuilding
the handle on every setter (needless construction cost; per-call params already
cover the hot setters). Engine selection stays per-call via `iflag` bits with
C's MOSEPH > JPLEPH > SWIEPH precedence, so `seFlgMosEph`/`seFlgSwiEph`
switching never rebuilds.

## Consequences

- Cross-isolate handle sharing becomes safe and is exposed additively
  (`nativeHandle` / `SwissEph.view(addr)`); a view detaches via copy-on-write
  when it hits a rebuild trigger, and `close()` frees only owned handles.
- `setInterpolateNut` is a documented no-op (pure C-cache performance hint);
  `version()` reports the compat baseline "2.10.03", with the Rust crate
  version on the additive `engineVersion` getter.
- The first calc of an undeclared asteroid pays a hidden ms-scale handle
  rebuild (C-parity lazy semantics; the stateless engine opens files only at
  construction).
