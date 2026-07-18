// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../calc_context.dart';
import '../context_state.dart';

class AppliedGlobals {
  const AppliedGlobals({
    required this.ephePath,
    required this.epheSource,
    required this.sidMode,
    required this.userAyanT0,
    required this.userAyanValue,
    required this.topo,
    required this.jplFile,
  });

  final String? ephePath;
  final EpheSource epheSource;
  final int? sidMode;
  final double userAyanT0;
  final double userAyanValue;
  final ({double lon, double lat, double alt})? topo;
  final String? jplFile;

  factory AppliedGlobals.fromContext(EffectiveContext ctx, String? ephePath) {
    return AppliedGlobals(
      ephePath: ephePath,
      epheSource: ctx.epheSource,
      sidMode: ctx.zodiacRef == ZodiacRef.sidereal && ctx.ayanamsa >= 0
          ? ctx.ayanamsa
          : null,
      userAyanT0: ctx.userAyanT0,
      userAyanValue: ctx.userAyanValue,
      topo: ctx.origin == Origin.topocentric
          ? (lon: ctx.longitude, lat: ctx.latitude, alt: ctx.altitude)
          : null,
      jplFile: ctx.epheSource == EpheSource.jpl ? ctx.jplFilename : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppliedGlobals &&
          ephePath == other.ephePath &&
          epheSource == other.epheSource &&
          sidMode == other.sidMode &&
          userAyanT0 == other.userAyanT0 &&
          userAyanValue == other.userAyanValue &&
          topo == other.topo &&
          jplFile == other.jplFile;

  @override
  int get hashCode => Object.hash(
    ephePath,
    epheSource,
    sidMode,
    userAyanT0,
    userAyanValue,
    topo,
    jplFile,
  );
}
