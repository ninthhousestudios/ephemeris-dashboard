// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../ffi_types.dart';

import '../bindings/bindings.dart';
import '../types/types.dart';
import 'config_pack.dart' as config_pack;

// ---------------------------------------------------------------------------
// Error handling
// ---------------------------------------------------------------------------

const _errBufSize = 256;

/// Check an FFI return code; throw on negative.
void _checkResult(int code, Pointer<Utf8> errBuf) {
  if (code < 0) {
    final msg = errBuf.toDartString();
    throw exceptionFromCode(code, msg);
  }
}

/// rise_trans FFI returns raw -2 for circumpolar (C convention),
/// not SweErrorCode::CircumpolarBody (-11).
void _checkRiseTransResult(int code, Pointer<Utf8> errBuf) {
  if (code == -2) {
    throw CircumpolarBodyException(errBuf.toDartString());
  }
  _checkResult(code, errBuf);
}

// ---------------------------------------------------------------------------
// Config marshaling — delegated to config_pack barrel (Struct-based on
// native, byte-offset packing on web where wasm_ffi has no Struct support).
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Result unmarshaling
// ---------------------------------------------------------------------------

/// Unpack a 6-element double array + flags into a [CalcResult].
CalcResult unmarshalCalcResult(Pointer<Double> xx, int flagsUsed) {
  return CalcResult(
    longitude: xx[0],
    latitude: xx[1],
    distance: xx[2],
    longitudeSpeed: xx[3],
    latitudeSpeed: xx[4],
    distanceSpeed: xx[5],
    flagsUsed: CalcFlags(flagsUsed),
  );
}

// ---------------------------------------------------------------------------
// High-level FFI call wrappers (the only Dart↔FFI meeting point).
// ---------------------------------------------------------------------------

/// Create an ephemeris handle from config. Throws [SweException] on failure.
Pointer<Void> createHandle(EphemerisConfig config) {
  return using((arena) {
    final sweConfig = config_pack.marshalConfig(arena, config);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final out = arena<Pointer<Void>>();
    final code = swissephNew(sweConfig, out, errBuf, _errBufSize);
    _checkResult(code, errBuf);
    return out.value;
  });
}

/// Clone a handle's refcount. Returns a new handle sharing the same engine.
Pointer<Void> shareHandle(Pointer<Void> handle) {
  return using((arena) {
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final out = arena<Pointer<Void>>();
    final code = swissephShare(handle, out, errBuf, _errBufSize);
    _checkResult(code, errBuf);
    return out.value;
  });
}

/// Release an ephemeris handle. Null-safe on the native side.
void freeHandle(Pointer<Void> handle) {
  swissephFree(handle);
}

