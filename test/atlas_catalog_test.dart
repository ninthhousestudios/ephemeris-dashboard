// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/atlas/atlas_catalog.dart';

void main() {
  test('releases are ordered highest-coverage first', () {
    // The loader picks the first installed tier, so the biggest (most cities)
    // must come first for "biggest installed wins" to hold.
    for (var i = 1; i < atlasReleases.length; i++) {
      expect(
        atlasReleases[i - 1].approxCities,
        greaterThan(atlasReleases[i].approxCities),
        reason: 'atlasReleases must descend by approxCities',
      );
    }
  });

  test('every release pins an md5 and a positive size', () {
    for (final r in atlasReleases) {
      expect(r.md5, isNotEmpty);
      expect(r.sizeBytes, greaterThan(0));
      expect(r.url, startsWith('https://'));
      expect(r.filename, endsWith('.tsv.gz'));
    }
  });

  test('filenames and urls are unique', () {
    expect(
      atlasReleases.map((r) => r.filename).toSet().length,
      atlasReleases.length,
    );
    expect(
      atlasReleases.map((r) => r.url).toSet().length,
      atlasReleases.length,
    );
  });

  test('toDownloadSpec lands in the atlas subdir and pins the hash', () {
    final r = atlasReleases.first;
    final spec = r.toDownloadSpec();
    expect(spec.subdir, atlasSubdir);
    expect(spec.filename, r.filename);
    expect(spec.url, r.url);
    expect(spec.md5, r.md5);
    expect(spec.sizeBytes, r.sizeBytes);
    // md5 is pinned, so the ephe payload sniff must stay off.
    expect(spec.sniffEphePayload, isFalse);
  });
}
