// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Ties `wasmAssetPath` to the `flutter: assets:` declaration it describes.
///
/// The whole point of bundling the wasm artifacts as package assets is that a
/// consumer's glue and Dart loader can no longer disagree about a version. That
/// guarantee rests on one string matching a pubspec entry, and nothing in the
/// Dart type system connects the two: rename or move `wasm/swisseph_ffi.js` and
/// `wasmAssetPath` keeps compiling while every consumer's `initializeWasm()`
/// 404s at runtime, on web only.
///
/// So assert the join here, from the artifacts themselves.
///
/// Reads pubspec.yaml off disk: a packaging assertion, not a runtime one.
@TestOn('vm')
library;

import 'dart:io';

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  final packageName = pubspec['name'] as String;
  final assets = (pubspec['flutter'] as YamlMap?)?['assets'] as YamlList?;

  test('pubspec declares the wasm artifacts as Flutter assets', () {
    expect(
      assets,
      isNotNull,
      reason:
          'the flutter: assets: block is what puts the glue and .wasm into a '
          'consuming build; without it every web consumer is back to vendoring',
    );
    expect(assets, containsAll(<String>['wasm/swisseph_ffi.js']));
  });

  test('wasmAssetPath is where the bundler puts the declared glue', () {
    // Flutter bundles a dependency's assets at their declared package-relative
    // path under assets/packages/<name>/.
    expect(wasmAssetPath, 'assets/packages/$packageName/wasm/swisseph_ffi.js');
  });

  test('every declared asset exists', () {
    for (final asset in assets!.cast<String>()) {
      expect(
        File(asset).existsSync(),
        isTrue,
        reason: '$asset is declared in pubspec.yaml but not present',
      );
    }
  });

  test('the sibling .wasm ships alongside the glue', () {
    // The Emscripten glue resolves its .wasm relative to its own script URL, so
    // the two have to be bundled into the same asset directory. Declaring one
    // without the other yields a glue script that loads and then fails to
    // instantiate.
    expect(assets, contains('wasm/swisseph_ffi.wasm'));
  });
}