/// Call `swisseph_calc_ut` and return a typed [CalcResult].
CalcResult calcUt(Pointer<Void> handle, double tjdUt, int ipl, int iflag) {
  return using((arena) {
    final xx = arena<Double>(6);
    final flagsUsed = arena<Int32>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephCalcUt(
      handle,
      tjdUt,
      ipl,
      iflag,
      nullptr,
      nullptr,
      xx,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return unmarshalCalcResult(xx, flagsUsed.value);
  });
}

/// Call `swisseph_calc_ut` with per-call config overrides.
CalcResult calcUtWithConfig(
  Pointer<Void> handle,
  double tjdUt,
  int ipl,
  int iflag,
  EphemerisConfig config,
) {
  return using((arena) {
    final xx = arena<Double>(6);
    final flagsUsed = arena<Int32>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final (:geopos, :sidMode) = config_pack.marshalPerCallOverrides(
      arena,
      config,
    );
    final code = swissephCalcUt(
      handle,
      tjdUt,
      ipl,
      iflag,
      geopos,
      sidMode,
      xx,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return unmarshalCalcResult(xx, flagsUsed.value);
  });
}

/// Call `swisseph_calc` and return a typed [CalcResult].
CalcResult calc(Pointer<Void> handle, double tjdEt, int ipl, int iflag) {
  return using((arena) {
    final xx = arena<Double>(6);
    final flagsUsed = arena<Int32>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephCalc(
      handle,
      tjdEt,
      ipl,
      iflag,
      nullptr,
      nullptr,
      xx,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return unmarshalCalcResult(xx, flagsUsed.value);
  });
}

/// Call `swisseph_calc` with per-call config overrides.
CalcResult calcWithConfig(
  Pointer<Void> handle,
  double tjdEt,
  int ipl,
  int iflag,
  EphemerisConfig config,
) {
  return using((arena) {
    final xx = arena<Double>(6);
    final flagsUsed = arena<Int32>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final (:geopos, :sidMode) = config_pack.marshalPerCallOverrides(
      arena,
      config,
    );
    final code = swissephCalc(
      handle,
      tjdEt,
      ipl,
      iflag,
      geopos,
      sidMode,
      xx,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return unmarshalCalcResult(xx, flagsUsed.value);
  });
}

/// Call `swisseph_calc_pctr` and return a typed [CalcResult].
CalcResult calcPctr(
  Pointer<Void> handle,
  double tjdEt,
  int ipl,
  int iplctr,
  int iflag,
) {
  return using((arena) {
    final xx = arena<Double>(6);
    final flagsUsed = arena<Int32>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephCalcPctr(
      handle,
      tjdEt,
      ipl,
      iplctr,
      iflag,
      xx,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return unmarshalCalcResult(xx, flagsUsed.value);
  });
}

/// Read the engine version string from the native library.
String engineVersion() {
  return swissephVersion().toDartString();
}

// ---------------------------------------------------------------------------
// Date/time free functions
// ---------------------------------------------------------------------------

/// Call `swisseph_julday`.
double julday(int year, int month, int day, double hour, int gregflag) {
  return swissephJulday(year, month, day, hour, gregflag);
}

/// Call `swisseph_revjul` and return components.
({int year, int month, int day, double hour}) revjul(double jd, int gregflag) {
  return using((arena) {
    final y = arena<Int32>();
    final m = arena<Int32>();
    final d = arena<Int32>();
    final h = arena<Double>();
    swissephRevjul(jd, gregflag, y, m, d, h);
    return (year: y.value, month: m.value, day: d.value, hour: h.value);
  });
}

/// Call `swisseph_date_conversion`. Throws on invalid date.
double dateConversion(int year, int month, int day, double hour, int cal) {
  return using((arena) {
    final tjd = arena<Double>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephDateConversion(
      year,
      month,
      day,
      hour,
      cal,
      tjd,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return tjd.value;
  });
}

/// Call `swisseph_day_of_week`.
int dayOfWeek(double jd) {
  return swissephDayOfWeek(jd);
}

/// Call `swisseph_utc_time_zone` and return [UtcComponents].
UtcComponents utcTimeZone(
  int year,
  int month,
  int day,
  int hour,
  int minute,
  double second,
  double tzOffset,
) {
  return using((arena) {
    final oy = arena<Int32>();
    final om = arena<Int32>();
    final od = arena<Int32>();
    final oh = arena<Int32>();
    final omin = arena<Int32>();
    final osec = arena<Double>();
    swissephUtcTimeZone(
      year,
      month,
      day,
      hour,
      minute,
      second,
      tzOffset,
      oy,
      om,
      od,
      oh,
      omin,
      osec,
    );
    return UtcComponents(
      year: oy.value,
      month: om.value,
      day: od.value,
      hour: oh.value,
      minute: omin.value,
      second: osec.value,
    );
  });
}

/// Call `swisseph_utc_to_jd` and return [UtcToJd].
UtcToJd utcToJd(
  Pointer<Void> handle,
  int year,
  int month,
  int day,
  int hour,
  int min,
  double sec,
  int gregflag,
) {
  return using((arena) {
    final dret = arena<Double>(2);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephUtcToJd(
      handle,
      year,
      month,
      day,
      hour,
      min,
      sec,
      gregflag,
      dret,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return UtcToJd(tt: JdTt(dret[0]), ut1: JdUt1(dret[1]));
  });
}

/// Call `swisseph_jdet_to_utc` and return [UtcComponents].
UtcComponents jdetToUtc(Pointer<Void> handle, double tjdEt, int gregflag) {
  return using((arena) {
    final y = arena<Int32>();
    final m = arena<Int32>();
    final d = arena<Int32>();
    final h = arena<Int32>();
    final min = arena<Int32>();
    final sec = arena<Double>();
    swissephJdetToUtc(handle, tjdEt, gregflag, y, m, d, h, min, sec);
    return UtcComponents(
      year: y.value,
      month: m.value,
      day: d.value,
      hour: h.value,
      minute: min.value,
      second: sec.value,
    );
  });
}

/// Call `swisseph_jdut1_to_utc` and return [UtcComponents].
UtcComponents jdut1ToUtc(Pointer<Void> handle, double tjdUt, int gregflag) {
  return using((arena) {
    final y = arena<Int32>();
    final m = arena<Int32>();
    final d = arena<Int32>();
    final h = arena<Int32>();
    final min = arena<Int32>();
    final sec = arena<Double>();
    swissephJdut1ToUtc(handle, tjdUt, gregflag, y, m, d, h, min, sec);
    return UtcComponents(
      year: y.value,
      month: m.value,
      day: d.value,
      hour: h.value,
      minute: min.value,
      second: sec.value,
    );
  });
}

/// Call `swisseph_deltat`.
double deltaT(Pointer<Void> handle, double tjdUt) {
  final result = swissephDeltat(handle, tjdUt);
  if (result.isNaN) {
    throw const CErrorException('swisseph_deltat returned NaN');
  }
  return result;
}

/// Call `swisseph_sidtime`.
double siderealTime(Pointer<Void> handle, double tjdUt) {
  final result = swissephSidtime(handle, tjdUt);
  if (result.isNaN) {
    throw const CErrorException('swisseph_sidtime returned NaN');
  }
  return result;
}

/// Call `swisseph_sidtime0`.
double siderealTime0(
  Pointer<Void> handle,
  double tjdUt,
  double eps,
  double nut,
) {
  return swissephSidtime0(handle, tjdUt, eps, nut);
}

/// Call `swisseph_time_equ`.
double timeEqu(Pointer<Void> handle, double tjdUt) {
  return using((arena) {
    final e = arena<Double>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephTimeEqu(handle, tjdUt, e, errBuf, _errBufSize);
    _checkResult(code, errBuf);
    return e.value;
  });
}

/// Call `swisseph_lmt_to_lat`.
double lmtToLat(Pointer<Void> handle, double tjdLmt, double geolon) {
  return using((arena) {
    final tjdLat = arena<Double>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephLmtToLat(
      handle,
      tjdLmt,
      geolon,
      tjdLat,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return tjdLat.value;
  });
}

/// Call `swisseph_lat_to_lmt`.
double latToLmt(Pointer<Void> handle, double tjdLat, double geolon) {
  return using((arena) {
    final tjdLmt = arena<Double>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephLatToLmt(
      handle,
      tjdLat,
      geolon,
      tjdLmt,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return tjdLmt.value;
  });
}

/// Call `swisseph_get_planet_name`.
String getPlanetName(Pointer<Void> handle, int ipl) {
  return using((arena) {
    final buf = arena<Uint8>(256).cast<Utf8>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephGetPlanetName(
      handle,
      ipl,
      buf,
      256,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return buf.toDartString();
  });
}

/// Call `swisseph_split_deg` and return [DegreeParts].
DegreeParts splitDegrees(double ddeg, int roundflag) {
  return using((arena) {
    final deg = arena<Int32>();
    final min = arena<Int32>();
    final sec = arena<Int32>();
    final secfr = arena<Double>();
    final sign = arena<Int32>();
    swissephSplitDeg(ddeg, roundflag, deg, min, sec, secfr, sign);
    return DegreeParts(
      degrees: deg.value,
      minutes: min.value,
      seconds: sec.value,
      secondFraction: secfr.value,
      sign: sign.value,
    );
  });
}

// ---------------------------------------------------------------------------
// Houses
// ---------------------------------------------------------------------------

/// Unmarshal a 10-element ascmc array into [AscMc].
AscMc _unmarshalAscMc(Pointer<Double> p) {
  return AscMc(
    ascendant: p[0],
    mc: p[1],
    armc: p[2],
    vertex: p[3],
    equatorialAscendant: p[4],
    coascendantKoch: p[5],
    coascendantMunkasey: p[6],
    polarAscendant: p[7],
  );
}

/// Unmarshal cusps from a native 37-element buffer into a Dart list.
/// The list length is 37 for Gauquelin (hsys 0x47), 13 otherwise.
List<double> _unmarshalCusps(Pointer<Double> p, int hsys) {
  final len = hsys == 0x47 ? 37 : 13;
  return [for (var i = 0; i < len; i++) p[i]];
}

/// Call `swisseph_houses_ex2` and return a typed [HouseResult].
HouseResult housesEx2(
  Pointer<Void> handle,
  double tjdUt,
  int iflag,
  double geolat,
  double geolon,
  int hsys,
) {
  return using((arena) {
    final cusps = arena<Double>(37);
    final ascmc = arena<Double>(10);
    final cuspSpeed = arena<Double>(37);
    final ascmcSpeed = arena<Double>(10);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephHousesEx2(
      handle,
      tjdUt,
      iflag,
      geolat,
      geolon,
      hsys,
      cusps,
      ascmc,
      cuspSpeed,
      ascmcSpeed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return HouseResult(
      cusps: _unmarshalCusps(cusps, hsys),
      cuspSpeeds: _unmarshalCusps(cuspSpeed, hsys),
      ascmc: _unmarshalAscMc(ascmc),
      ascmcSpeeds: _unmarshalAscMc(ascmcSpeed),
    );
  });
}

/// Call `swisseph_houses_armc_ex2` (handle-free) and return a [HouseResult].
HouseResult housesArmcEx2(
  double armc,
  double geolat,
  double eps,
  int hsys, {
  double? sundec,
}) {
  return using((arena) {
    final cusps = arena<Double>(37);
    final ascmc = arena<Double>(10);
    final cuspSpeed = arena<Double>(37);
    final ascmcSpeed = arena<Double>(10);
    final Pointer<Double> sundecPtr = sundec != null
        ? (arena<Double>()..value = sundec)
        : nullptr;
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephHousesArmcEx2(
      armc,
      geolat,
      eps,
      hsys,
      sundecPtr,
      cusps,
      ascmc,
      cuspSpeed,
      ascmcSpeed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return HouseResult(
      cusps: _unmarshalCusps(cusps, hsys),
      cuspSpeeds: _unmarshalCusps(cuspSpeed, hsys),
      ascmc: _unmarshalAscMc(ascmc),
      ascmcSpeeds: _unmarshalAscMc(ascmcSpeed),
    );
  });
}

/// Call `swisseph_house_pos` (handle-free) and return the house position.
double housePos(
  double armc,
  double geolat,
  double eps,
  int hsys,
  double bodyLon,
  double bodyLat, {
  double? sundec,
}) {
  return using((arena) {
    final xpin = arena<Double>(2);
    xpin[0] = bodyLon;
    xpin[1] = bodyLat;
    final Pointer<Double> sundecPtr = sundec != null
        ? (arena<Double>()..value = sundec)
        : nullptr;
    final hpos = arena<Double>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephHousePos(
      armc,
      geolat,
      eps,
      hsys,
      xpin,
      sundecPtr,
      hpos,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return hpos.value;
  });
}

/// Call `swisseph_house_name` (handle-free) and return the name string.
String houseName(int hsys) {
  return using((arena) {
    final buf = arena<Uint8>(256).cast<Utf8>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephHouseName(hsys, buf, 256, errBuf, _errBufSize);
    _checkResult(code, errBuf);
    return buf.toDartString();
  });
}

/// Call `swisseph_gauquelin_sector` and return the sector number.
double gauquelinSector(
  Pointer<Void> handle,
  double tjdUt,
  int ipl,
  String? starname,
  int iflag,
  int imeth,
  double geolon,
  double geolat,
  double geoalt,
  double atpress,
  double attemp,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final Pointer<Utf8> starnamePtr = starname != null
        ? starname.toNativeUtf8(allocator: arena)
        : nullptr;
    final dgsect = arena<Double>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephGauquelinSector(
      handle,
      tjdUt,
      ipl,
      starnamePtr,
      iflag,
      imeth,
      geopos,
      atpress,
      attemp,
      dgsect,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return dgsect.value;
  });
}

// ---------------------------------------------------------------------------
// Ayanamsa
// ---------------------------------------------------------------------------

/// Call `swisseph_get_ayanamsa_ex` and return ayanamsa + flags used.
({double ayanamsa, CalcFlags flagsUsed}) getAyanamsaEx(
  Pointer<Void> handle,
  double tjdEt,
  int iflag,
) {
  return using((arena) {
    final daya = arena<Double>();
    final pFlags = arena<Int32>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephGetAyanamsaEx(
      handle,
      tjdEt,
      iflag,
      nullptr, // use handle's configured sidereal mode
      daya,
      pFlags,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return (ayanamsa: daya.value, flagsUsed: CalcFlags(pFlags.value));
  });
}

/// Call `swisseph_get_ayanamsa_ex` with per-call sidereal mode override.
({double ayanamsa, CalcFlags flagsUsed}) getAyanamsaExWithConfig(
  Pointer<Void> handle,
  double tjdEt,
  int iflag,
  EphemerisConfig config,
) {
  return using((arena) {
    final daya = arena<Double>();
    final pFlags = arena<Int32>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final (:geopos, :sidMode) = config_pack.marshalPerCallOverrides(
      arena,
      config,
    );
    // geopos unused — ayanamsa only needs sidereal mode override
    final _ = geopos;
    final code = swissephGetAyanamsaEx(
      handle,
      tjdEt,
      iflag,
      sidMode,
      daya,
      pFlags,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return (ayanamsa: daya.value, flagsUsed: CalcFlags(pFlags.value));
  });
}

/// Call `swisseph_get_ayanamsa_ex_ut` and return ayanamsa + flags used.
({double ayanamsa, CalcFlags flagsUsed}) getAyanamsaUt(
  Pointer<Void> handle,
  double tjdUt,
  int iflag,
) {
  return using((arena) {
    final daya = arena<Double>();
    final pFlags = arena<Int32>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephGetAyanamsaExUt(
      handle,
      tjdUt,
      iflag,
      nullptr,
      daya,
      pFlags,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return (ayanamsa: daya.value, flagsUsed: CalcFlags(pFlags.value));
  });
}

/// Call `swisseph_get_ayanamsa` (legacy, no flags).
double getAyanamsa(Pointer<Void> handle, double tjdEt) {
  final result = swissephGetAyanamsa(handle, tjdEt, nullptr);
  if (result.isNaN) {
    throw const CErrorException('swisseph_get_ayanamsa returned NaN');
  }
  return result;
}

/// Call `swisseph_get_ayanamsa_name` (handle-free) and return the name.
String getAyanamsaName(int sidModeRaw) {
  return using((arena) {
    final buf = arena<Uint8>(256).cast<Utf8>();
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephGetAyanamsaName(
      sidModeRaw,
      buf,
      256,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return buf.toDartString();
  });
}

// ---------------------------------------------------------------------------
// Eclipses & occultations
// ---------------------------------------------------------------------------

EclipseHow _unmarshalEclipseHow(Pointer<Double> attr, EclipseFlags flags) {
  return EclipseHow(
    magnitude: attr[0],
    diameterRatio: attr[1],
    obscuration: attr[2],
    coreDiameterKm: attr[3],
    azimuth: attr[4],
    trueAltitude: attr[5],
    apparentAltitude: attr[6],
    elongation: attr[7],
    nasaMagnitude: attr[8],
    sarosSeries: attr[9],
    sarosMember: attr[10],
    flags: flags,
  );
}

LunarEclipseHow _unmarshalLunarEclipseHow(
  Pointer<Double> attr,
  EclipseFlags flags,
) {
  return LunarEclipseHow(
    umbralMagnitude: attr[0],
    penumbralMagnitude: attr[1],
    azimuth: attr[4],
    trueAltitude: attr[5],
    apparentAltitude: attr[6],
    distanceFromOpposition: attr[7],
    sarosSeries: attr[9],
    sarosMember: attr[10],
    flags: flags,
  );
}

SolarEclipseGlobal solEclipseWhenGlob(
  Pointer<Void> handle,
  double tjdStart,
  int ifl,
  int ifltype,
  bool backward,
) {
  return using((arena) {
    final tret = arena<Double>(10);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephSolEclipseWhenGlob(
      handle,
      tjdStart,
      ifl,
      ifltype,
      backward ? 1 : 0,
      tret,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return SolarEclipseGlobal(
      timeMaximum: tret[0],
      timeRaConjunction: tret[1],
      timeBegin: tret[2],
      timeEnd: tret[3],
      timeTotalityBegin: tret[4],
      timeTotalityEnd: tret[5],
      timeCenterlineBegin: tret[6],
      timeCenterlineEnd: tret[7],
      flags: EclipseFlags(code),
    );
  });
}

SolarEclipseLocal solEclipseWhenLoc(
  Pointer<Void> handle,
  double tjdStart,
  int ifl,
  double geolon,
  double geolat,
  double geoalt,
  bool backward,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final tret = arena<Double>(10);
    final attr = arena<Double>(20);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephSolEclipseWhenLoc(
      handle,
      tjdStart,
      ifl,
      geopos,
      backward ? 1 : 0,
      tret,
      attr,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    final flags = EclipseFlags(code);
    return SolarEclipseLocal(
      timeMaximum: tret[0],
      timeFirstContact: tret[1],
      timeSecondContact: tret[2],
      timeThirdContact: tret[3],
      timeFourthContact: tret[4],
      timeSunrise: tret[5],
      timeSunset: tret[6],
      attr: _unmarshalEclipseHow(attr, flags),
      flags: flags,
    );
  });
}

EclipseWhere solEclipseWhere(Pointer<Void> handle, double tjdUt, int ifl) {
  return using((arena) {
    final geopos = arena<Double>(10);
    final attr = arena<Double>(20);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephSolEclipseWhere(
      handle,
      tjdUt,
      ifl,
      geopos,
      attr,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return EclipseWhere(
      centralLongitude: geopos[0],
      centralLatitude: geopos[1],
      coreDiameterKm: geopos[2],
      penumbraDiameterKm: geopos[3],
      shadowAxisDistanceKm: geopos[4],
      umbraDiameterFundamentalKm: geopos[5],
      penumbraDiameterFundamentalKm: geopos[6],
      cosUmbraHalfAngle: geopos[7],
      cosPenumbraHalfAngle: geopos[8],
      flags: EclipseFlags(code),
    );
  });
}

EclipseHow solEclipseHow(
  Pointer<Void> handle,
  double tjdUt,
  int ifl,
  double geolon,
  double geolat,
  double geoalt,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final attr = arena<Double>(20);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephSolEclipseHow(
      handle,
      tjdUt,
      ifl,
      geopos,
      attr,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return _unmarshalEclipseHow(attr, EclipseFlags(code));
  });
}

LunarEclipseHow lunEclipseHow(
  Pointer<Void> handle,
  double tjdUt,
  int ifl,
  double geolon,
  double geolat,
  double geoalt,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final attr = arena<Double>(20);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephLunEclipseHow(
      handle,
      tjdUt,
      ifl,
      geopos,
      attr,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return _unmarshalLunarEclipseHow(attr, EclipseFlags(code));
  });
}

LunarEclipseGlobal lunEclipseWhen(
  Pointer<Void> handle,
  double tjdStart,
  int ifl,
  int ifltype,
  bool backward,
) {
  return using((arena) {
    final tret = arena<Double>(10);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephLunEclipseWhen(
      handle,
      tjdStart,
      ifl,
      ifltype,
      backward ? 1 : 0,
      tret,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return LunarEclipseGlobal(
      timeMaximum: tret[0],
      timePartialBegin: tret[2],
      timePartialEnd: tret[3],
      timeTotalityBegin: tret[4],
      timeTotalityEnd: tret[5],
      timePenumbralBegin: tret[6],
      timePenumbralEnd: tret[7],
      flags: EclipseFlags(code),
    );
  });
}

LunarEclipseLocal lunEclipseWhenLoc(
  Pointer<Void> handle,
  double tjdStart,
  int ifl,
  double geolon,
  double geolat,
  double geoalt,
  bool backward,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final tret = arena<Double>(10);
    final attr = arena<Double>(20);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephLunEclipseWhenLoc(
      handle,
      tjdStart,
      ifl,
      geopos,
      backward ? 1 : 0,
      tret,
      attr,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    final flags = EclipseFlags(code);
    return LunarEclipseLocal(
      timeMaximum: tret[0],
      timePartialBegin: tret[2],
      timePartialEnd: tret[3],
      timeTotalityBegin: tret[4],
      timeTotalityEnd: tret[5],
      timePenumbralBegin: tret[6],
      timePenumbralEnd: tret[7],
      timeMoonrise: tret[8],
      timeMoonset: tret[9],
      attr: _unmarshalLunarEclipseHow(attr, flags),
      flags: flags,
    );
  });
}

EclipseWhere lunOccultWhere(
  Pointer<Void> handle,
  double tjdUt,
  int ipl,
  String? starname,
  int ifl,
) {
  return using((arena) {
    final geopos = arena<Double>(10);
    final attr = arena<Double>(20);
    final Pointer<Utf8> starnamePtr = starname != null
        ? starname.toNativeUtf8(allocator: arena)
        : nullptr;
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephLunOccultWhere(
      handle,
      tjdUt,
      ipl,
      starnamePtr,
      ifl,
      geopos,
      attr,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return EclipseWhere(
      centralLongitude: geopos[0],
      centralLatitude: geopos[1],
      coreDiameterKm: geopos[2],
      penumbraDiameterKm: geopos[3],
      shadowAxisDistanceKm: geopos[4],
      umbraDiameterFundamentalKm: geopos[5],
      penumbraDiameterFundamentalKm: geopos[6],
      cosUmbraHalfAngle: geopos[7],
      cosPenumbraHalfAngle: geopos[8],
      flags: EclipseFlags(code),
    );
  });
}

OccultGlobal lunOccultWhenGlob(
  Pointer<Void> handle,
  double tjdStart,
  int ipl,
  String? starname,
  int ifl,
  int ifltype,
  bool backward,
) {
  return using((arena) {
    final tret = arena<Double>(10);
    final Pointer<Utf8> starnamePtr = starname != null
        ? starname.toNativeUtf8(allocator: arena)
        : nullptr;
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephLunOccultWhenGlob(
      handle,
      tjdStart,
      ipl,
      starnamePtr,
      ifl,
      ifltype,
      backward ? 1 : 0,
      tret,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return OccultGlobal(
      timeMaximum: tret[0],
      timeRaConjunction: tret[1],
      timeBegin: tret[2],
      timeEnd: tret[3],
      timeTotalityBegin: tret[4],
      timeTotalityEnd: tret[5],
      timeCenterlineBegin: tret[6],
      timeCenterlineEnd: tret[7],
      flags: EclipseFlags(code),
    );
  });
}

OccultLocal lunOccultWhenLoc(
  Pointer<Void> handle,
  double tjdStart,
  int ipl,
  String? starname,
  int ifl,
  double geolon,
  double geolat,
  double geoalt,
  bool backward,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final tret = arena<Double>(10);
    final attr = arena<Double>(20);
    final Pointer<Utf8> starnamePtr = starname != null
        ? starname.toNativeUtf8(allocator: arena)
        : nullptr;
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephLunOccultWhenLoc(
      handle,
      tjdStart,
      ipl,
      starnamePtr,
      ifl,
      geopos,
      backward ? 1 : 0,
      tret,
      attr,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    final flags = EclipseFlags(code);
    return OccultLocal(
      timeMaximum: tret[0],
      timeFirstContact: tret[1],
      timeSecondContact: tret[2],
      timeThirdContact: tret[3],
      timeFourthContact: tret[4],
      timeRise: tret[5],
      timeSet: tret[6],
      attr: _unmarshalEclipseHow(attr, flags),
      flags: flags,
    );
  });
}

// ---------------------------------------------------------------------------
// Rise/set & crossings (task /32)
// ---------------------------------------------------------------------------

RiseSetResult riseTrans(
  Pointer<Void> handle,
  double tjdUt,
  int ipl,
  String? starname,
  int epheflag,
  int rsmi,
  double geolon,
  double geolat,
  double geoalt,
  double atpress,
  double attemp,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final tret = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final starBuf = starname != null
        ? starname.toNativeUtf8(allocator: arena)
        : nullptr.cast<Utf8>();
    final code = swissephRiseTrans(
      handle,
      tjdUt,
      ipl,
      starBuf,
      epheflag,
      rsmi,
      geopos,
      atpress,
      attemp,
      tret,
      errBuf,
      _errBufSize,
    );
    _checkRiseTransResult(code, errBuf);
    return RiseSetResult(time: tret[0]);
  });
}

RiseSetResult riseTransTrueHor(
  Pointer<Void> handle,
  double tjdUt,
  int ipl,
  String? starname,
  int epheflag,
  int rsmi,
  double geolon,
  double geolat,
  double geoalt,
  double atpress,
  double attemp,
  double horhgt,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final tret = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final starBuf = starname != null
        ? starname.toNativeUtf8(allocator: arena)
        : nullptr.cast<Utf8>();
    final code = swissephRiseTransTrueHor(
      handle,
      tjdUt,
      ipl,
      starBuf,
      epheflag,
      rsmi,
      geopos,
      atpress,
      attemp,
      horhgt,
      tret,
      errBuf,
      _errBufSize,
    );
    _checkRiseTransResult(code, errBuf);
    return RiseSetResult(time: tret[0]);
  });
}

double solcross(Pointer<Void> handle, double x2cross, double tjdEt, int iflag) {
  return using((arena) {
    final jx = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephSolcross(
      handle,
      x2cross,
      tjdEt,
      iflag,
      jx,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return jx[0];
  });
}

double solcrossUt(
  Pointer<Void> handle,
  double x2cross,
  double tjdUt,
  int iflag,
) {
  return using((arena) {
    final jx = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephSolcrossUt(
      handle,
      x2cross,
      tjdUt,
      iflag,
      jx,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return jx[0];
  });
}

double mooncross(
  Pointer<Void> handle,
  double x2cross,
  double tjdEt,
  int iflag,
) {
  return using((arena) {
    final jx = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephMooncross(
      handle,
      x2cross,
      tjdEt,
      iflag,
      jx,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return jx[0];
  });
}

double mooncrossUt(
  Pointer<Void> handle,
  double x2cross,
  double tjdUt,
  int iflag,
) {
  return using((arena) {
    final jx = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephMooncrossUt(
      handle,
      x2cross,
      tjdUt,
      iflag,
      jx,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return jx[0];
  });
}

MoonCrossing mooncrossNode(Pointer<Void> handle, double tjdEt, int iflag) {
  return using((arena) {
    final xlon = arena<Double>(1);
    final xlat = arena<Double>(1);
    final jx = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephMooncrossNode(
      handle,
      tjdEt,
      iflag,
      xlon,
      xlat,
      jx,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return MoonCrossing(jd: jx[0], longitude: xlon[0], latitude: xlat[0]);
  });
}

MoonCrossing mooncrossNodeUt(Pointer<Void> handle, double tjdUt, int iflag) {
  return using((arena) {
    final xlon = arena<Double>(1);
    final xlat = arena<Double>(1);
    final jx = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephMooncrossNodeUt(
      handle,
      tjdUt,
      iflag,
      xlon,
      xlat,
      jx,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return MoonCrossing(jd: jx[0], longitude: xlon[0], latitude: xlat[0]);
  });
}

double helioCross(
  Pointer<Void> handle,
  int ipl,
  double x2cross,
  double tjdEt,
  int iflag,
  int dir,
) {
  return using((arena) {
    final jx = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephHelioCross(
      handle,
      ipl,
      x2cross,
      tjdEt,
      iflag,
      dir,
      jx,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return jx[0];
  });
}

double helioCrossUt(
  Pointer<Void> handle,
  int ipl,
  double x2cross,
  double tjdUt,
  int iflag,
  int dir,
) {
  return using((arena) {
    final jx = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephHelioCrossUt(
      handle,
      ipl,
      x2cross,
      tjdUt,
      iflag,
      dir,
      jx,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return jx[0];
  });
}

// ---------------------------------------------------------------------------
// Phenomena, orbital, nodes/apsides (task /33)
// ---------------------------------------------------------------------------

Phenomena phenoUt(Pointer<Void> handle, double tjdUt, int ipl, int iflag) {
  return using((arena) {
    final attr = arena<Double>(20);
    final flagsUsed = arena<Int32>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephPhenoUt(
      handle,
      tjdUt,
      ipl,
      iflag,
      nullptr,
      nullptr.cast(),
      attr,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return Phenomena(
      phaseAngle: attr[0],
      phase: attr[1],
      elongation: attr[2],
      apparentDiameter: attr[3],
      apparentMagnitude: attr[4],
      horizontalParallax: attr[5],
      flagsUsed: CalcFlags(flagsUsed[0]),
    );
  });
}

Phenomena pheno(Pointer<Void> handle, double tjdEt, int ipl, int iflag) {
  return using((arena) {
    final attr = arena<Double>(20);
    final flagsUsed = arena<Int32>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephPheno(
      handle,
      tjdEt,
      ipl,
      iflag,
      nullptr,
      nullptr.cast(),
      attr,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return Phenomena(
      phaseAngle: attr[0],
      phase: attr[1],
      elongation: attr[2],
      apparentDiameter: attr[3],
      apparentMagnitude: attr[4],
      horizontalParallax: attr[5],
      flagsUsed: CalcFlags(flagsUsed[0]),
    );
  });
}

NodesApsides nodApsUt(
  Pointer<Void> handle,
  double tjdUt,
  int ipl,
  int iflag,
  int method,
) {
  return using((arena) {
    final xnasc = arena<Double>(6);
    final xndsc = arena<Double>(6);
    final xperi = arena<Double>(6);
    final xaphe = arena<Double>(6);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephNodApsUt(
      handle,
      tjdUt,
      ipl,
      iflag,
      method,
      xnasc,
      xndsc,
      xperi,
      xaphe,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return NodesApsides(
      ascending: List.generate(6, (i) => xnasc[i]),
      descending: List.generate(6, (i) => xndsc[i]),
      perihelion: List.generate(6, (i) => xperi[i]),
      aphelion: List.generate(6, (i) => xaphe[i]),
    );
  });
}

NodesApsides nodAps(
  Pointer<Void> handle,
  double tjdEt,
  int ipl,
  int iflag,
  int method,
) {
  return using((arena) {
    final xnasc = arena<Double>(6);
    final xndsc = arena<Double>(6);
    final xperi = arena<Double>(6);
    final xaphe = arena<Double>(6);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephNodAps(
      handle,
      tjdEt,
      ipl,
      iflag,
      method,
      xnasc,
      xndsc,
      xperi,
      xaphe,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return NodesApsides(
      ascending: List.generate(6, (i) => xnasc[i]),
      descending: List.generate(6, (i) => xndsc[i]),
      perihelion: List.generate(6, (i) => xperi[i]),
      aphelion: List.generate(6, (i) => xaphe[i]),
    );
  });
}

OrbitalElements getOrbitalElements(
  Pointer<Void> handle,
  double tjdEt,
  int ipl,
  int iflag,
) {
  return using((arena) {
    final dret = arena<Double>(50);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephGetOrbitalElements(
      handle,
      tjdEt,
      ipl,
      iflag,
      dret,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return OrbitalElements(
      semiMajorAxis: dret[0],
      eccentricity: dret[1],
      inclination: dret[2],
      ascendingNode: dret[3],
      argPerihelion: dret[4],
      perihelionLon: dret[5],
      meanAnomaly: dret[6],
      trueAnomaly: dret[7],
      eccentricAnomaly: dret[8],
      meanLongitude: dret[9],
      siderealPeriod: dret[10],
      meanDailyMotion: dret[11],
      tropicalPeriod: dret[12],
      synodicPeriod: dret[13],
      perihelionPassage: dret[14],
      perihelionDistance: dret[15],
      aphelionDistance: dret[16],
    );
  });
}

OrbitDistances orbitMaxMinTrueDistance(
  Pointer<Void> handle,
  double tjdEt,
  int ipl,
  int iflag,
) {
  return using((arena) {
    final dmax = arena<Double>(1);
    final dmin = arena<Double>(1);
    final dtrue = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephOrbitMaxMinTrueDistance(
      handle,
      tjdEt,
      ipl,
      iflag,
      dmax,
      dmin,
      dtrue,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return OrbitDistances(max: dmax[0], min: dmin[0], trueDist: dtrue[0]);
  });
}

Phenomena phenoWithConfig(
  Pointer<Void> handle,
  double tjdEt,
  int ipl,
  int iflag,
  EphemerisConfig config,
) {
  return using((arena) {
    final attr = arena<Double>(20);
    final flagsUsed = arena<Int32>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final (:geopos, :sidMode) = config_pack.marshalPerCallOverrides(
      arena,
      config,
    );
    final code = swissephPheno(
      handle,
      tjdEt,
      ipl,
      iflag,
      geopos,
      sidMode,
      attr,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return Phenomena(
      phaseAngle: attr[0],
      phase: attr[1],
      elongation: attr[2],
      apparentDiameter: attr[3],
      apparentMagnitude: attr[4],
      horizontalParallax: attr[5],
      flagsUsed: CalcFlags(flagsUsed[0]),
    );
  });
}

Phenomena phenoUtWithConfig(
  Pointer<Void> handle,
  double tjdUt,
  int ipl,
  int iflag,
  EphemerisConfig config,
) {
  return using((arena) {
    final attr = arena<Double>(20);
    final flagsUsed = arena<Int32>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final (:geopos, :sidMode) = config_pack.marshalPerCallOverrides(
      arena,
      config,
    );
    final code = swissephPhenoUt(
      handle,
      tjdUt,
      ipl,
      iflag,
      geopos,
      sidMode,
      attr,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return Phenomena(
      phaseAngle: attr[0],
      phase: attr[1],
      elongation: attr[2],
      apparentDiameter: attr[3],
      apparentMagnitude: attr[4],
      horizontalParallax: attr[5],
      flagsUsed: CalcFlags(flagsUsed[0]),
    );
  });
}

// ---------------------------------------------------------------------------
// Horizon & refraction (task /34)
// ---------------------------------------------------------------------------

AzaltResult azalt(
  Pointer<Void> handle,
  double tjdUt,
  int calcFlag,
  double geolon,
  double geolat,
  double geoalt,
  double atpress,
  double attemp,
  double lapseRate,
  double xin0,
  double xin1,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final xin = arena<Double>(2);
    xin[0] = xin0;
    xin[1] = xin1;
    final xaz = arena<Double>(3);
    swissephAzalt(
      handle,
      tjdUt,
      calcFlag,
      geopos,
      atpress,
      attemp,
      lapseRate,
      xin,
      xaz,
    );
    return AzaltResult(
      azimuth: xaz[0],
      trueAltitude: xaz[1],
      apparentAltitude: xaz[2],
    );
  });
}

({double lon, double lat}) azaltRev(
  Pointer<Void> handle,
  double tjdUt,
  int calcFlag,
  double geolon,
  double geolat,
  double geoalt,
  double azimuth,
  double trueAltitude,
) {
  return using((arena) {
    final geopos = arena<Double>(3);
    geopos[0] = geolon;
    geopos[1] = geolat;
    geopos[2] = geoalt;
    final xin = arena<Double>(2);
    xin[0] = azimuth;
    xin[1] = trueAltitude;
    final xout = arena<Double>(2);
    swissephAzaltRev(handle, tjdUt, calcFlag, geopos, xin, xout);
    return (lon: xout[0], lat: xout[1]);
  });
}

double refrac(double inalt, double atpress, double attemp, int calcFlag) {
  return swissephRefrac(inalt, atpress, attemp, calcFlag);
}

RefracExtendedResult refracExtended(
  double inalt,
  double geoalt,
  double atpress,
  double attemp,
  double lapseRate,
  int calcFlag,
) {
  return using((arena) {
    final dret = arena<Double>(4);
    final result = swissephRefracExtended(
      inalt,
      geoalt,
      atpress,
      attemp,
      lapseRate,
      calcFlag,
      dret,
    );
    return RefracExtendedResult(
      returnValue: result,
      trueAltitude: dret[0],
      apparentAltitude: dret[1],
      refraction: dret[2],
      horizonDip: dret[3],
    );
  });
}

// ---------------------------------------------------------------------------
// Fixed stars (task /33)
// ---------------------------------------------------------------------------

const _starBufSize = 256;

FixstarResult fixstar2(
  Pointer<Void> handle,
  String star,
  double tjdEt,
  int iflag,
) {
  return using((arena) {
    final starIn = star.toNativeUtf8(allocator: arena);
    final starOut = arena<Uint8>(_starBufSize).cast<Utf8>();
    final xx = arena<Double>(6);
    final flagsUsed = arena<Int32>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephFixstar2(
      handle,
      starIn,
      starOut,
      _starBufSize,
      tjdEt,
      iflag,
      nullptr,
      nullptr.cast(),
      xx,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return FixstarResult(
      starName: starOut.toDartString(),
      longitude: xx[0],
      latitude: xx[1],
      distance: xx[2],
      longitudeSpeed: xx[3],
      latitudeSpeed: xx[4],
      distanceSpeed: xx[5],
      flagsUsed: CalcFlags(flagsUsed[0]),
    );
  });
}

FixstarResult fixstar2Ut(
  Pointer<Void> handle,
  String star,
  double tjdUt,
  int iflag,
) {
  return using((arena) {
    final starIn = star.toNativeUtf8(allocator: arena);
    final starOut = arena<Uint8>(_starBufSize).cast<Utf8>();
    final xx = arena<Double>(6);
    final flagsUsed = arena<Int32>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephFixstar2Ut(
      handle,
      starIn,
      starOut,
      _starBufSize,
      tjdUt,
      iflag,
      nullptr,
      nullptr.cast(),
      xx,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return FixstarResult(
      starName: starOut.toDartString(),
      longitude: xx[0],
      latitude: xx[1],
      distance: xx[2],
      longitudeSpeed: xx[3],
      latitudeSpeed: xx[4],
      distanceSpeed: xx[5],
      flagsUsed: CalcFlags(flagsUsed[0]),
    );
  });
}

/// Call `swisseph_fixstar2` with per-call config overrides.
FixstarResult fixstar2WithConfig(
  Pointer<Void> handle,
  String star,
  double tjdEt,
  int iflag,
  EphemerisConfig config,
) {
  return using((arena) {
    final starIn = star.toNativeUtf8(allocator: arena);
    final starOut = arena<Uint8>(_starBufSize).cast<Utf8>();
    final xx = arena<Double>(6);
    final flagsUsed = arena<Int32>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final (:geopos, :sidMode) = config_pack.marshalPerCallOverrides(
      arena,
      config,
    );
    final code = swissephFixstar2(
      handle,
      starIn,
      starOut,
      _starBufSize,
      tjdEt,
      iflag,
      geopos,
      sidMode,
      xx,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return FixstarResult(
      starName: starOut.toDartString(),
      longitude: xx[0],
      latitude: xx[1],
      distance: xx[2],
      longitudeSpeed: xx[3],
      latitudeSpeed: xx[4],
      distanceSpeed: xx[5],
      flagsUsed: CalcFlags(flagsUsed[0]),
    );
  });
}

/// Call `swisseph_fixstar2_ut` with per-call config overrides.
FixstarResult fixstar2UtWithConfig(
  Pointer<Void> handle,
  String star,
  double tjdUt,
  int iflag,
  EphemerisConfig config,
) {
  return using((arena) {
    final starIn = star.toNativeUtf8(allocator: arena);
    final starOut = arena<Uint8>(_starBufSize).cast<Utf8>();
    final xx = arena<Double>(6);
    final flagsUsed = arena<Int32>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final (:geopos, :sidMode) = config_pack.marshalPerCallOverrides(
      arena,
      config,
    );
    final code = swissephFixstar2Ut(
      handle,
      starIn,
      starOut,
      _starBufSize,
      tjdUt,
      iflag,
      geopos,
      sidMode,
      xx,
      flagsUsed,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return FixstarResult(
      starName: starOut.toDartString(),
      longitude: xx[0],
      latitude: xx[1],
      distance: xx[2],
      longitudeSpeed: xx[3],
      latitudeSpeed: xx[4],
      distanceSpeed: xx[5],
      flagsUsed: CalcFlags(flagsUsed[0]),
    );
  });
}

FixstarMagResult fixstar2Mag(Pointer<Void> handle, String star) {
  return using((arena) {
    final starIn = star.toNativeUtf8(allocator: arena);
    final starOut = arena<Uint8>(_starBufSize).cast<Utf8>();
    final mag = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final code = swissephFixstar2Mag(
      handle,
      starIn,
      starOut,
      _starBufSize,
      mag,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return FixstarMagResult(
      starName: starOut.toDartString(),
      magnitude: mag[0],
    );
  });
}

// ---------------------------------------------------------------------------
// Heliacal (task /33)
// ---------------------------------------------------------------------------

void _fillHeliacal(
  Arena arena,
  Pointer<Double> dgeo,
  double geolon,
  double geolat,
  double geoalt,
  Pointer<Double> datm,
  double pressure,
  double temperature,
  double humidity,
  double extinction,
  Pointer<Double> dobs,
  double age,
  double snellenRatio,
  double opticType,
  double aperture,
  double magnification,
  double transmission,
) {
  dgeo[0] = geolon;
  dgeo[1] = geolat;
  dgeo[2] = geoalt;
  datm[0] = pressure;
  datm[1] = temperature;
  datm[2] = humidity;
  datm[3] = extinction;
  dobs[0] = age;
  dobs[1] = snellenRatio;
  dobs[2] = opticType;
  dobs[3] = magnification;
  dobs[4] = aperture;
  dobs[5] = transmission;
}

HeliacalEvent heliacalUt(
  Pointer<Void> handle,
  double tjdStart,
  double geolon,
  double geolat,
  double geoalt,
  double pressure,
  double temperature,
  double humidity,
  double extinction,
  double age,
  double snellenRatio,
  double opticType,
  double aperture,
  double magnification,
  double transmission,
  String objectName,
  int eventType,
  int helflag,
) {
  return using((arena) {
    final dgeo = arena<Double>(3);
    final datm = arena<Double>(4);
    final dobs = arena<Double>(6);
    final dret = arena<Double>(50);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final objName = objectName.toNativeUtf8(allocator: arena);
    _fillHeliacal(
      arena,
      dgeo,
      geolon,
      geolat,
      geoalt,
      datm,
      pressure,
      temperature,
      humidity,
      extinction,
      dobs,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
    );
    final code = swissephHeliacalUt(
      handle,
      tjdStart,
      dgeo,
      datm,
      dobs,
      objName,
      eventType,
      helflag,
      dret,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return HeliacalEvent(
      startVisible: dret[0],
      optimumVisibility: dret[1],
      endVisible: dret[2],
    );
  });
}

HeliacalPheno heliacalPhenoUt(
  Pointer<Void> handle,
  double tjdUt,
  double geolon,
  double geolat,
  double geoalt,
  double pressure,
  double temperature,
  double humidity,
  double extinction,
  double age,
  double snellenRatio,
  double opticType,
  double aperture,
  double magnification,
  double transmission,
  String objectName,
  int eventType,
  int helflag,
) {
  return using((arena) {
    final dgeo = arena<Double>(3);
    final datm = arena<Double>(4);
    final dobs = arena<Double>(6);
    final darr = arena<Double>(50);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final objName = objectName.toNativeUtf8(allocator: arena);
    _fillHeliacal(
      arena,
      dgeo,
      geolon,
      geolat,
      geoalt,
      datm,
      pressure,
      temperature,
      humidity,
      extinction,
      dobs,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
    );
    final code = swissephHeliacalPhenoUt(
      handle,
      tjdUt,
      dgeo,
      datm,
      dobs,
      objName,
      eventType,
      helflag,
      darr,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return HeliacalPheno(
      tcAltitude: darr[0],
      tcApparentAltitude: darr[1],
      gcAltitude: darr[2],
      azimuthObject: darr[3],
      tcSunAltitude: darr[4],
      sunAzimuth: darr[5],
      tavAct: darr[6],
      arcvAct: darr[7],
      dazAct: darr[8],
      arclAct: darr[9],
      kact: darr[10],
      minTav: darr[11],
      tFirstVr: darr[12],
      tBestVr: darr[13],
      tLastVr: darr[14],
      tBestYallop: darr[15],
      wMoon: darr[16],
      qYallop: darr[17],
      qCrit: darr[18],
      parO: darr[19],
      magnO: darr[20],
      riseO: darr[21],
      riseS: darr[22],
      lag: darr[23],
      tVisVr: darr[24],
      lMoon: darr[25],
      elongation: darr[26],
      illumination: darr[27],
    );
  });
}

VisLimitMagResult visLimitMag(
  Pointer<Void> handle,
  double tjdUt,
  double geolon,
  double geolat,
  double geoalt,
  double pressure,
  double temperature,
  double humidity,
  double extinction,
  double age,
  double snellenRatio,
  double opticType,
  double aperture,
  double magnification,
  double transmission,
  String objectName,
  int helflag,
) {
  return using((arena) {
    final dgeo = arena<Double>(3);
    final datm = arena<Double>(4);
    final dobs = arena<Double>(6);
    final dret = arena<Double>(8);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    final objName = objectName.toNativeUtf8(allocator: arena);
    _fillHeliacal(
      arena,
      dgeo,
      geolon,
      geolat,
      geoalt,
      datm,
      pressure,
      temperature,
      humidity,
      extinction,
      dobs,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
    );
    final code = swissephVisLimitMag(
      handle,
      tjdUt,
      dgeo,
      datm,
      dobs,
      objName,
      helflag,
      dret,
      errBuf,
      _errBufSize,
    );
    final belowHorizon = code == -2;
    if (code < 0 && !belowHorizon) {
      _checkResult(code, errBuf);
    }
    return VisLimitMagResult(
      limitingMagnitude: dret[0],
      altitudeObject: dret[1],
      azimuthObject: dret[2],
      altitudeSun: dret[3],
      azimuthSun: dret[4],
      altitudeMoon: dret[5],
      azimuthMoon: dret[6],
      magnitudeObject: dret[7],
      vision: belowHorizon ? VisLimFlags.none : VisLimFlags(code),
      belowHorizon: belowHorizon,
    );
  });
}

HeliacalAngleResult heliacalAngle(
  Pointer<Void> handle,
  double tjdUt,
  double geolon,
  double geolat,
  double geoalt,
  double pressure,
  double temperature,
  double humidity,
  double extinction,
  double age,
  double snellenRatio,
  double opticType,
  double aperture,
  double magnification,
  double transmission,
  int helflag,
  double mag,
  double aziObj,
  double aziSun,
  double aziMoon,
  double altMoon,
) {
  return using((arena) {
    final dgeo = arena<Double>(3);
    final datm = arena<Double>(4);
    final dobs = arena<Double>(6);
    final dret = arena<Double>(3);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    _fillHeliacal(
      arena,
      dgeo,
      geolon,
      geolat,
      geoalt,
      datm,
      pressure,
      temperature,
      humidity,
      extinction,
      dobs,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
    );
    final code = swissephHeliacalAngle(
      handle,
      tjdUt,
      dgeo,
      datm,
      dobs,
      helflag,
      mag,
      aziObj,
      aziSun,
      aziMoon,
      altMoon,
      dret,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return HeliacalAngleResult(
      optimalAltitude: dret[0],
      arcusVisionis: dret[1],
      sunAltitudeDiff: dret[2],
    );
  });
}

double topoArcusVisionis(
  Pointer<Void> handle,
  double tjdUt,
  double geolon,
  double geolat,
  double geoalt,
  double pressure,
  double temperature,
  double humidity,
  double extinction,
  double age,
  double snellenRatio,
  double opticType,
  double aperture,
  double magnification,
  double transmission,
  int helflag,
  double mag,
  double aziObj,
  double altObj,
  double aziSun,
  double aziMoon,
  double altMoon,
) {
  return using((arena) {
    final dgeo = arena<Double>(3);
    final datm = arena<Double>(4);
    final dobs = arena<Double>(6);
    final dret = arena<Double>(1);
    final errBuf = arena<Uint8>(_errBufSize).cast<Utf8>();
    _fillHeliacal(
      arena,
      dgeo,
      geolon,
      geolat,
      geoalt,
      datm,
      pressure,
      temperature,
      humidity,
      extinction,
      dobs,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
    );
    final code = swissephTopoArcusVisionis(
      handle,
      tjdUt,
      dgeo,
      datm,
      dobs,
      helflag,
      mag,
      aziObj,
      altObj,
      aziSun,
      aziMoon,
      altMoon,
      dret,
      errBuf,
      _errBufSize,
    );
    _checkResult(code, errBuf);
    return dret[0];
  });
}

// ---------------------------------------------------------------------------
// Math
// ---------------------------------------------------------------------------

/// Call `swisseph_cotrans`.
List<double> cotrans(double lon, double lat, double dist, double eps) {
  return using((arena) {
    final xpo = arena<Double>(3);
    xpo[0] = lon;
    xpo[1] = lat;
    xpo[2] = dist;
    final xpn = arena<Double>(3);
    swissephCotrans(xpo, xpn, eps);
    return [xpn[0], xpn[1], xpn[2]];
  });
}

/// Call `swisseph_cotrans_sp`.
List<double> cotransWithSpeed(
  double lon,
  double lat,
  double dist,
  double lonSpeed,
  double latSpeed,
  double distSpeed,
  double eps,
) {
  return using((arena) {
    final xpo = arena<Double>(6);
    xpo[0] = lon;
    xpo[1] = lat;
    xpo[2] = dist;
    xpo[3] = lonSpeed;
    xpo[4] = latSpeed;
    xpo[5] = distSpeed;
    final xpn = arena<Double>(6);
    swissephCotransSp(xpo, xpn, eps);
    return [xpn[0], xpn[1], xpn[2], xpn[3], xpn[4], xpn[5]];
  });
}
