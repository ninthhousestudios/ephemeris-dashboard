// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';
import 'dart:io';

import 'atlas_catalog.dart';

/// Return the gunzipped TSV of the highest-coverage atlas tier installed under
/// `<epheDir>/atlas/`, or null if none is present.
///
/// [atlasReleases] is ordered highest-coverage first, so the first hit is the
/// biggest installed tier — the superset chain means it fully supersedes any
/// smaller tier and the bundle.
Future<String?> loadInstalledAtlasTsv(String epheDir) async {
  for (final release in atlasReleases) {
    final file = File('$epheDir/$atlasSubdir/${release.filename}');
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      return utf8.decode(gzip.decode(bytes));
    }
  }
  return null;
}
