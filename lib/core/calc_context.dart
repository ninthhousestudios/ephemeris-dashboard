// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ayanamsa_catalog.dart';
import 'context_provider.dart';
import 'context_state.dart';
import 'flag_provider.dart';
import 'user_ayanamsa.dart';

/// Merged view of global context bar + flag bar state,
/// ready for a calculation call.
///
/// Single place where override-merge happens. Per-card overrides
/// will extend this in Phase 7 (pinned results).
class EffectiveContext {
  const EffectiveContext({
    required this.jdUt,
    required this.iflag,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.origin,
    required this.zodiacRef,
    required this.eqRef,
    required this.ayanamsa,
    this.userAyanT0 = 0.0,
    this.userAyanValue = 0.0,
    this.userAyanT0IsUt = false,
    this.projection = SiderealProjection.standard,
    required this.epheSource,
    this.jplFilename,
  });

  final double jdUt;
  final int iflag;
  final double latitude;
  final double longitude;
  final double altitude;
  final Origin origin;
  final ZodiacRef zodiacRef;
  final EqRef eqRef;
  final int ayanamsa; // -1 = tropical/none; 255 = user-defined

  // The selected user-defined ayanamsha's parameters, resolved out of
  // `userAyanamsasProvider` by the Context's `userAyanId`. Flattened here so a
  // compute still sees a plain set of engine parameters, with the entry list
  // itself confined to the projection below.
  final double userAyanT0;
  final double userAyanValue;
  final bool userAyanT0IsUt;
  final SiderealProjection projection;
  final EpheSource epheSource;
  final String? jplFilename;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EffectiveContext &&
          jdUt == other.jdUt &&
          iflag == other.iflag &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          altitude == other.altitude &&
          origin == other.origin &&
          zodiacRef == other.zodiacRef &&
          eqRef == other.eqRef &&
          ayanamsa == other.ayanamsa &&
          userAyanT0 == other.userAyanT0 &&
          userAyanValue == other.userAyanValue &&
          userAyanT0IsUt == other.userAyanT0IsUt &&
          projection == other.projection &&
          epheSource == other.epheSource &&
          jplFilename == other.jplFilename;

  @override
  int get hashCode => Object.hash(
    jdUt,
    iflag,
    latitude,
    longitude,
    altitude,
    origin,
    zodiacRef,
    eqRef,
    ayanamsa,
    userAyanT0,
    userAyanValue,
    userAyanT0IsUt,
    projection,
    epheSource,
    jplFilename,
  );
}

/// Derived provider: merges context bar + flag bar into EffectiveContext.
final effectiveContextProvider = Provider<EffectiveContext>((ref) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);
  // Only the selected entry can change a calculation, but the list is watched
  // whole: an edit to it is exactly what has to recompute the chart.
  final user = ctx.ayanamsa == ayanamsaUserId
      ? resolveUserAyanamsa(ref.watch(userAyanamsasProvider), ctx.userAyanId)
      : null;
  // 255 with nothing behind it is not a frame the engine can compute: it would
  // configure SE_SIDM_USER from a zeroed t0/value and return a zodiac nobody
  // chose, looking like a real result. `contextBarProvider` reconciles the
  // selection off user-defined the moment the entry goes away, so this is the
  // same landing spot, held here too because a derived value must not depend
  // on that having happened first.
  final ayanamsa = user == null && ctx.ayanamsa == ayanamsaUserId
      ? ayanamsaDefaultSiderealId
      : ctx.ayanamsa;

  return EffectiveContext(
    jdUt: ctx.jdUt,
    iflag: flags.iflag,
    latitude: ctx.latitude,
    longitude: ctx.longitude,
    altitude: ctx.altitude,
    origin: ctx.origin,
    zodiacRef: ctx.zodiacRef,
    eqRef: ctx.eqRef,
    ayanamsa: ayanamsa,
    userAyanT0: user?.t0 ?? 0.0,
    userAyanValue: user?.value ?? 0.0,
    userAyanT0IsUt: user?.t0IsUt ?? false,
    projection: ctx.projection,
    epheSource: ctx.epheSource,
    jplFilename: ctx.jplFilename,
  );
});
