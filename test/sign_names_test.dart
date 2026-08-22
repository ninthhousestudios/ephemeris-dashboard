// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Sign names (swe-dashboard/100) are a pure display relabel of the equal 30°
/// division of an ecliptic longitude. These tests pin the parts that carry the
/// feature: the `lon mod 30` math (including negative/wrap longitudes), the
/// scheme tables, the ecliptic gate, the Context reconcile (Aditya needs
/// tropical, True Sidereal needs its ayanamsha, else fall back to Zodiac), the
/// user-set store round trip, and the selection's fall-back-to-Zodiac when its
/// set is removed. The Human Design subdivision (gate/line/color/tone/base) is
/// pinned against libaditya's YiLongitude reference values.
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
      expect(signNameFor(0, SignScheme.zodiac, null, null), 'Aries');
      expect(signNameFor(120, SignScheme.zodiac, null, null), 'Leo');
      expect(signNameFor(359, SignScheme.zodiac, null, null), 'Pisces');
    });

    test('aditya relabels the same signs, Dhata at 330–360', () {
      expect(signNameFor(0, SignScheme.aditya, null, null), 'Aryama');
      expect(signNameFor(330, SignScheme.aditya, null, null), 'Dhata');
      expect(signNameFor(359.9, SignScheme.aditya, null, null), 'Dhata');
      expect(adityaNames.length, 12);
    });

    test('none produces no name; trueSidereal without a binning does too', () {
      expect(signNameFor(120, SignScheme.none, null, null), isNull);
      // True Sidereal needs a runtime binning; without one, no name renders.
      expect(signNameFor(120, SignScheme.trueSidereal, null, null), isNull);
    });

    test('userDefined uses its set, falling back to zodiac when malformed', () {
      final set = UserSignSet(id: 0, names: List.generate(12, (i) => 'S$i'));
      expect(signNameFor(0, SignScheme.userDefined, set, null), 'S0');
      expect(signNameFor(45, SignScheme.userDefined, set, null), 'S1');
      // Missing set: still renders a name rather than blank.
      expect(signNameFor(45, SignScheme.userDefined, null, null), 'Taurus');
    });
  });

  group('inSignField gate', () {
    const zodiac = SignScheme.zodiac;

    test('renders the in-sign tuple for an ecliptic longitude', () {
      final f = inSignField(45, 0, zodiac, null, DisplayFormat.decimal, null);
      expect(f, isNotNull);
      expect(f!.$1, 'In-Sign Longitude');
      expect(f.$2, startsWith('15.000000'));
      expect(f.$2, endsWith('Taurus'));
    });

    test('excludes equatorial and cartesian coordinates', () {
      expect(
        inSignField(45, seFlgEquatorial, zodiac, null, DisplayFormat.dms, null),
        isNull,
      );
      expect(
        inSignField(45, seFlgXyz, zodiac, null, DisplayFormat.dms, null),
        isNull,
      );
    });

    test('null for scheme none, binning-less trueSidereal, non-finite lon', () {
      expect(
        inSignField(45, 0, SignScheme.none, null, DisplayFormat.dms, null),
        isNull,
      );
      expect(
        inSignField(
          45,
          0,
          SignScheme.trueSidereal,
          null,
          DisplayFormat.dms,
          null,
        ),
        isNull,
      );
      expect(
        inSignField(double.nan, 0, zodiac, null, DisplayFormat.dms, null),
        isNull,
      );
    });
  });

  group('Human Design subdivision', () {
    // Reference values from libaditya's YiLongitude (hd/longitude.py).
    test('places lon 0° at gate 25, line 2, color 6, tone 2, base 1', () {
      final p = humanDesignPlacement(0);
      expect(p.gate, 25);
      expect(p.line, 2);
      expect(p.color, 6);
      expect(p.tone, 2);
      expect(p.base, 1);
      expect(p.gateInLon, closeTo(1.75, 1e-9));
      expect(p.lineInLon, closeTo(0.8125, 1e-9));
      expect(p.colorInLon, closeTo(0.03125, 1e-9));
      expect(p.toneInLon, closeTo(0.005208333, 1e-9));
      expect(p.baseInLon, closeTo(0.005208333, 1e-9));
      expect(p.gateElapsed, closeTo(31.11, 1e-2));
      expect(p.lineElapsed, closeTo(86.67, 1e-2));
      expect(p.baseElapsed, closeTo(100.0, 1e-2));
    });

    test('gate 1 begins exactly at 223°15′ (13°15′ Scorpio)', () {
      final p = humanDesignPlacement(223.25);
      expect(p.gate, 1);
      expect(p.line, 1);
      expect(p.color, 1);
      expect(p.tone, 1);
      expect(p.base, 1);
      expect(p.gateInLon, closeTo(0, 1e-9));
      expect(p.baseInLon, closeTo(0, 1e-9));
    });

    test('wraps for lon just under a full turn (359.9°)', () {
      final p = humanDesignPlacement(359.9);
      expect(p.gate, 25);
      expect(p.line, 2);
      expect(p.color, 5);
      expect(p.tone, 4);
      expect(p.base, 2);
      expect(p.gateInLon, closeTo(1.65, 1e-9));
    });

    test('inSignField renders the 5-line breakdown under one label', () {
      final f = inSignField(
        0,
        0,
        SignScheme.humanDesign,
        null,
        DisplayFormat.decimal,
        null,
      );
      expect(f, isNotNull);
      expect(f!.$1, 'In-Sign Longitude');
      final lines = f.$2.split('\n');
      expect(lines, hasLength(5));
      expect(lines[0], contains('gate 25;'));
      expect(lines[0], contains('31.11% elapsed'));
      expect(lines[1], contains('line 2;'));
      expect(lines[4], contains('base 1;'));
    });

    test('inSignField still excludes equatorial/cartesian for HD', () {
      expect(
        inSignField(
          0,
          seFlgXyz,
          SignScheme.humanDesign,
          null,
          DisplayFormat.dms,
          null,
        ),
        isNull,
      );
    });

    test('signPlacement yields no single name (HD is not a named sign)', () {
      expect(signNameFor(0, SignScheme.humanDesign, null, null), isNull);
    });
  });

  group('effectiveSchemeFor — reconcile against the Context', () {
    test('none, zodiac, userDefined, humanDesign valid in every frame', () {
      for (final frame in [
        _ctx(),
        _ctx(zodiac: ZodiacRef.sidereal, ayanamsa: 1),
      ]) {
        expect(
          effectiveSchemeFor(
            const SignNameSelection(scheme: SignScheme.humanDesign),
            frame,
          ),
          SignScheme.humanDesign,
        );
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

    test('reconcileScheme collapses Aditya when the zodiac turns sidereal', () {
      final n = SignNameSelectionNotifier(
        initial: const SignNameSelection(scheme: SignScheme.aditya),
      );
      // Still tropical: held.
      n.reconcileScheme(_ctx());
      expect(n.state.scheme, SignScheme.aditya);
      // Sidereal: Aditya cannot render, collapses to Zodiac.
      n.reconcileScheme(_ctx(zodiac: ZodiacRef.sidereal, ayanamsa: 1));
      expect(n.state.scheme, SignScheme.zodiac);
    });

    test('reconcileScheme collapses True Sidereal when its frame is left', () {
      final n = SignNameSelectionNotifier(
        initial: const SignNameSelection(scheme: SignScheme.trueSidereal),
      );
      // In frame: held.
      n.reconcileScheme(
        _ctx(zodiac: ZodiacRef.sidereal, ayanamsa: ayanamsaTrueSiderealId),
      );
      expect(n.state.scheme, SignScheme.trueSidereal);
      // Back to tropical: collapses.
      n.reconcileScheme(_ctx());
      expect(n.state.scheme, SignScheme.zodiac);
    });

    test('reconcileScheme leaves userDefined (valid in every frame) alone', () {
      final n = SignNameSelectionNotifier(
        initial: const SignNameSelection(
          scheme: SignScheme.userDefined,
          userSetId: 4,
        ),
      );
      n.reconcileScheme(_ctx(zodiac: ZodiacRef.sidereal, ayanamsa: 1));
      expect(n.state.scheme, SignScheme.userDefined);
      expect(n.state.userSetId, 4);
    });
  });
}
