// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// [computeCrossing] backward search. swisseph's sol/moon/node crossings are
/// forward-only, so backward is two forward searches at the app layer: the next
/// crossing, then a second search one period-with-margin before it. These pin
/// that the second search actually issues from `next - margin` and returns the
/// immediately-previous event — the whole point of the feature.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/core/ephemeris/fake_ephemeris.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/output_clock.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/tabs/crossings/crossings_provider.dart';

void main() {
  group('computeCrossing direction', () {
    // build() formats the found JD on the Context Scale via the real engine; a
    // finite crossing therefore needs the native library, as in jd_scale_field.
    SweUtils? swe;

    setUp(() {
      try {
        swe = SweUtils(EphemerisRunner());
      } catch (_) {
        // Native library not available on this platform.
      }
    });

    const now = 2451545.0;
    const nextCross = now + 100.0; // the fake "next" crossing
    const prevCross = now - 265.0; // what the margin-shifted 2nd search returns

    CrossingResult run(CrossingType type, int dir, FakeEphemeris eph) =>
        computeCrossing(
          eph: eph,
          swe: swe!,
          jdUt: now,
          iflag: 0,
          type: type,
          longitude: 120.0,
          helioBody: seMercury,
          dir: dir,
          helioBodyName: 'Mercury',
          view: ClockView.ut,
        );

    test('sunCross forward passes through the single native call', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      var calls = 0;
      final fake = FakeEphemeris()
        ..onSolCrossUt = (lon, startJd, flags) {
          calls++;
          return nextCross;
        };
      final r = run(CrossingType.sunCross, 1, fake);
      expect(calls, 1);
      expect(r.crossingJd, nextCross);
      expect(r.description, contains('forward'));
    });

    test('sunCross backward returns the immediately-previous crossing', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final starts = <double>[];
      final fake = FakeEphemeris()
        ..onSolCrossUt = (lon, startJd, flags) {
          starts.add(startJd);
          // First search starts at `now`; the second at `nextCross - margin`,
          // which is < now, so it yields the previous crossing.
          return startJd == now ? nextCross : prevCross;
        };
      final r = run(CrossingType.sunCross, -1, fake);
      expect(starts, hasLength(2));
      expect(starts.first, now);
      expect(starts[1], nextCross - 370.0); // _sunBackMargin
      expect(r.crossingJd, prevCross);
      expect(r.description, contains('backward'));
    });

    test('a NaN next short-circuits: no second search, stays NaN', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      var calls = 0;
      final fake = FakeEphemeris()
        ..onSolCrossUt = (lon, startJd, flags) {
          calls++;
          return double.nan;
        };
      final r = run(CrossingType.sunCross, -1, fake);
      expect(calls, 1);
      expect(r.crossingJd, isNaN);
    });

    test('moonCross backward searches from next minus the moon margin', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final starts = <double>[];
      final fake = FakeEphemeris()
        ..onMoonCrossUt = (lon, startJd, flags) {
          starts.add(startJd);
          return startJd == now ? nextCross : prevCross;
        };
      final r = run(CrossingType.moonCross, -1, fake);
      expect(starts[1], nextCross - 30.0); // _moonBackMargin
      expect(r.crossingJd, prevCross);
    });

    test(
      'moonNode backward returns the previous node crossing + longitude',
      () {
        if (swe == null) return markTestSkipped('SwissEph unavailable');
        final starts = <double>[];
        const nextNode = now + 10.0;
        final fake = FakeEphemeris()
          ..onMoonCrossNodeUt = (startJd, flags) {
            starts.add(startJd);
            return startJd >= now
                ? const MoonNodeCrossResult(
                    jdUt: nextNode,
                    longitude: 100.0,
                    latitude: 0.0,
                  )
                : const MoonNodeCrossResult(
                    jdUt: now - 20.0,
                    longitude: 280.0,
                    latitude: 0.0,
                  );
          };
        final r = run(CrossingType.moonNode, -1, fake);
        expect(starts, hasLength(2));
        expect(starts[1], nextNode - 16.0); // _nodeBackMargin
        expect(r.crossingJd, now - 20.0);
        expect(r.crossingLongitude, 280.0);
        expect(r.description, contains('backward'));
      },
    );
  });
}
