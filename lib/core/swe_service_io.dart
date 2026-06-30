import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show StandardMessageCodec, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:swisseph/swisseph.dart';

/// Result of native ephemeris path initialization.
class NativeInitResult {
  final String? ephePath;
  final SwissEph? swe;
  const NativeInitResult({this.ephePath, this.swe});
}

/// Initialize ephemeris path and optionally preload SwissEph on native platforms.
Future<NativeInitResult> initNativeEphePath() async {
  // --- Desktop release build: ephe/ near the executable ---
  // macOS skipped here — it extracts to app support dir instead so .se1
  // files live outside the signed app bundle (codesign rejects them).
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  if (!Platform.isMacOS) {
    for (final candidate in [
      '$exeDir/data/ephe', // CMake-installed bundle
      '$exeDir/data/flutter_assets/assets/ephe', // Flutter asset bundle
    ]) {
      if (_isValidEpheDir(candidate)) {
        return NativeInitResult(ephePath: candidate);
      }
    }
  }

  // --- Desktop dev mode: find swisseph package in pub cache ---
  // macOS skipped — it uses the asset-extraction path below (app sandbox
  // blocks access to CWD/.dart_tool/ anyway).
  if (Platform.isLinux || Platform.isWindows) {
    final pkgConfigPath = _findPackageConfig();
    if (pkgConfigPath != null) {
      final config =
          jsonDecode(File(pkgConfigPath).readAsStringSync())
              as Map<String, dynamic>;
      final packages = config['packages'] as List<dynamic>;
      for (final pkg in packages) {
        if (pkg['name'] == 'swisseph') {
          final rootUri = pkg['rootUri'] as String;
          var pkgRoot = Uri.parse(rootUri).toFilePath();
          if (!pkgRoot.endsWith('/')) pkgRoot = '$pkgRoot/';
          final epheDir = '${pkgRoot}ephe';
          if (_isValidEpheDir(epheDir)) {
            return NativeInitResult(ephePath: epheDir);
          }
        }
      }
    }
  }

  // --- Mobile + macOS: extract assets to app support directory ---
  // macOS included here so .se1 files live outside the signed app bundle.
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    final appDir = await getApplicationSupportDirectory();
    final epheDir = Directory('${appDir.path}/ephe');

    // Re-extract if directory is missing, empty, or from a different version.
    const epheVersion = '0.4.3'; // bump when swisseph dependency changes
    final versionFile = File('${epheDir.path}/.version');
    final needsExtract =
        !_isValidEpheDir(epheDir.path) ||
        !versionFile.existsSync() ||
        versionFile.readAsStringSync().trim() != epheVersion;

    if (needsExtract) {
      await epheDir.create(recursive: true);
      final epheFiles = await _listEpheAssets();

      for (final fileName in epheFiles) {
        final data = await rootBundle.load('assets/ephe/$fileName');
        final outFile = File('${epheDir.path}/$fileName');
        await outFile.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
      await versionFile.writeAsString(epheVersion, flush: true);
    }

    final swe = _loadNativeLibrary();
    return NativeInitResult(ephePath: epheDir.path, swe: swe);
  }

  // No ephe files found — Moshier analytical ephemeris will be used.
  return const NativeInitResult();
}

/// Create a SwissEph instance for desktop (release bundle or dev mode).
SwissEph createDesktopSwissEph() {
  return _loadNativeLibrary();
}

