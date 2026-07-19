// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ephemeris/runner.dart';
import 'swe_utils.dart';

// Conditional dart:io import — only used when !kIsWeb.
import 'swe_service_io.dart'
    if (dart.library.js_interop) 'swe_service_stub.dart'
    as io;

/// Resolved once at startup; null on web (Moshier mode, no files needed).
String? _ephePath;

/// Call once from main() before runApp(). Resolves or extracts the
/// ephemeris data files (.se1 + sefstars.txt) to a filesystem directory
/// that the C library can read.
///
/// - **Web:** loads WASM module, stages bundled .se1 files into MEMFS.
/// - **Linux/macOS/Windows desktop:** checks release bundle, then dev-mode
///   .dart_tool/package_config.json.
/// - **Android/iOS:** copies bundled assets/ephe/ to the app's support
///   directory on first launch (skips if already present).
Future<void> initSweEphePath() async {
  // --- Web: WASM + load bundled ephe into MEMFS ---
  if (kIsWeb) {
    await io.initWasm();
    _ephePath = await io.loadBundledEpheFiles();
    return;
  }

  // --- Native platforms (dart:io available) ---
  _ephePath = await io.initNativeEphePath();
}

/// Whether .se1 ephemeris files were found at startup.
bool get hasEpheFiles => _ephePath != null;

/// Bundled ephe path resolved at startup (null on web / when nothing found).
/// Consumers (e.g. resolvedEphePathProvider) use this as a fallback when
/// a user-selected dir is empty or missing.
String? get bundledEphePath => _ephePath;

/// SweUtils backed by the runner's rs.Ephemeris — for untraced utility calls.
/// Resolves the engine lazily per call so it tracks engine rebuilds.
final sweProvider = Provider<SweUtils>((ref) {
  return SweUtils(ref.watch(ephemerisRunnerProvider));
});
