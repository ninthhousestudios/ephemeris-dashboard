// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Counterpart: (systematic divergence: web loader seam)
///
/// URL of the Emscripten glue script as Flutter's asset bundler places it in a
/// consuming web build.
///
/// This package declares `wasm/swisseph_ffi.js` and `wasm/swisseph_ffi.wasm`
/// as Flutter assets, so a Flutter consumer receives both files from the
/// *resolved* `swisseph_rs` version with no copy step:
///
/// ```dart
/// await initializeWasm(wasmAssetPath);
/// ```
///
/// Pass this rather than hardcoding the string: the glue and the Dart loader
/// then always come from one package version, which is what makes the skew
/// that broke swe_dashboard on 0.2.7 glue unrepresentable. The glue resolves
/// its sibling `.wasm` relative to its own script URL, and the bundler keeps
/// both files in this directory, so no `locateFile` override is needed.
///
/// Non-Flutter web consumers (plain `package:web` apps) have no asset bundler
/// and must still copy both files into their own `web/` directory, passing
/// whatever path they serve them from.
const wasmAssetPath = 'assets/packages/swisseph_rs/wasm/swisseph_ffi.js';
