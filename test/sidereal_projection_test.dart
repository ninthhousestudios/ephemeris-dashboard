// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ayanamsa_catalog.dart';
import 'package:swe_dashboard/core/calc_context.dart';
import 'package:swe_dashboard/core/context_provider.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/ephemeris/applied_globals.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/widget_fixtures.dart';

EffectiveContext _ctx({
  required int ayanamsa,
  SiderealProjection projection = SiderealProjection.standard,
  bool userT0IsUt = false,
  double userAyanT0 = 0,
  double userAyanValue = 0,
}) => EffectiveContext(
  jdUt: 2460412.5,
  iflag: seFlgSwiEph,
  latitude: 0,
  longitude: 0,
  altitude: 0,
  origin: Origin.geocentric,
  zodiacRef: ZodiacRef.sidereal,
  eqRef: EqRef.trueEquinoxOfDate,
  ayanamsa: ayanamsa,
  projection: projection,
  userAyanT0IsUt: userT0IsUt,
  userAyanT0: userAyanT0,
  userAyanValue: userAyanValue,
  epheSource: EpheSource.moshier,
);

void main() {
  group('AppliedGlobals packs SE_SIDBIT modifiers into sidMode', () {
    test('standard projection leaves the ayanamsha number alone', () {
      final g = AppliedGlobals.fromContext(_ctx(ayanamsa: 1), null);
      expect(g.sidMode, 1); // Lahiri, no bits
    });

    test('ecliptic-of-t0 ORs SE_SIDBIT_ECL_T0 (256)', () {
      final g = AppliedGlobals.fromContext(
        _ctx(ayanamsa: 1, projection: SiderealProjection.eclipticT0),
        null,
      );
      expect(g.sidMode, 1 | 256);
    });

    test('solar-system-plane ORs SE_SIDBIT_SSY_PLANE (512)', () {
      final g = AppliedGlobals.fromContext(
        _ctx(ayanamsa: 1, projection: SiderealProjection.solarSystemPlane),
        null,
      );
      expect(g.sidMode, 1 | 512);
    });

    test('t0-is-UT only applies to the user-defined mode', () {
      // Non-user mode: USER_UT bit must not be set even if flag is true.
      final nonUser = AppliedGlobals.fromContext(
        _ctx(ayanamsa: 1, userT0IsUt: true),
        null,
      );
      expect(nonUser.sidMode! & 1024, 0);

      // User-defined mode: USER_UT (1024) is set.
      final user = AppliedGlobals.fromContext(
        _ctx(
          ayanamsa: 255,
          userT0IsUt: true,
          userAyanT0: 2451545,
          userAyanValue: 24,
        ),
        null,
      );
      expect(user.sidMode! & 1024, 1024);
      expect(user.sidMode! & 0xFF, 255);
    });

    test('tropical yields no sidMode regardless of projection', () {
      final g = AppliedGlobals.fromContext(
        const EffectiveContext(
          jdUt: 2460412.5,
          iflag: seFlgSwiEph,
          latitude: 0,
          longitude: 0,
          altitude: 0,
          origin: Origin.geocentric,
          zodiacRef: ZodiacRef.tropical,
          eqRef: EqRef.trueEquinoxOfDate,
          ayanamsa: -1,
          projection: SiderealProjection.solarSystemPlane,
          epheSource: EpheSource.moshier,
        ),
        null,
      );
      expect(g.sidMode, isNull);
    });
  });

  group('True Sidereal preset resolves to SE_SIDM_USER', () {
    Future<ProviderContainer> container() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          epheBootstrapOverride,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'the effective context flattens the preset into 255 + fixed params',
      () async {
        final c = await container();
        c.read(contextBarProvider.notifier)
          ..setZodiacRef(ZodiacRef.sidereal)
          ..setAyanamsa(ayanamsaTrueSiderealId);

        final ectx = c.read(effectiveContextProvider);
        expect(ectx.ayanamsa, ayanamsaUserId);
        expect(ectx.userAyanT0, 2451545.0);
        expect(ectx.userAyanValue, 31.2816);
        expect(ectx.userAyanT0IsUt, isFalse);

        // And it reaches the engine as SE_SIDM_USER with no jdisut bit.
        final g = AppliedGlobals.fromContext(ectx, null);
        expect(g.sidMode! & 0xFF, 255);
        expect(g.sidMode! & 1024, 0);
        expect(g.userAyanT0, 2451545.0);
        expect(g.userAyanValue, 31.2816);
      },
    );

    test('the preset survives a tropical round-trip', () async {
      final c = await container();
      final notifier = c.read(contextBarProvider.notifier)
        ..setZodiacRef(ZodiacRef.sidereal)
        ..setAyanamsa(ayanamsaTrueSiderealId);

      notifier.setZodiacRef(ZodiacRef.tropical);
      expect(c.read(contextBarProvider).ayanamsa, ayanamsaTropicalId);

      notifier.setZodiacRef(ZodiacRef.sidereal);
      expect(c.read(contextBarProvider).ayanamsa, ayanamsaTrueSiderealId);
    });
  });

  group('projection bits reach the engine and change body positions', () {
    late EphemerisRunner runner;
    setUp(() => runner = EphemerisRunner());
    tearDown(() => runner.close());

    double sunLon(SiderealProjection p) {
      runner.apply(
        AppliedGlobals.fromContext(_ctx(ayanamsa: 1, projection: p), null),
      );
      return runner.eph
          .calcUt(2460412.5, seSun, seFlgSpeed | seFlgSidereal)
          .longitude;
    }

    test(
      'solar-system-plane differs from standard (matches swetest -sidsp)',
      () {
        final standard = sunLon(SiderealProjection.standard);
        final ssyPlane = sunLon(SiderealProjection.solarSystemPlane);
        expect((standard - ssyPlane).abs(), greaterThan(1e-4));
      },
    );
  });
}
