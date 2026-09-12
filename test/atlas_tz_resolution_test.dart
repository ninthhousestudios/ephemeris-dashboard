// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Every IANA zone the bundled atlas can hand to the Context must resolve
/// against the initialized tzdata (swe-dashboard/113 TZ-001).
///
/// The atlas carries GeoNames zone ids including link/alias zones (Europe/
/// Amsterdam, Africa/Accra, Pacific/Chuuk, …) that the `latest` tz database
/// dropped — selecting such a city then silently kept the previous offset
/// behind an unresolved link. This pins the `latest_all` database against the
/// actual atlas contents, so a future atlas or database swap can't reintroduce
/// a zone the app can carry but not resolve.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/timezone_offset.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(ensureTimeZonesInitialized);

  test('every distinct atlas time zone resolves against tzdata', () {
    // Column layout matches InMemoryAtlas.parse: f[6] is the IANA zone.
    final tsv = File('assets/atlas/cities.tsv').readAsStringSync();
    final zones = <String>{};
    for (final line in tsv.split('\n')) {
      if (line.isEmpty) continue;
      final f = line.split('\t');
      if (f.length < 7) continue;
      zones.add(f[6]);
    }
    expect(zones, isNotEmpty, reason: 'the atlas must carry zone ids');

    final unresolved = <String>[];
    for (final z in zones) {
      try {
        tz.getLocation(z);
      } catch (_) {
        unresolved.add(z);
      }
    }
    expect(
      unresolved,
      isEmpty,
      reason:
          'these atlas zones do not resolve; the tz database is missing them '
          '(switch to a fuller database or canonicalize the atlas): $unresolved',
    );
  });
}
