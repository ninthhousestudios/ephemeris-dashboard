// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../persistence.dart';
import 'bootstrap.dart';

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
  EphemerisDirectoryNotifier(this._prefs, EpheBootstrap bootstrap)
    : super(
        EphemerisDirectorySettings(
          useManaged: _prefs.getBool(_kUseManagedKey) ?? true,
          customPath: _prefs.getString(_kCustomPathKey),
          managedPath: bootstrap.managedPath,
        ),
      );

  final SharedPreferences _prefs;

  void useManaged() {
    state = state.copyWith(useManaged: true);
    _prefs.setBool(_kUseManagedKey, true);
  }

  void useCustom(String path) {
    state = state.copyWith(useManaged: false, customPath: path);
    _prefs
      ..setBool(_kUseManagedKey, false)
      ..setString(_kCustomPathKey, path);
  }
}

final ephemerisDirectoryProvider =
    StateNotifierProvider<
      EphemerisDirectoryNotifier,
      EphemerisDirectorySettings
    >((ref) {
      final prefs = ref.watch(sharedPrefsProvider);
      return EphemerisDirectoryNotifier(
        prefs,
        ref.watch(epheBootstrapProvider),
      );
    });

/// The ephe directory that SwissEph reads from AND the manager writes to.
/// When useManaged, always returns the managed dir (seeded with the
/// bundled files on first launch via [bootstrapEpheSource]). Falls back
/// to the bundled path only if bootstrap failed outright.
final resolvedEphePathProvider = Provider<String?>((ref) {
  final settings = ref.watch(ephemerisDirectoryProvider);
  final bundled = ref.watch(epheBootstrapProvider).bundledPath;
  if (settings.useManaged) {
    return settings.managedPath ?? bundled;
  }
  return settings.customPath ?? bundled;
});