/// Load the Swiss Ephemeris native library, searching all known locations.
///
/// Search order:
/// 1. Release bundle paths (exe-relative: lib/, Frameworks/, etc.)
/// 2. App bundle Frameworks directory (iOS/macOS)
/// 3. Native assets embedded library (bare name via dlopen)
/// 4. SwissEph.find() — walks CWD/.dart_tool/
/// 5. Project .dart_tool/ found via package_config.json or exe path walk
SwissEph _loadNativeLibrary() {
  final exeDir = File(Platform.resolvedExecutable).parent.path;

  // --- Release bundle paths ---
  final candidates = [
    '$exeDir/lib/libswisseph.so', // Linux release
    '$exeDir/lib/libswisseph.dylib', // macOS non-bundle
    '$exeDir/../Frameworks/libswisseph.dylib', // macOS .app bundle (native assets)
    '$exeDir/Frameworks/libswisseph.dylib', // iOS .app bundle (native assets)
    '$exeDir/swisseph.dll', // Windows release
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return SwissEph(path);
  }

  // --- Android: load by soname from APK ---
  if (Platform.isAndroid) return SwissEph('libswisseph.so');

  // --- CocoaPods dynamic framework (use_frameworks! in Podfile) ---
  // On iOS/macOS, dlopen recognizes the framework path pattern and searches
  // @rpath (which includes @executable_path/Frameworks for app bundles).
  if (Platform.isIOS || Platform.isMacOS) {
    try {
      return SwissEph('swisseph_native.framework/swisseph_native');
    } catch (_) {}
  }

  // --- Try bare library name (works if native assets embedded it) ---
  final bareName = Platform.isWindows
      ? 'swisseph.dll'
      : Platform.isLinux
      ? 'libswisseph.so'
      : 'libswisseph.dylib';
  try {
    return SwissEph(bareName);
  } catch (_) {}

  // --- SwissEph.find() walks CWD/.dart_tool/ ---
  try {
    return SwissEph.find();
  } catch (_) {}

  // --- Dev mode: find .dart_tool/ via package_config.json or exe walk ---
  final libPath = _findLibraryInDartTool();
  if (libPath != null) return SwissEph(libPath);

  throw StateError(
    'libswisseph not found. Ensure native assets are enabled '
    '(flutter config --enable-native-assets) and run flutter pub get.',
  );
}

/// Find .dart_tool/package_config.json from CWD or by walking up from exe.
String? _findPackageConfig() {
  // Try CWD first (works on Linux desktop dev mode).
  final cwdConfig = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  if (cwdConfig.existsSync()) return cwdConfig.path;

  // Walk up from executable to find project root (macOS dev mode:
  // exe is at <project>/build/macos/Build/Products/Debug/Runner.app/Contents/MacOS/Runner).
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 12; i++) {
    final candidate = File('${dir.path}/.dart_tool/package_config.json');
    if (candidate.existsSync()) return candidate.path;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

/// Search .dart_tool/ (found via package_config.json or exe walk) for the
/// compiled native library.
String? _findLibraryInDartTool() {
  final pkgConfig = _findPackageConfig();
  if (pkgConfig == null) return null;

  // .dart_tool/package_config.json → .dart_tool/
  final dartToolDir = File(pkgConfig).parent;
  if (!dartToolDir.existsSync()) return null;

  final libNames = ['libswisseph.so', 'libswisseph.dylib', 'swisseph.dll'];
  try {
    for (final entity in dartToolDir.listSync(recursive: true)) {
      if (entity is File &&
          libNames.any((name) => entity.path.endsWith(name))) {
        return entity.path;
      }
    }
  } catch (_) {
    // Permission or I/O errors — skip.
  }
  return null;
}

bool _isValidEpheDir(String path) {
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) return false;
    return dir.listSync().any((e) => e.path.endsWith('.se1'));
  } catch (_) {
    return false;
  }
}

Future<List<String>> _listEpheAssets() async {
  try {
    final manifestBytes = await rootBundle.load('AssetManifest.bin');
    final manifest =
        const StandardMessageCodec().decodeMessage(manifestBytes)
            as Map<Object?, Object?>;
    return manifest.keys
        .map((k) => k.toString())
        .where((k) => k.startsWith('assets/ephe/'))
        .map((k) => k.split('/').last)
        .toList();
  } catch (_) {
    final files = ['sefstars.txt'];
    for (final n in ['00', '06', '12', '18', '24', '30', '36', '42', '48']) {
      files.addAll(['seas_$n.se1', 'semo_$n.se1', 'sepl_$n.se1']);
    }
    for (final n in ['06', '12', '18', '24', '30', '36', '42', '48', '54']) {
      files.addAll(['seasm$n.se1', 'semom$n.se1', 'seplm$n.se1']);
    }
    return files;
  }
}
