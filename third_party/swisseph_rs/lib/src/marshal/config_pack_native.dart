// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../bindings/bindings.dart';
import '../types/types.dart';

Pointer<Void> marshalConfig(Arena arena, EphemerisConfig config) {
  final c = arena<SweConfig>();
  c.ref.ephemerisSource = config.ephemerisSource.value;
  c.ref.ephePath = config.ephePath != null
      ? config.ephePath!.toNativeUtf8(allocator: arena)
      : nullptr;
  c.ref.jplFilename = config.jplFilename != null
      ? config.jplFilename!.toNativeUtf8(allocator: arena)
      : nullptr;
  c.ref.leapSecondsFile = config.leapSecondsFile != null
      ? config.leapSecondsFile!.toNativeUtf8(allocator: arena)
      : nullptr;
  c.ref.hasSidereal = config.siderealMode != null;
  var sidBits = config.siderealBits.value;
  if (config.siderealT0IsUt) sidBits |= SiderealBits.userUt.value;
  c.ref.sidMode = (config.siderealMode?.value ?? 0) | sidBits;
  c.ref.sidT0 = config.siderealT0;
  c.ref.sidAyanT0 = config.siderealAyanT0;
  c.ref.hasTopo = config.topographic != null;
  c.ref.geolon = config.topographic?.longitude ?? 0;
  c.ref.geolat = config.topographic?.latitude ?? 0;
  c.ref.altitude = config.topographic?.altitude ?? 0;
  c.ref.tidalAcceleration = config.tidalAcceleration ?? double.nan;
  c.ref.deltaTUserdef = config.deltaTUserdef ?? double.nan;

  if (config.asteroidNumbers.isNotEmpty) {
    final arr = arena<Int32>(config.asteroidNumbers.length);
    for (var i = 0; i < config.asteroidNumbers.length; i++) {
      arr[i] = config.asteroidNumbers[i];
    }
    c.ref.asteroidNumbers = arr;
    c.ref.asteroidNumbersLen = config.asteroidNumbers.length;
  } else {
    c.ref.asteroidNumbers = nullptr;
    c.ref.asteroidNumbersLen = 0;
  }

  if (config.planetMoonNumbers.isNotEmpty) {
    final arr = arena<Int32>(config.planetMoonNumbers.length);
    for (var i = 0; i < config.planetMoonNumbers.length; i++) {
      arr[i] = config.planetMoonNumbers[i];
    }
    c.ref.planetMoonNumbers = arr;
    c.ref.planetMoonNumbersLen = config.planetMoonNumbers.length;
  } else {
    c.ref.planetMoonNumbers = nullptr;
    c.ref.planetMoonNumbersLen = 0;
  }

  if (config.extraLeapSeconds.isNotEmpty) {
    final arr = arena<Int32>(config.extraLeapSeconds.length);
    for (var i = 0; i < config.extraLeapSeconds.length; i++) {
      arr[i] = config.extraLeapSeconds[i];
    }
    c.ref.extraLeapSeconds = arr;
    c.ref.extraLeapSecondsLen = config.extraLeapSeconds.length;
  } else {
    c.ref.extraLeapSeconds = nullptr;
    c.ref.extraLeapSecondsLen = 0;
  }

  c.ref.astroModelPrecLongterm = config.astroModels?.precLongterm.value ?? 0;
  c.ref.astroModelPrecShortterm = config.astroModels?.precShortterm.value ?? 0;
  c.ref.astroModelNutation = config.astroModels?.nutation.value ?? 0;
  c.ref.astroModelBias = config.astroModels?.bias.value ?? 0;
  c.ref.astroModelJplhor = config.astroModels?.jplhorMode.value ?? 0;
  c.ref.astroModelJplhora = config.astroModels?.jplhoraMode.value ?? 0;
  c.ref.astroModelSiderealTime = config.astroModels?.siderealTime.value ?? 0;
  c.ref.astroModelDeltaT = config.astroModels?.deltaT.value ?? 0;
  return c.cast<Void>();
}

({Pointer<Double> geopos, Pointer<Void> sidMode}) marshalPerCallOverrides(
  Arena arena,
  EphemerisConfig config,
) {
  Pointer<Double> geopos = nullptr;
  if (config.topographic case final topo?) {
    geopos = arena<Double>(3);
    geopos[0] = topo.longitude;
    geopos[1] = topo.latitude;
    geopos[2] = topo.altitude;
  }

  Pointer<Void> sidMode = nullptr;
  if (config.siderealMode != null) {
    final sm = arena<SweSidMode>();
    var bits = config.siderealBits.value;
    if (config.siderealT0IsUt) bits |= SiderealBits.userUt.value;
    sm.ref.sidMode = config.siderealMode!.value | bits;
    sm.ref.t0 = config.siderealT0;
    sm.ref.ayanT0 = config.siderealAyanT0;
    sidMode = sm.cast<Void>();
  }

  return (geopos: geopos, sidMode: sidMode);
}
