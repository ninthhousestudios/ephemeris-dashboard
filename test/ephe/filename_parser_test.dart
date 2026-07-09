// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephe/filename_parser.dart';
import 'package:swe_dashboard/core/ephe/types.dart';

void main() {
  group('parseEpheFilename', () {
    test('AD planets chunk sepl_18.se1 → 1800–2400 CE', () {
      final f = parseEpheFilename('sepl_18.se1', 1300000)!;
      expect(f.family, BodyFamily.planets);
      expect(f.startYear, 1800);
      expect(f.endYear, 2400);
      expect(f.startJd, lessThan(f.endJd));
    });

    test('BCE planets chunk seplm06.se1 → -599–0 (600 BCE–1 BCE)', () {
      final f = parseEpheFilename('seplm06.se1', 1300000)!;
      expect(f.family, BodyFamily.planets);
      expect(f.startYear, -599);
      expect(f.endYear, 0);
    });

    test('Moon chunk semo_18.se1', () {
      final f = parseEpheFilename('semo_18.se1', 1000)!;
      expect(f.family, BodyFamily.moon);
      expect(f.startYear, 1800);
    });

    test('Asteroids chunk seas_18.se1', () {
      final f = parseEpheFilename('seas_18.se1', 1000)!;
      expect(f.family, BodyFamily.mainAsteroids);
    });

    test('JPL file de431.eph', () {
      final f = parseEpheFilename('de431.eph', 1000)!;
      expect(f.family, BodyFamily.jpl);
    });

    test('JPL file with letter suffix de406e.eph', () {
      final f = parseEpheFilename('de406e.eph', 1000)!;
      expect(f.family, BodyFamily.jpl);
    });

    test('Fixed stars catalog sefstars.txt', () {
      final f = parseEpheFilename('sefstars.txt', 500000)!;
      expect(f.family, BodyFamily.fixedStars);
    });

    test('Unknown file readme.txt', () {
      final f = parseEpheFilename('readme.txt', 100)!;
      expect(f.family, BodyFamily.unknown);
    });

    test('sizeBytes is preserved', () {
      final f = parseEpheFilename('sepl_18.se1', 424242)!;
      expect(f.sizeBytes, 424242);
    });
  });
}
