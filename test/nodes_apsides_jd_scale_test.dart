// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// The perihelion passage is the one Julian Day this app reports that does not
/// start on UT1: `getOrbitalElements` takes `jdEt`, so it answers on ET/TT.
///
/// That makes it the field where a scale conversion is easiest to get exactly
/// backwards — a wrong direction is a ~2ΔT error that still looks like a
/// plausible Julian Day. These pin the direction and the label together.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/core/time_scale.dart';
import 'package:swe_dashboard/tabs/nodes_apsides/nodes_apsides_provider.dart';

void main() {
  group('perihelionPassageField', () {
    SweUtils? swe;

    setUp(() {
      try {
        swe = SweUtils(EphemerisRunner());
      } catch (_) {
        // Native library not available on this platform.
      }
    });

    // A perihelion passage as the engine reports it: already on ET/TT.
    const jdEt = 2451545.0;

    test('TT is the engine value untouched, and says so', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final (label, value) = perihelionPassageField(jdEt, swe!, TimeScale.tt);
      expect(label, 'Perihelion Passage (JD TT)');
      expect(double.parse(value), jdEt);
    });

    test('UT1 steps down by ΔT, not up', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final (label, value) = perihelionPassageField(jdEt, swe!, TimeScale.ut1);
      expect(label, 'Perihelion Passage (JD UT1)');
      // ΔT at J2000 is ~64 s. Below the ET value — the direction is the whole
      // point, so assert the sign before the magnitude.
      final shown = double.parse(value);
      expect(shown, lessThan(jdEt));
      expect(shown, closeTo(jdEt - 64 / 86400, 1e-5));
    });

    test('UTC follows UT1, since a JD has no UTC numbering', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final (label, value) = perihelionPassageField(jdEt, swe!, TimeScale.utc);
      expect(label, 'Perihelion Passage (JD UT1)');
      expect(double.parse(value), lessThan(jdEt));
    });

    test('the scale actually changes the number across the three settings', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      // The defect this fixes was a card that ignored the Scale entirely, so
      // pin that the value moves rather than only that the label does.
      final values = [
        for (final s in TimeScale.values)
          double.parse(perihelionPassageField(jdEt, swe!, s).$2),
      ];
      expect(values.toSet(), hasLength(2), reason: 'UTC and UT1 coincide');
      expect(values.any((v) => v != jdEt), isTrue);
    });
  });
}
