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
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/tabs/heliacal/heliacal_provider.dart';

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
}
