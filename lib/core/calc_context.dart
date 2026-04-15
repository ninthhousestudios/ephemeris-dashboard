import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import 'context_provider.dart';
import 'context_state.dart';
import 'flag_provider.dart';

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
  final double userAyanT0;
  final double userAyanValue;
  final EpheSource epheSource;
  final String? jplFilename;

  /// Set C globals atomically and run a calculation.
  ///
  /// This is the ONLY place C globals should be set. Context bar
  /// never touches them — we set them here right before each call
  /// to avoid race conditions with per-card overrides.
  T calculate<T>(SwissEph swe, T Function(SwissEph swe, double jd, int flags) fn) {
    _applyGlobals(swe);
    return fn(swe, jdUt, iflag);
  }

  /// Apply C global state (sidereal mode, topo, ephe path).
  void _applyGlobals(SwissEph swe) {
    // Sidereal mode
    if (zodiacRef == ZodiacRef.sidereal && ayanamsa >= 0) {
      if (ayanamsa == 255) {
        swe.setSidMode(ayanamsa, t0: userAyanT0, ayanT0: userAyanValue);
      } else {
        swe.setSidMode(ayanamsa);
      }
    }

    // Topocentric
    if (origin == Origin.topocentric) {
      swe.setTopo(longitude, latitude, altitude);
    }

    // JPL file selection (only meaningful when epheSource == jpl).
    if (epheSource == EpheSource.jpl && jplFilename != null) {
      swe.setJplFile(jplFilename!);
    }
  }

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
          epheSource == other.epheSource &&
          jplFilename == other.jplFilename;

  @override
  int get hashCode => Object.hash(
        jdUt, iflag, latitude, longitude, altitude,
        origin, zodiacRef, eqRef, ayanamsa, userAyanT0, userAyanValue,
        epheSource, jplFilename,
      );
}

/// Derived provider: merges context bar + flag bar into EffectiveContext.
final effectiveContextProvider = Provider<EffectiveContext>((ref) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);

  return EffectiveContext(
    jdUt: ctx.jdUt,
    iflag: flags.iflag,
    latitude: ctx.latitude,
    longitude: ctx.longitude,
    altitude: ctx.altitude,
    origin: ctx.origin,
    zodiacRef: ctx.zodiacRef,
    eqRef: ctx.eqRef,
    ayanamsa: ctx.ayanamsa,
    userAyanT0: ctx.userAyanT0,
    userAyanValue: ctx.userAyanValue,
    epheSource: ctx.epheSource,
    jplFilename: ctx.jplFilename,
  );
});
