// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/services.dart' show StandardMessageCodec, rootBundle;

/// Filenames of the ephemeris files bundled under `assets/ephe/`.
///
/// Reads the asset manifest, so it needs nothing but `flutter/services` and
/// works on every platform (native and web share this). [fallback] is returned
/// when the manifest cannot be read at all — native builds pass the shipped
/// file list there so a missing manifest does not look like an empty bundle.
Future<List<String>> listEpheAssets({List<String> fallback = const []}) async {
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
    return fallback;
  }
}

/// The ephemeris files this app ships under `assets/ephe/`, used as the
/// fallback when the asset manifest is unreadable.
List<String> bundledEpheFileNames() {
  final files = ['sefstars.txt'];
  for (final n in ['00', '06', '12', '18', '24', '30', '36', '42', '48']) {
    files.addAll(['seas_$n.se1', 'semo_$n.se1', 'sepl_$n.se1']);
  }
  for (final n in ['06', '12', '18', '24', '30', '36', '42', '48', '54']) {
    files.addAll(['seasm$n.se1', 'semom$n.se1', 'seplm$n.se1']);
  }
  return files;
}
