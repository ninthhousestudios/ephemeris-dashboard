// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/services.dart' show StandardMessageCodec, rootBundle;
import 'package:swisseph_rs/swisseph_rs.dart' show initializeWasm, loadEpheFile;

/// Initialize ephemeris path stub — not used on web.
Future<String?> initNativeEphePath() =>
    throw UnsupportedError('Not available on web');

/// Load the swisseph_rs WASM module for web.
Future<void> initWasm() => initializeWasm('swisseph_ffi.js');

/// Load bundled .se1/sefstars.txt from Flutter assets into Emscripten MEMFS.
/// Returns the MEMFS path ('/ephe') on success, null if no files found.
Future<String?> loadBundledEpheFiles() async {
  final names = await _listEpheAssets();
  if (names.isEmpty) return null;
  await Future.wait(
    names.map((name) async {
      final data = await rootBundle.load('assets/ephe/$name');
      loadEpheFile(
        name,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }),
  );
  return '/ephe';
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
    return const [];
  }
}
