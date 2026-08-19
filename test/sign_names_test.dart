// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Sign names (swe-dashboard/100) are a pure display relabel of the equal 30°
/// division of an ecliptic longitude. These tests pin the parts that carry the
/// feature: the `lon mod 30` math (including negative/wrap longitudes), the
/// scheme tables, the ecliptic gate, the Context reconcile (Aditya needs
/// tropical, True Sidereal needs its ayanamsha, else fall back to Zodiac), the
/// user-set store round trip, and the selection's fall-back-to-Zodiac when its
/// set is removed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ayanamsa_catalog.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/display_format.dart';
import 'package:swe_dashboard/core/sign_names.dart';
import 'package:swe_dashboard/core/swe_constants.dart';

ContextBarState _ctx({
  ZodiacRef zodiac = ZodiacRef.tropical,
  int ayanamsa = ayanamsaTropicalId,
}) => ContextBarState(
  utcOffset: 0,
  jdUt: 2451545.0,
  zodiacRef: zodiac,
  ayanamsa: ayanamsa,
);

void main() {
  group('sign math', () {
    test('inSignLongitude is lon mod 30 in [0, 30)', () {
      expect(inSignLongitude(0), 0);
      expect(inSignLongitude(15), 15);
      expect(inSignLongitude(30), 0);
      expect(inSignLongitude(45), 15);
      expect(inSignLongitude(359.9), closeTo(29.9, 1e-9));
    });

    test('inSignLongitude normalises negative and >360 longitudes', () {
      expect(inSignLongitude(-5), closeTo(25, 1e-9)); // -5° = 355° = Pisces 25°
      expect(inSignLongitude(-30), 0);
      expect(inSignLongitude(390), 0); // 390° = 30° = Taurus 0°
    });

    test('signIndex wraps to [0, 12)', () {
      expect(signIndex(0), 0);
      expect(signIndex(29.9), 0);
      expect(signIndex(30), 1);
      expect(signIndex(359.9), 11);
      expect(signIndex(-5), 11); // 355° is Pisces
      expect(signIndex(360), 0);
    });
  });

  group('scheme tables', () {
    test('zodiac names index by floor(lon / 30)', () {
      expect(signNameFor(0, SignScheme.zodiac, null), 'Aries');
      expect(signNameFor(120, SignScheme.zodiac, null), 'Leo');
      expect(signNameFor(359, SignScheme.zodiac, null), 'Pisces');
    });

    test('aditya relabels the same signs, Dhata at 330–360', () {
      expect(signNameFor(0, SignScheme.aditya, null), 'Aryama');
      expect(signNameFor(330, SignScheme.aditya, null), 'Dhata');
      expect(signNameFor(359.9, SignScheme.aditya, null), 'Dhata');
      expect(adityaNames.length, 12);
    });

    test('none and trueSidereal produce no name (rendering deferred /102)', () {
      expect(signNameFor(120, SignScheme.none, null), isNull);
      expect(signNameFor(120, SignScheme.trueSidereal, null), isNull);
    });

    test('userDefined uses its set, falling back to zodiac when malformed', () {
      final set = UserSignSet(id: 0, names: List.generate(12, (i) => 'S$i'));
      expect(signNameFor(0, SignScheme.userDefined, set), 'S0');
      expect(signNameFor(45, SignScheme.userDefined, set), 'S1');
      // Missing set: still renders a name rather than blank.
      expect(signNameFor(45, SignScheme.userDefined, null), 'Taurus');
    });
  });

  group('inSignField gate', () {
    const zodiac = SignScheme.zodiac;

    test('renders the in-sign tuple for an ecliptic longitude', () {
      final f = inSignField(45, 0, zodiac, null, DisplayFormat.decimal);
      expect(f, isNotNull);
      expect(f!.$1, 'Longitude Sign');
      expect(f.$2, startsWith('Taurus '));
      expect(f.$2, contains('15.000000'));
    });

    test('excludes equatorial and cartesian coordinates', () {
      expect(
        inSignField(45, seFlgEquatorial, zodiac, null, DisplayFormat.dms),
        isNull,
      );
      expect(
        inSignField(45, seFlgXyz, zodiac, null, DisplayFormat.dms),
        isNull,
      );
    });

    test('null for scheme none, deferred trueSidereal, and non-finite lon', () {
      expect(
        inSignField(45, 0, SignScheme.none, null, DisplayFormat.dms),
        isNull,
      );
      expect(
        inSignField(45, 0, SignScheme.trueSidereal, null, DisplayFormat.dms),
        isNull,
      );
      expect(
        inSignField(double.nan, 0, zodiac, null, DisplayFormat.dms),
        isNull,
      );
    });
  });

  group('effectiveSchemeFor — reconcile against the Context', () {
    test('none, zodiac, userDefined are valid in every frame', () {
      for (final frame in [
        _ctx(),
        _ctx(zodiac: ZodiacRef.sidereal, ayanamsa: 1),
      ]) {
        expect(
          effectiveSchemeFor(
            const SignNameSelection(scheme: SignScheme.none),
            frame,
          ),
          SignScheme.none,
        );
        expect(
          effectiveSchemeFor(
            const SignNameSelection(scheme: SignScheme.zodiac),
            frame,
          ),
          SignScheme.zodiac,
        );
        expect(
          effectiveSchemeFor(
            const SignNameSelection(
              scheme: SignScheme.userDefined,
              userSetId: 3,
            ),
            frame,
          ),
          SignScheme.userDefined,
        );
      }
    });

    test(
      'aditya holds under tropical, falls back to zodiac under sidereal',
      () {
        const sel = SignNameSelection(scheme: SignScheme.aditya);
        expect(effectiveSchemeFor(sel, _ctx()), SignScheme.aditya);
        expect(
          effectiveSchemeFor(
            sel,
            _ctx(zodiac: ZodiacRef.sidereal, ayanamsa: 1),
          ),
          SignScheme.zodiac,
        );
      },
    );

    test('trueSidereal holds only on sidereal + True Sidereal ayanamsha', () {
      const sel = SignNameSelection(scheme: SignScheme.trueSidereal);
      expect(
        effectiveSchemeFor(
          sel,
          _ctx(zodiac: ZodiacRef.sidereal, ayanamsa: ayanamsaTrueSiderealId),
        ),
        SignScheme.trueSidereal,
      );
      // Sidereal but wrong ayanamsha → fall back.
      expect(
        effectiveSchemeFor(sel, _ctx(zodiac: ZodiacRef.sidereal, ayanamsa: 1)),
        SignScheme.zodiac,
      );
      // Tropical → fall back.
      expect(effectiveSchemeFor(sel, _ctx()), SignScheme.zodiac);
    });
  });

  group('UserSignSet round trip', () {
    test('toJson / fromJson preserves a 12-name set', () {
      final set = UserSignSet(
        id: 7,
        name: 'Vedic',
        names: List.generate(12, (i) => 'N$i'),
      );
      final back = UserSignSet.fromJson(set.toJson());
      expect(back, set);
    });

    test('fromJson drops a set whose names are not exactly 12 strings', () {
      expect(
        UserSignSet.fromJson({
          'id': 1,
          'names': ['a', 'b'],
        }),
        isNull,
      );
      expect(
        UserSignSet.fromJson({
          'id': 1,
          'names': [for (var i = 0; i < 12; i++) i], // ints, not strings
        }),
        isNull,
      );
      expect(UserSignSet.fromJson('nonsense'), isNull);
    });
  });

  group('UserSignSetNotifier', () {
    test('add appends with distinct stable ids and returns the id', () {
      final n = UserSignSetNotifier();
      final id0 = n.add(names: zodiacNames);
      final id1 = n.add(names: zodiacNames);
      expect(id0, isNot(id1));
      expect(n.state.map((s) => s.id), [id0, id1]);
    });

    test('removeById drops just that entry', () {
      final n = UserSignSetNotifier();
      final id0 = n.add(names: zodiacNames);
      final id1 = n.add(names: zodiacNames);
      n.removeById(id0);
      expect(n.state.map((s) => s.id), [id1]);
    });

    test('update replaces name/names in place', () {
      final n = UserSignSetNotifier();
      final id = n.add(names: zodiacNames);
      n.update(id, name: 'Renamed');
      expect(n.state.single.name, 'Renamed');
      expect(n.state.single.names, zodiacNames);
    });
  });

  group('SignNameSelectionNotifier reconcile', () {
    test('a removed user set falls back to Zodiac', () {
      final n = SignNameSelectionNotifier(
        initial: const SignNameSelection(
          scheme: SignScheme.userDefined,
          userSetId: 5,
        ),
      );
      n.reconcile([1, 2, 3]); // 5 is gone
      expect(n.state.scheme, SignScheme.zodiac);
      expect(n.state.userSetId, isNull);
    });

    test('leaves a still-present selection alone', () {
      final n = SignNameSelectionNotifier(
        initial: const SignNameSelection(
          scheme: SignScheme.userDefined,
          userSetId: 2,
        ),
      );
      n.reconcile([1, 2, 3]);
      expect(n.state.scheme, SignScheme.userDefined);
      expect(n.state.userSetId, 2);
    });

    test('does not touch a non-user scheme', () {
      final n = SignNameSelectionNotifier(
        initial: const SignNameSelection(scheme: SignScheme.aditya),
      );
      n.reconcile([]);
      expect(n.state.scheme, SignScheme.aditya);
    });
  });
}
