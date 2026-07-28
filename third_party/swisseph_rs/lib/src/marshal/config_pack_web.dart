// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:wasm_ffi/ffi.dart';
import 'package:wasm_ffi/ffi_utils.dart';

import '../types/types.dart';

// SweConfig layout for wasm32-unknown-emscripten (#[repr(C)]):
//
// offset  type       field
// 0       i32        ephemerisSource
// 4       ptr(4)     ephePath
// 8       ptr(4)     jplFilename
// 12      ptr(4)     leapSecondsFile
// 16      bool(1)    hasSidereal  (+3 pad)
// 20      i32        sidMode
// 24      f64        sidT0
// 32      f64        sidAyanT0
// 40      bool(1)    hasTopo  (+7 pad to align f64)
// 48      f64        geolon
// 56      f64        geolat
// 64      f64        altitude
// 72      f64        tidalAcceleration
// 80      f64        deltaTUserdef
// 88      ptr(4)     asteroidNumbers
// 92      u32(size)  asteroidNumbersLen
// 96      ptr(4)     planetMoonNumbers
// 100     u32(size)  planetMoonNumbersLen
// 104     ptr(4)     extraLeapSeconds
// 108     u32(size)  extraLeapSecondsLen
// 112     i32        astroModelPrecLongterm
// 116     i32        astroModelPrecShortterm
// 120     i32        astroModelNutation
// 124     i32        astroModelBias
// 128     i32        astroModelJplhor
// 132     i32        astroModelJplhora
// 136     i32        astroModelSiderealTime
// 140     i32        astroModelDeltaT
// total: 144 bytes (alignment 8)

const _sweConfigSize = 144;

void _setI32(Pointer<Uint8> base, int offset, int value) {
  base.cast<Int32>().elementAt(offset ~/ 4).value = value;
}

void _setU32(Pointer<Uint8> base, int offset, int value) {
  base.cast<Uint32>().elementAt(offset ~/ 4).value = value;
}

void _setF64(Pointer<Uint8> base, int offset, double value) {
  base.cast<Double>().elementAt(offset ~/ 8).value = value;
}

void _setPtr(Pointer<Uint8> base, int offset, Pointer<Void> value) {
  base.cast<Uint32>().elementAt(offset ~/ 4).value = value.address;
}

void _setBool(Pointer<Uint8> base, int offset, bool value) {
  base[offset] = value ? 1 : 0;
}

Pointer<Void> marshalConfig(Arena arena, EphemerisConfig config) {
  final c = arena<Uint8>(_sweConfigSize);
  for (var i = 0; i < _sweConfigSize; i++) {
    c[i] = 0;
  }

  _setI32(c, 0, config.ephemerisSource.value);
  _setPtr(
    c,
    4,
    config.ephePath != null
        ? config.ephePath!.toNativeUtf8(allocator: arena).cast<Void>()
        : nullptr,
  );
  _setPtr(
    c,
    8,
    config.jplFilename != null
        ? config.jplFilename!.toNativeUtf8(allocator: arena).cast<Void>()
        : nullptr,
  );
  _setPtr(
    c,
    12,
    config.leapSecondsFile != null
        ? config.leapSecondsFile!.toNativeUtf8(allocator: arena).cast<Void>()
        : nullptr,
  );
  _setBool(c, 16, config.siderealMode != null);
  var sidBits = config.siderealBits.value;
  if (config.siderealT0IsUt) sidBits |= SiderealBits.userUt.value;
  _setI32(c, 20, (config.siderealMode?.value ?? 0) | sidBits);
  _setF64(c, 24, config.siderealT0);
  _setF64(c, 32, config.siderealAyanT0);
  _setBool(c, 40, config.topographic != null);
  _setF64(c, 48, config.topographic?.longitude ?? 0);
  _setF64(c, 56, config.topographic?.latitude ?? 0);
  _setF64(c, 64, config.topographic?.altitude ?? 0);
  _setF64(c, 72, config.tidalAcceleration ?? double.nan);
  _setF64(c, 80, config.deltaTUserdef ?? double.nan);

  if (config.asteroidNumbers.isNotEmpty) {
    final arr = arena<Int32>(config.asteroidNumbers.length);
    for (var i = 0; i < config.asteroidNumbers.length; i++) {
      arr[i] = config.asteroidNumbers[i];
    }
    _setPtr(c, 88, arr.cast<Void>());
    _setU32(c, 92, config.asteroidNumbers.length);
  }

  if (config.planetMoonNumbers.isNotEmpty) {
    final arr = arena<Int32>(config.planetMoonNumbers.length);
    for (var i = 0; i < config.planetMoonNumbers.length; i++) {
      arr[i] = config.planetMoonNumbers[i];
    }
    _setPtr(c, 96, arr.cast<Void>());
    _setU32(c, 100, config.planetMoonNumbers.length);
  }

  if (config.extraLeapSeconds.isNotEmpty) {
    final arr = arena<Int32>(config.extraLeapSeconds.length);
    for (var i = 0; i < config.extraLeapSeconds.length; i++) {
      arr[i] = config.extraLeapSeconds[i];
    }
    _setPtr(c, 104, arr.cast<Void>());
    _setU32(c, 108, config.extraLeapSeconds.length);
  }

  _setI32(c, 112, config.astroModels?.precLongterm.value ?? 0);
  _setI32(c, 116, config.astroModels?.precShortterm.value ?? 0);
  _setI32(c, 120, config.astroModels?.nutation.value ?? 0);
  _setI32(c, 124, config.astroModels?.bias.value ?? 0);
  _setI32(c, 128, config.astroModels?.jplhorMode.value ?? 0);
  _setI32(c, 132, config.astroModels?.jplhoraMode.value ?? 0);
  _setI32(c, 136, config.astroModels?.siderealTime.value ?? 0);
  _setI32(c, 140, config.astroModels?.deltaT.value ?? 0);
  return c.cast<Void>();
}

// SweSidMode layout for wasm32:
// offset 0: i32 sidMode (4 bytes, +4 pad)
// offset 8: f64 t0
// offset 16: f64 ayanT0
// total: 24 bytes
const _sweSidModeSize = 24;

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
    final sm = arena<Uint8>(_sweSidModeSize);
    for (var i = 0; i < _sweSidModeSize; i++) {
      sm[i] = 0;
    }
    var bits = config.siderealBits.value;
    if (config.siderealT0IsUt) bits |= SiderealBits.userUt.value;
    _setI32(sm, 0, config.siderealMode!.value | bits);
    _setF64(sm, 8, config.siderealT0);
    _setF64(sm, 16, config.siderealAyanT0);
    sidMode = sm.cast<Void>();
  }

  return (geopos: geopos, sidMode: sidMode);
}
