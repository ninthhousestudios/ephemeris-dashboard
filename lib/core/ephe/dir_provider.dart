import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../persistence.dart';
import '../swe_service.dart';

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
      : super(EphemerisDirectorySettings(
          useManaged: _prefs.getBool(_kUseManagedKey) ?? true,
          customPath: _prefs.getString(_kCustomPathKey),
        )) {
    _resolveManagedDir();
  }

  final SharedPreferences _prefs;

  Future<void> _resolveManagedDir() async {
    if (kIsWeb) return;
    try {
      final appDir = await getApplicationSupportDirectory();
      final managed = Directory('${appDir.path}/ephe');
      if (!managed.existsSync()) managed.createSync(recursive: true);
      if (mounted) {
        state = state.copyWith(managedPath: managed.path);
      }
    } catch (_) {
      // managedPath stays null; resolver falls back to bundled.
    }
  }

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

final ephemerisDirectoryProvider = StateNotifierProvider<
    EphemerisDirectoryNotifier, EphemerisDirectorySettings>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return EphemerisDirectoryNotifier(prefs);
});

/// The ephe directory that SwissEph should actually read from.
/// Falls back to the bundled path (resolved at startup) when the
/// selected location is unusable.
final resolvedEphePathProvider = Provider<String?>((ref) {
  final settings = ref.watch(ephemerisDirectoryProvider);
  final bundled = bundledEphePath;
  if (settings.useManaged) {
    final managed = settings.managedPath;
    if (managed != null && _hasEpheContent(managed)) return managed;
    return bundled ?? managed;
  }
  final custom = settings.customPath;
  if (custom != null && _hasEpheContent(custom)) return custom;
  return bundled;
});

bool _hasEpheContent(String path) {
  if (kIsWeb) return false;
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) return false;
    return dir
        .listSync()
        .any((e) => e.path.endsWith('.se1') || e.path.endsWith('.eph'));
  } catch (_) {
    return false;
  }
}
