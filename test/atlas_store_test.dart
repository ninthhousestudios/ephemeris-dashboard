// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/atlas/atlas_catalog.dart';
import 'package:swe_dashboard/core/atlas/atlas_store.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('atlas_store_test_');
    Directory('${tmp.path}/$atlasSubdir').createSync(recursive: true);
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  void writeTier(AtlasRelease r, String tsv) {
    final gz = gzip.encode(utf8.encode(tsv));
    File('${tmp.path}/$atlasSubdir/${r.filename}').writeAsBytesSync(gz);
  }

  // Highest-coverage first, so index 0 is the biggest tier, last is smallest.
  final biggest = atlasReleases.first;
  final smallest = atlasReleases.last;

  test('returns null when no tier is installed', () async {
    expect(await loadInstalledAtlasTsv(tmp.path), isNull);
  });

  test('gunzips the installed tier', () async {
    const tsv =
        'Paris\tÎle-de-France\tFrance\t48.85\t2.35\t2138551\tEurope/Paris';
    writeTier(smallest, tsv);
    expect(await loadInstalledAtlasTsv(tmp.path), tsv);
  });

  test('biggest installed tier wins when several are present', () async {
    writeTier(smallest, 'SMALL');
    writeTier(biggest, 'BIG');
    expect(await loadInstalledAtlasTsv(tmp.path), 'BIG');
  });
}
