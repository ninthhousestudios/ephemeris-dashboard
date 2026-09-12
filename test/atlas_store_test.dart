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

  // Write non-gzip garbage under a tier's name — stands in for a truncated or
  // corrupted download that slipped past the download-time md5 check.
  void writeCorruptTier(AtlasRelease r) {
    File(
      '${tmp.path}/$atlasSubdir/${r.filename}',
    ).writeAsBytesSync([0, 1, 2, 3, 4, 5]);
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

  test(
    'corrupt highest tier falls through to the next installed tier',
    () async {
      writeCorruptTier(biggest);
      writeTier(smallest, 'SMALL');
      expect(await loadInstalledAtlasTsv(tmp.path), 'SMALL');
    },
  );

  test(
    'corrupt sole tier returns null (caller falls back to the bundle)',
    () async {
      writeCorruptTier(biggest);
      expect(await loadInstalledAtlasTsv(tmp.path), isNull);
    },
  );
}
