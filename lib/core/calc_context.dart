import 'package:flutter_riverpod/flutter_riverpod.dart';

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
