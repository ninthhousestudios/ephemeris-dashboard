import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import 'ephe/dir_provider.dart';

// Conditional dart:io import — only used when !kIsWeb.
import 'swe_service_io.dart'
    if (dart.library.js_interop) 'swe_service_stub.dart' as io;

/// Resolved once at startup; null on web (Moshier mode, no files needed).
String? _ephePath;

/// Loaded once at startup on mobile/web; null on desktop (created synchronously).
SwissEph? _preloadedSwe;

/// Call once from main() before runApp(). Resolves or extracts the
/// ephemeris data files (.se1 + sefstars.txt) to a filesystem directory
/// that the C library can read.
///
/// - **Web:** loads WASM module, uses Moshier mode (no ephe files).
/// - **Linux/macOS/Windows desktop:** checks release bundle, then dev-mode
///   .dart_tool/package_config.json.
/// - **Android/iOS:** copies bundled assets/ephe/ to the app's support
///   directory on first launch (skips if already present).
Future<void> initSweEphePath() async {
  // --- Web: WASM + Moshier mode (no filesystem) ---
  if (kIsWeb) {
    _preloadedSwe = await SwissEph.load();
    return;
  }

  // --- Native platforms (dart:io available) ---
  final result = await io.initNativeEphePath();
  _ephePath = result.ephePath;
  _preloadedSwe = result.swe;
}

/// Whether .se1 ephemeris files were found at startup.
bool get hasEpheFiles => _ephePath != null;

/// Bundled ephe path resolved at startup (null on web / when nothing found).
/// Consumers (e.g. resolvedEphePathProvider) use this as a fallback when
/// a user-selected dir is empty or missing.
String? get bundledEphePath => _ephePath;

/// The SwissEph instance — built once, disposed with the ProviderScope.
/// Does NOT call setEphePath; that is done by ephePathApplyProvider so the
/// instance survives directory changes.
final sweProvider = Provider<SwissEph>((ref) {
  final swe = _preloadedSwe ?? io.createDesktopSwissEph();
  ref.onDispose(() => swe.close());
  return swe;
});

/// Imperatively applies the currently-resolved ephe path onto the shared
/// SwissEph instance. Watched by the scanner and any provider that should
/// invalidate when the user switches directories. Must be `ref.read` once
/// at app start (see AppShell) so the initial path is set before any calc.
///
/// IMPORTANT: this Provider has a deliberate side effect in its build
/// callback. Riverpod nominally expects build() to be pure, but rewriting
/// this as a listener on a holder notifier would plumb the `SwissEph`
/// instance through an init callback for no observable behavior change.
/// The side effect is idempotent (`setEphePath` is cheap and safe to call
/// repeatedly), and the provider is `ref.read` once in `AppShell.initState`
/// which keeps it alive for the rest of the session. If you tree-shake
/// that `ref.read` call or convert this to a pure provider, `setEphePath`
/// will stop firing on directory changes and you'll get stale C state.
final ephePathApplyProvider = Provider<String?>((ref) {
  final swe = ref.watch(sweProvider);
  final path = ref.watch(resolvedEphePathProvider);
  if (path != null) swe.setEphePath(path);
  return path;
});
