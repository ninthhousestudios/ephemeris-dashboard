// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    hierarchicalLoggingEnabled = true;
    final logger = Logger('swisseph_rs_build')
      ..level = Level.ALL
      ..onRecord.listen(
        (record) => print('${record.level.name}: ${record.message}'),
      );

    final rustDir = '${input.packageRoot.toFilePath()}rust';
    logger.info('Rust shim crate: $rustDir');

    final code = input.config.code;
    final targetOS = code.targetOS;
    final targetArch = code.targetArchitecture;
    final crossTarget = _rustTarget(targetOS, targetArch, code);

    if (crossTarget != null) {
      _ensureRustTarget(crossTarget);
    }

    final cargoArgs = [
      'build',
      '--release',
      '--manifest-path',
      '$rustDir/Cargo.toml',
      if (crossTarget != null) ...['--target', crossTarget],
    ];

    final env = <String, String>{};
    if (targetOS == OS.android) {
      _configureAndroidLinker(crossTarget!, code.android.targetNdkApi, env);
    }

    logger.info('cargo ${cargoArgs.join(' ')}');
    if (env.isNotEmpty) {
      logger.info('env: ${env.keys.join(', ')}');
    }

    final result = await Process.run(
      _rustTool('cargo'),
      cargoArgs,
      environment: env.isNotEmpty ? env : null,
    );

    if (result.exitCode != 0) {
      logger.severe('cargo build failed:\n${result.stderr}');
      throw Exception('cargo build failed with exit code ${result.exitCode}');
    }
    logger.info('cargo build succeeded');

    final dylibName = targetOS.dylibFileName('swisseph_rs_dart');
    final releaseDir = crossTarget != null
        ? '$rustDir/target/$crossTarget/release'
        : '$rustDir/target/release';
    final dylibPath = '$releaseDir/$dylibName';
    final dylibFile = File(dylibPath);
    if (!dylibFile.existsSync()) {
      throw Exception('Expected dylib not found: $dylibPath');
    }

    final outDir = input.outputDirectory;
    final outFile = File('${outDir.toFilePath()}$dylibName');
    dylibFile.copySync(outFile.path);
    logger.info('Copied $dylibPath -> ${outFile.path}');

    output.assets.code.add(
      CodeAsset(
        package: 'swisseph_rs',
        name: 'swisseph_rs.dart',
        linkMode: DynamicLoadingBundled(),
        file: outFile.uri,
      ),
    );

    output.dependencies.add(Directory(rustDir).uri);
  });
}

String? _rustTarget(OS os, Architecture arch, CodeConfig code) {
  if (os == OS.android) {
    return switch (arch) {
      Architecture.arm64 => 'aarch64-linux-android',
      Architecture.arm => 'armv7-linux-androideabi',
      Architecture.x64 => 'x86_64-linux-android',
      Architecture.ia32 => 'i686-linux-android',
      _ => throw UnsupportedError('Unsupported Android architecture: $arch'),
    };
  }
  if (os == OS.iOS) {
    final sdk = code.iOS.targetSdk;
    if (arch == Architecture.arm64 && sdk == IOSSdk.iPhoneOS) {
      return 'aarch64-apple-ios';
    }
    if (arch == Architecture.arm64 && sdk == IOSSdk.iPhoneSimulator) {
      return 'aarch64-apple-ios-sim';
    }
    if (arch == Architecture.x64) {
      return 'x86_64-apple-ios';
    }
    throw UnsupportedError('Unsupported iOS target: $arch / $sdk');
  }
  if (os == OS.macOS) {
    return switch (arch) {
      Architecture.arm64 => 'aarch64-apple-darwin',
      Architecture.x64 => 'x86_64-apple-darwin',
      _ => throw UnsupportedError('Unsupported macOS architecture: $arch'),
    };
  }
  return null;
}

void _configureAndroidLinker(
  String target,
  int apiLevel,
  Map<String, String> env,
) {
  final ndkPath = _findNdk();
  final hostTag = Platform.isLinux
      ? 'linux-x86_64'
      : Platform.isMacOS
      ? 'darwin-x86_64'
      : throw UnsupportedError(
          'Android cross-compilation not supported on ${Platform.operatingSystem}',
        );

  // NDK clang wrappers use a different arch prefix for armv7
  final clangPrefix = switch (target) {
    'aarch64-linux-android' => 'aarch64-linux-android',
    'armv7-linux-androideabi' => 'armv7a-linux-androideabi',
    'x86_64-linux-android' => 'x86_64-linux-android',
    'i686-linux-android' => 'i686-linux-android',
    _ => throw StateError('Unknown Android target: $target'),
  };

  final binDir = '$ndkPath/toolchains/llvm/prebuilt/$hostTag/bin';
  final clang = '$binDir/$clangPrefix$apiLevel-clang';
  if (!File(clang).existsSync()) {
    throw Exception(
      'NDK clang not found at $clang\n'
      'Ensure the Android NDK is installed and supports API level $apiLevel.',
    );
  }

  final envKey =
      'CARGO_TARGET_${target.toUpperCase().replaceAll('-', '_')}_LINKER';
  env[envKey] = clang;
}

String _findNdk() {
  final ndkHome = Platform.environment['ANDROID_NDK_HOME'];
  if (ndkHome != null && Directory(ndkHome).existsSync()) return ndkHome;

  final androidHome =
      Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'];
  if (androidHome == null) {
    throw Exception(
      'Cannot find Android NDK.\n'
      'Set ANDROID_HOME, ANDROID_SDK_ROOT, or ANDROID_NDK_HOME.',
    );
  }

  final ndkDir = Directory('$androidHome/ndk');
  if (!ndkDir.existsSync()) {
    throw Exception('No NDK directory found at ${ndkDir.path}');
  }

  final versions =
      ndkDir
          .listSync()
          .whereType<Directory>()
          .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
          .toList()
        ..sort();
  if (versions.isEmpty) {
    throw Exception('No NDK versions installed in ${ndkDir.path}');
  }
  return '${ndkDir.path}/${versions.last}';
}

void _ensureRustTarget(String target) {
  final result = Process.runSync(_rustTool('rustup'), [
    'target',
    'list',
    '--installed',
  ]);
  if (result.exitCode != 0) {
    throw Exception('Failed to query installed Rust targets via rustup.');
  }
  final installed = (result.stdout as String)
      .split('\n')
      .map((l) => l.trim())
      .toSet();
  if (!installed.contains(target)) {
    throw Exception(
      'Rust target "$target" is not installed.\n'
      'Run: rustup target add $target',
    );
  }
}

String _rustTool(String name) {
  final home = Platform.environment['HOME'];
  if (home != null) {
    final tool = File('$home/.cargo/bin/$name');
    if (tool.existsSync()) return tool.path;
  }
  return name;
}
