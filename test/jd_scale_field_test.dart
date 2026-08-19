// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// [jdScaleField] renders a bare Julian Day on the Context's Scale, the shared
/// source behind the Crossings, Eclipses and Rise/Set cards and exports. The
/// defect it fixes was a card that showed a fixed UT1 number while the Scale
/// toggle moved everything beside it — so these pin that the number *moves* with
/// the scale, not only that the label does.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/jd_utils.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/core/time_scale.dart';

void main() {
  group('jdScaleField', () {
    SweUtils? swe;

    setUp(() {
      try {
        swe = SweUtils(EphemerisRunner());
      } catch (_) {
        // Native library not available on this platform.
      }
    });

    // A crossing/eclipse/rise time as the engine reports it: on UT1.
    const jdUt = 2451545.0;

    test('UT1 is the engine value untouched, and says so', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final f = jdScaleField(swe!, jdUt, scale: TimeScale.ut1);
      expect(f.label, 'JD (UT1)');
      expect(double.parse(f.value), jdUt);
      expect(f.onScale, jdUt);
    });

    test('TT steps up by ΔT, not down', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final f = jdScaleField(swe!, jdUt, scale: TimeScale.tt);
      expect(f.label, 'JD (TT)');
      // ΔT at J2000 is ~64 s. A UT1 instant on the TT scale is *later* — the
      // direction is the whole point, so assert the sign before the magnitude.
      expect(f.onScale, greaterThan(jdUt));
      expect(f.onScale, closeTo(jdUt + 64 / 86400, 1e-5));
    });

    test('UTC follows UT1, since a JD has no UTC numbering', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final f = jdScaleField(swe!, jdUt, scale: TimeScale.utc);
      expect(f.label, 'JD (UT1)');
      expect(f.onScale, jdUt);
    });

    test('the scale actually changes the number across the three settings', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final values = [
        for (final s in TimeScale.values)
          jdScaleField(swe!, jdUt, scale: s).onScale,
      ];
      expect(values.toSet(), hasLength(2), reason: 'UTC and UT1 coincide');
      expect(values.any((v) => v != jdUt), isTrue);
    });

    test('the prefix and digits are honoured', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final f = jdScaleField(
        swe!,
        jdUt,
        scale: TimeScale.ut1,
        prefix: 'Max JD',
        digits: 8,
      );
      expect(f.label, 'Max JD (UT1)');
      expect(f.value, '2451545.00000000');
    });

    test('a null JD is the empty placeholder, with no on-scale value', () {
      final f = jdScaleField(_NoSwe(), null, scale: TimeScale.ut1);
      expect(f.value, '—');
      expect(f.onScale, isNull);
    });

    test('a non-finite JD is NaN, not a rendered instant', () {
      final f = jdScaleField(_NoSwe(), double.nan, scale: TimeScale.ut1);
      expect(f.value, 'NaN');
      expect(f.onScale, isNull);
    });
  });
}

/// A [SweUtils] that must never be touched: the null/NaN paths return before any
/// engine call, so these cases need no native library.
class _NoSwe implements SweUtils {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('engine must not be reached for null/NaN JD');
}
