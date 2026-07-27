// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../ephe_assets.dart';
import 'bootstrap.dart';
import 'probes.dart';
import 'types.dart';

/// Native half of the staging seam. See `bootstrap.dart`.
Future<EpheBootstrap> stageEpheSource() async {
  final bundled = await _runProbes(nativeEpheProbes(currentPlatformFacts()));
  final managed = await _resolveManagedDir(bundled);
  return EpheBootstrap(
    bundledPath: bundled,
    managedPath: managed,
    webFilenames: const [],
  );
}

/// The real platform, read once. Everything downstream takes these as data.
PlatformFacts currentPlatformFacts() => (
  isMacOS: Platform.isMacOS,
  isLinux: Platform.isLinux,
  isWindows: Platform.isWindows,
  isAndroid: Platform.isAndroid,
  isIOS: Platform.isIOS,
  exeDir: File(Platform.resolvedExecutable).parent.path,
  cwd: Directory.current.path,
);

/// Walk the plan and take the first probe that yields a directory holding at
/// least one `.se1` file. Returns null when every probe comes up empty —
/// the Moshier case.
Future<String?> _runProbes(List<EpheProbe> probes) async {
  for (final probe in probes) {
    final String? path;
    try {
      path = await _execute(probe);
    } catch (_) {
      // A probe that blows up (unreadable dir, malformed package config,
      // asset extraction denied) is a probe that did not find anything.
      continue;
    }
    if (path != null && isValidEpheDir(path)) return path;
  }
  return null;
}

Future<String?> _execute(EpheProbe probe) async => switch (probe) {
  DirectoryProbe(:final path) => path,
  PackageConfigProbe() => _swissephRsEpheDir(),
  AssetExtractionProbe() => await _extractBundledAssets(),
};

/// A directory counts as an ephemeris directory when it holds at least one
/// `.se1` file. Exposed so probe execution can be exercised against temp
/// dirs in tests.
bool isValidEpheDir(String path) {
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) return false;
    return dir.listSync().any((e) => e.path.endsWith('.se1'));
  } catch (_) {
    return false;
  }
}

/// Locate `swisseph_rs`'s own `ephe/` directory via the package config.
String? _swissephRsEpheDir() {
  final configPath = _findPackageConfig();
  if (configPath == null) return null;

  final config =
      jsonDecode(File(configPath).readAsStringSync()) as Map<String, dynamic>;
  final packages = config['packages'] as List<dynamic>;
  for (final pkg in packages) {
    if (pkg is! Map<String, dynamic> || pkg['name'] != 'swisseph_rs') continue;
    var pkgRoot = Uri.parse(pkg['rootUri'] as String).toFilePath();
    if (!pkgRoot.endsWith('/')) pkgRoot = '$pkgRoot/';
    return '${pkgRoot}ephe';
  }
  return null;
}

/// Find `.dart_tool/package_config.json` from the CWD, or by walking up from
/// the executable (macOS dev mode buries the exe deep under `build/`).
String? _findPackageConfig() {
  final cwdConfig = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  if (cwdConfig.existsSync()) return cwdConfig.path;

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

/// Copy `assets/ephe/` into `<appSupport>/ephe`, skipping the copy when a
/// matching `.version` marker says it is already current.
Future<String?> _extractBundledAssets() async {
  final appDir = await getApplicationSupportDirectory();
  final epheDir = Directory('${appDir.path}/ephe');
  final versionFile = File('${epheDir.path}/.version');

  final needsExtract =
      !isValidEpheDir(epheDir.path) ||
      !versionFile.existsSync() ||
      versionFile.readAsStringSync().trim() != epheAssetVersion;

  if (needsExtract) {
    await epheDir.create(recursive: true);
    final names = await listEpheAssets(fallback: bundledEpheFileNames());
    for (final name in names) {
      final data = await rootBundle.load('assets/ephe/$name');
      await File('${epheDir.path}/$name').writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    await versionFile.writeAsString(epheAssetVersion, flush: true);
  }

  return epheDir.path;
}

/// Resolve `<appSupport>/ephe`, create it if needed, and seed it from
/// [bundled] the first time we see it empty.
///
/// The managed dir has to be self-contained: the UI writes downloads into it,
/// and a read-only bundled directory's contents can vanish with
/// `flutter clean` or a fresh install.
Future<String?> _resolveManagedDir(String? bundled) async {
  try {
    final appDir = await getApplicationSupportDirectory();
    final managed = Directory('${appDir.path}/ephe');
    if (!managed.existsSync()) managed.createSync(recursive: true);

    // On mobile and macOS the asset-extraction probe already staged into
    // this exact directory, so there is nothing to seed.
    if (bundled != null && bundled != managed.path) {
      _seedFrom(bundled, managed.path);
    }
    return managed.path;
  } catch (_) {
    // Fall through — the resolver falls back to the bundled path.
    return null;
  }
}

void _seedFrom(String src, String dst) {
  final srcDir = Directory(src);
  if (!srcDir.existsSync()) return;
  for (final entity in srcDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!isEpheArtifact(name)) continue;
    final destFile = File('$dst/$name');
    if (destFile.existsSync()) continue;
    try {
      entity.copySync(destFile.path);
    } catch (_) {
      // Best-effort: one failing file shouldn't abort boot.
    }
  }
}
