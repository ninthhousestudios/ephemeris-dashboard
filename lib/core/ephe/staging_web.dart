// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/services.dart' show rootBundle;
import 'package:swisseph_rs/swisseph_rs.dart'
    show initializeWasm, loadEpheFile, wasmAssetPath;

import '../ephe_assets.dart';
import 'bootstrap.dart';
import 'filename_parser.dart';
import 'types.dart';

/// Web half of the staging seam. See `bootstrap.dart`.
///
/// There is no filesystem, so "staging" means loading the WASM module and
/// pushing the bundled `.se1`/`sefstars.txt` bytes into Emscripten's MEMFS
/// at `/ephe`. No managed directory exists on web.
///
/// The split between [stageEpheSource] and [progressiveEpheLoad] is what keeps
/// the first frame from waiting on 36 MB of ephemeris data. [stageEpheSource]
/// does only the mandatory part — `initializeWasm`, without which the engine
/// cannot be constructed at all — and returns immediately with nothing loaded
/// (Moshier). [progressiveEpheLoad] then streams the `.se1` files in one at a
/// time, nearest-to-today first, so the app is interactive in ~a WASM download
/// and Swiss Ephemeris for the current era lights up moments later.
Future<EpheBootstrap> stageEpheSource() async {
  await initializeWasm(wasmAssetPath);
  // WASM is up but no files are in MEMFS yet: Moshier mode. The files arrive
  // via progressiveEpheLoad, which the bootstrap notifier subscribes to.
  return const EpheBootstrap.none();
}

/// Stream the bundled ephemeris files into MEMFS one at a time, emitting the
/// growing [EpheBootstrap] after each so the reactive graph (scanner, Context,
/// available sources) recomputes as coverage expands.
///
/// Files load in [_byLoadPriority] order — the fixed-star catalog first, then
/// `.se1` chunks by proximity of their date range to today — so the era a demo
/// user is most likely to look at is available before the deep-past/future
/// chunks finish. Emissions are coalesced (see below) so a full 55-file load
/// does not restart the scan 55 times.
Stream<EpheBootstrap> progressiveEpheLoad() async* {
  final names = await listEpheAssets();
  if (names.isEmpty) return;

  final ordered = _byLoadPriority(names);
  final loaded = <String>[];
  for (var i = 0; i < ordered.length; i++) {
    final name = ordered[i];
    final data = await rootBundle.load('assets/ephe/$name');
    loadEpheFile(
      name,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    loaded.add(name);

    // Emit promptly for the first few files (so Swiss Ephemeris for the
    // current era appears fast), then coalesce to cut scan churn, and always
    // emit the final state.
    final isLast = i == ordered.length - 1;
    if (i < 6 || i % 6 == 5 || isLast) {
      yield EpheBootstrap(
        bundledPath: '/ephe',
        managedPath: null,
        webFilenames: List.unmodifiable(loaded),
      );
    }
  }
}

/// Order bundled ephemeris files by how likely a user is to need them, nearest
/// first: the fixed-star catalog, then `.se1` chunks by the distance of their
/// year range from today (0 when today falls inside the range).
List<String> _byLoadPriority(List<String> names) {
  // Kept in sync with the app's demo focus rather than wired to DateTime.now()
  // so the load order is deterministic and testable.
  const nowYear = 2026;

  int priority(String name) {
    final file = parseEpheFilename(name, 0);
    if (file == null) return 1 << 30; // unrecognized: last
    if (file.family == BodyFamily.fixedStars) return -1; // small, broadly used
    if (file.startYear == 0 && file.endYear == 0) return 1 << 29; // no range
    if (nowYear >= file.startYear && nowYear <= file.endYear) return 0;
    return nowYear < file.startYear
        ? file.startYear - nowYear
        : nowYear - file.endYear;
  }

  return [...names]..sort((a, b) => priority(a).compareTo(priority(b)));
}
