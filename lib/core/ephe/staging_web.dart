// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/services.dart' show rootBundle;
import 'package:swisseph_rs/swisseph_rs.dart' show initializeWasm, loadEpheFile;

import '../ephe_assets.dart';
import 'bootstrap.dart';

/// Web half of the staging seam. See `bootstrap.dart`.
///
/// There is no filesystem, so "staging" means loading the WASM module and
/// pushing the bundled `.se1`/`sefstars.txt` bytes into Emscripten's MEMFS
/// at `/ephe`. No managed directory exists on web.
Future<EpheBootstrap> stageEpheSource() async {
  await initializeWasm('swisseph_ffi.js');

  final names = await listEpheAssets();
  if (names.isEmpty) return const EpheBootstrap.none();

  await Future.wait(
    names.map((name) async {
      final data = await rootBundle.load('assets/ephe/$name');
      loadEpheFile(
        name,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }),
  );

  return EpheBootstrap(
    bundledPath: '/ephe',
    managedPath: null,
    webFilenames: names,
  );
}
