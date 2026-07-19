// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph_rs/swisseph_rs.dart' as rs;

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

  static const _sourceMap = {
    EpheSource.moshier: rs.EphemerisSource.moshier,
    EpheSource.swissEph: rs.EphemerisSource.swiss,
    EpheSource.jpl: rs.EphemerisSource.jpl,
  };

  rs.EphemerisConfig toEphemerisConfig() {
    rs.SiderealMode? rsMode;
    rs.SiderealBits rsBits = rs.SiderealBits.none;
    bool t0IsUt = false;
    double t0 = 0;
    double ayanT0 = 0;

    if (sidMode != null) {
      final modeIndex = sidMode! & 0xFF;
      rsMode = rs.SiderealMode.values.firstWhere(
        (m) => m.value == modeIndex,
        orElse: () => rs.SiderealMode.faganBradley,
      );
      rsBits = rs.SiderealBits(sidMode! & ~0xFF);
      t0IsUt = (sidMode! & 1024) != 0;
      t0 = userAyanT0;
      ayanT0 = userAyanValue;
    }

    return rs.EphemerisConfig(
      ephemerisSource: _sourceMap[epheSource]!,
      ephePath: ephePath,
      jplFilename: jplFile,
      siderealMode: rsMode,
      siderealT0: t0,
      siderealAyanT0: ayanT0,
      siderealBits: rsBits,
      siderealT0IsUt: t0IsUt,
      topographic: topo != null
          ? rs.TopoPosition(
              longitude: topo!.lon,
              latitude: topo!.lat,
              altitude: topo!.alt,
            )
          : null,
    );
  }

  AppliedGlobals withSidMode(
    int newSidMode, {
    double t0 = 0,
    double ayanT0 = 0,
  }) {
    return AppliedGlobals(
      ephePath: ephePath,
      epheSource: epheSource,
      sidMode: newSidMode,
      userAyanT0: t0,
      userAyanValue: ayanT0,
      topo: topo,
      jplFile: jplFile,
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
