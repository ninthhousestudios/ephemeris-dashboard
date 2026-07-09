// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../persistence.dart';
import '../swe_service.dart';

/// Resolved managed ephe dir (`<appSupport>/ephe`). Populated once by
/// [bootstrapManagedEphe] at startup; null on web or if resolution failed.
String? _managedEphePath;

/// Exposed for the resolver and the notifier.
String? get managedEphePath => _managedEphePath;

/// Resolve `<appSupport>/ephe`, create it if needed, and copy bundled
/// ephemeris files into it the first time we see it empty. Makes the
/// managed dir self-contained so the UI doesn't have to fall back to a
/// read-only bundled directory whose contents can vanish with
/// `flutter clean` (or a fresh install on desktop).
///
/// Call once from `main()` after [initSweEphePath] and before `runApp`.
Future<void> bootstrapManagedEphe() async {
  if (kIsWeb) return;
  try {
    final appDir = await getApplicationSupportDirectory();
    final managed = Directory('${appDir.path}/ephe');
    if (!managed.existsSync()) managed.createSync(recursive: true);

    final bundled = bundledEphePath;
    if (bundled != null && bundled != managed.path) {
      _seedFromBundled(bundled, managed.path);
    }
    _managedEphePath = managed.path;
  } catch (_) {
    // Fall through — resolver will fall back to bundled.
  }
}

void _seedFromBundled(String src, String dst) {
  final srcDir = Directory(src);
  if (!srcDir.existsSync()) return;
  for (final entity in srcDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!_isEpheArtifact(name)) continue;
    final destFile = File('$dst/$name');
    if (destFile.existsSync()) continue;
    try {
      entity.copySync(destFile.path);
    } catch (_) {
      // Best-effort: a single missing/failing file shouldn't abort boot.
    }
  }
}

bool _isEpheArtifact(String name) =>
    name.endsWith('.se1') || name.endsWith('.eph') || name == 'sefstars.txt';

/// Persisted settings for where the C library reads ephemeris files from.
///
/// `useManaged = true` (default) → app's application-support `ephe/` dir.
/// `useManaged = false` → [customPath] (must exist on disk).
/// If the selected location is empty/missing, resolution falls back to the
/// bundled ephe path so the app keeps working out of the box.
class EphemerisDirectorySettings {
  const EphemerisDirectorySettings({
    required this.useManaged,
    this.customPath,
    this.managedPath,
  });

  final bool useManaged;
  final String? customPath;
  final String? managedPath;

  EphemerisDirectorySettings copyWith({
    bool? useManaged,
    Object? customPath = _sentinel,
    Object? managedPath = _sentinel,
  }) {
    return EphemerisDirectorySettings(
      useManaged: useManaged ?? this.useManaged,
      customPath: identical(customPath, _sentinel)
          ? this.customPath
          : customPath as String?,
      managedPath: identical(managedPath, _sentinel)
          ? this.managedPath
          : managedPath as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EphemerisDirectorySettings &&
          useManaged == other.useManaged &&
          customPath == other.customPath &&
          managedPath == other.managedPath;

  @override
  int get hashCode => Object.hash(useManaged, customPath, managedPath);
}

const Object _sentinel = Object();

const _kUseManagedKey = 'ephe.useManaged';
const _kCustomPathKey = 'ephe.customPath';

class EphemerisDirectoryNotifier
    extends StateNotifier<EphemerisDirectorySettings> {
  EphemerisDirectoryNotifier(this._prefs)
    : super(
        EphemerisDirectorySettings(
          useManaged: _prefs.getBool(_kUseManagedKey) ?? true,
          customPath: _prefs.getString(_kCustomPathKey),
          managedPath: managedEphePath,
        ),
      );

  final SharedPreferences _prefs;

  void useManaged() {
    state = state.copyWith(useManaged: true);
    _prefs.setBool(_kUseManagedKey, true);
  }

  void useCustom(String path) {
    state = state.copyWith(useManaged: false, customPath: path);
    _prefs.setBool(_kUseManagedKey, false);
    _prefs.setString(_kCustomPathKey, path);
  }
}

final ephemerisDirectoryProvider =
    StateNotifierProvider<
      EphemerisDirectoryNotifier,
      EphemerisDirectorySettings
    >((ref) {
      final prefs = ref.watch(sharedPrefsProvider);
      return EphemerisDirectoryNotifier(prefs);
    });

/// The ephe directory that SwissEph reads from AND the manager writes to.
/// When useManaged, always returns the managed dir (seeded with the
/// bundled files on first launch via [bootstrapManagedEphe]). Falls back
/// to the bundled path only if bootstrap failed outright.
final resolvedEphePathProvider = Provider<String?>((ref) {
  final settings = ref.watch(ephemerisDirectoryProvider);
  if (settings.useManaged) {
    return settings.managedPath ?? bundledEphePath;
  }
  return settings.customPath ?? bundledEphePath;
});
