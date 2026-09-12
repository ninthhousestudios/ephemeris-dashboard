// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Platform seam for loading an optionally-downloaded city-atlas tier from the
/// managed ephe directory. Native reads + gunzips the file; web has no
/// filesystem and always returns null (falls back to the bundle).
///
/// Mirrors the ephe staging seam: the `dart:io` half is the default, the web
/// half is selected when `dart.library.js_interop` is available so `dart:io`
/// never reaches a web compile.
library;

export 'atlas_store_io.dart'
    if (dart.library.js_interop) 'atlas_store_web.dart';
