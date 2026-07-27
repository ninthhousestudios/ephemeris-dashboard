// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Unit-pins what `computeHeliacal` hands the engine (swe-dashboard/80, A2).
///
/// The Ephemeris Source cannot be pinned by comparing results: Swiss and
/// Moshier agree on a heliacal event to well under the tenth of a second the
/// event is reported at, so "the source was ignored" is invisible in the
/// numbers. It is only visible in the argument, which is what this asserts.
/// The *effect* of the optical parameters is pinned separately, against
/// swetest, in heliacal_optical_parity_test.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephemeris/fake_ephemeris.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/output_clock.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/core/time_scale.dart';
import 'package:swe_dashboard/tabs/heliacal/heliacal_provider.dart';
import 'package:swe_dashboard/widgets/result_section.dart';

const _atmo = AtmoConditions(
  pressure: 1013.25,
  temperature: 25.0,
  humidity: 50.0,
  extinction: 0.2,
);

const _telescope = ObserverConditions(
  age: 36,
  snellenRatio: 1,
  monoNoBino: 0,
  telescopeMag: 50,
  telescopeDia: 100,
  transmission: 0.8,
);

void main() {
  group('computeHeliacal', () {
    late FakeEphemeris fake;
    int? seenFlags;
    ObserverConditions? seenObserver;

    setUp(() {
      seenFlags = null;
      seenObserver = null;
      fake = FakeEphemeris()
        ..onHeliacalUt =
            ((
              jdStart, {
              required geolon,
              required geolat,
              geoalt = 0,
              required atmo,
              required observer,
              required objectName,
              required typeEvent,
              flags = 0,
            }) {
              seenFlags = flags;
              seenObserver = observer;
              return const HeliacalResult(
                startVisible: 1,
                bestVisible: 2,
                endVisible: 3,
              );
            });
    });

    List<HeliacalCalcResult> run({
      required int epheflag,
      List<String> targets = const ['Venus'],
    }) => computeHeliacal(
      eph: fake,
      jdUt: 2461041.5,
      targets: targets,
      typeEvent: seHeliacalRising,
      geolon: 13.4,
      geolat: 52.5,
      geoalt: 0,
      atmo: _atmo,
      observer: _telescope,
      epheflag: epheflag,
    );

    test('forwards the Context ephemeris source', () {
      run(epheflag: seFlgMosEph);
      expect(seenFlags, seFlgMosEph);

      run(epheflag: seFlgJplEph);
      expect(seenFlags, seFlgJplEph);
    });

    test('forwards the optical-instrument inputs unmodified', () {
      run(epheflag: seFlgSwiEph);
      expect(seenObserver?.monoNoBino, 0);
      expect(seenObserver?.telescopeMag, 50);
      expect(seenObserver?.telescopeDia, 100);
      expect(seenObserver?.transmission, 0.8);
    });

    test('one failing target does not lose the others', () {
      fake.onHeliacalUt =
          ((
            jdStart, {
            required geolon,
            required geolat,
            geoalt = 0,
            required atmo,
            required observer,
            required objectName,
            required typeEvent,
            flags = 0,
          }) {
            if (objectName == 'Venus') throw StateError('no event');
            return const HeliacalResult(
              startVisible: 1,
              bestVisible: 2,
              endVisible: 3,
            );
          });

      final results = run(
        epheflag: seFlgSwiEph,
        targets: const ['Venus', 'Mercury'],
      );
      expect(results, hasLength(2));
      expect(results[0].hasError, isTrue);
      expect(results[1].hasError, isFalse);
      expect(results[1].startVisibleJd, 1);
    });
  });

  group('the Julian Days card follows the Context Scale', () {
    // The event JDs the engine returns are UT1 Moments; the card used to print
    // them raw, so the Scale moved the date-time card above it and left this
    // one behind — the same instant shown twice, disagreeing.
    const result = HeliacalCalcResult(
      objectName: 'Venus',
      eventType: seHeliacalRising,
      startVisibleJd: 2451545.0,
      bestVisibleJd: 2451545.5,
      endVisibleJd: 2451546.0,
    );

    SweUtils? swe;

    setUp(() {
      try {
        swe = SweUtils(EphemerisRunner());
      } catch (_) {
        // Native library not available on this platform.
      }
    });

    ResultSection jdCard(TimeScale scale) => heliacalSections(
      result,
      swe!,
      ClockView(
        clock: OutputClock.standard,
        longitude: 0,
        utcOffset: 0,
        scale: scale,
      ),
    ).last;

    test('UT1 labels the scale and leaves the Moments alone', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final card = jdCard(TimeScale.ut1);
      expect(card.fields.map((f) => f.label), [
        'Start Visible (JD UT1)',
        'Best Visible (JD UT1)',
        'End Visible (JD UT1)',
      ]);
      expect(card.fields.first.value, '2451545.000000');
    });

    test('TT relabels and shifts by ΔT', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final card = jdCard(TimeScale.tt);
      expect(card.fields.map((f) => f.label), [
        'Start Visible (JD TT)',
        'Best Visible (JD TT)',
        'End Visible (JD TT)',
      ]);
      // ΔT at J2000 is ~64 s, so the TT number is above the UT1 one — and the
      // rawValue moves with the displayed text, since the export reads it.
      final shown = double.parse(card.fields.first.value);
      expect(shown, greaterThan(2451545.0));
      expect(shown, closeTo(2451545.0 + 64 / 86400, 1e-5));
      expect(card.fields.first.rawValue, closeTo(shown, 1e-6));
    });

    test('UTC reads as UT1, the scale the number is actually on', () {
      if (swe == null) return markTestSkipped('SwissEph unavailable');
      final card = jdCard(TimeScale.utc);
      expect(card.fields.first.label, 'Start Visible (JD UT1)');
      expect(card.fields.first.value, '2451545.000000');
    });
  });
}
