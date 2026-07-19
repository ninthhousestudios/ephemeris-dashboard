// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph_rs/swisseph_rs.dart' as rs;

import 'ephemeris.dart';
import 'result_types.dart';
import 'swe_symbol_catalog.dart';
import 'trace_model.dart';

class TracingRustEph implements Ephemeris {
  TracingRustEph([rs.EphemerisConfig? config])
    : _engine = rs.Ephemeris(config ?? const rs.EphemerisConfig());

  rs.Ephemeris _engine;
  final List<CallEntry> _entries = [];
  String _tabTag = '';

  rs.Ephemeris get engine => _engine;

  List<CallEntry> get entries => _entries;

  void setTabTag(String tag) => _tabTag = tag;

  void clearEntries() => _entries.clear();

  void reconfigure(rs.EphemerisConfig config) {
    final replacement = rs.Ephemeris(config);
    _engine.close();
    _engine = replacement;
  }

  void close() {
    _engine.close();
  }

  static Never _translateAndThrow(rs.SweException e) {
    throw e;
  }

  // --------------- Core calculation families ---------------

  @override
  CalcResult calcUt(double jdUt, int body, int flags) {
    final traceId = '$_tabTag:calc_ut:body=$body';
    try {
      final r = _engine.calcUt(
        rs.JdUt1(jdUt),
        rs.Body.fromRawId(body),
        rs.CalcFlags(flags),
      );
      final result = CalcResult(
        longitude: r.longitude,
        latitude: r.latitude,
        distance: r.distance,
        longitudeSpeed: r.longitudeSpeed,
        latitudeSpeed: r.latitudeSpeed,
        distanceSpeed: r.distanceSpeed,
        returnFlag: r.flagsUsed.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCalcUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
          returnFlag: result.returnFlag,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCalcUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  CalcResult calcPctr(double jdEt, int body, int centerBody, int flags) {
    final traceId = '$_tabTag:calc_pctr:body=$body,center=$centerBody';
    try {
      final r = _engine.calcPctr(
        rs.JdTt(jdEt),
        rs.Body.fromRawId(body),
        rs.Body.fromRawId(centerBody),
        rs.CalcFlags(flags),
      );
      final result = CalcResult(
        longitude: r.longitude,
        latitude: r.latitude,
        distance: r.distance,
        longitudeSpeed: r.longitudeSpeed,
        latitudeSpeed: r.latitudeSpeed,
        distanceSpeed: r.distanceSpeed,
        returnFlag: r.flagsUsed.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCalcPctr,
          args: {
            'jdEt': jdEt,
            'body': body,
            'centerBody': centerBody,
            'iflag': flags,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
          returnFlag: result.returnFlag,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCalcPctr,
          args: {
            'jdEt': jdEt,
            'body': body,
            'centerBody': centerBody,
            'iflag': flags,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  HouseResult houses(double jdUt, double geolat, double geolon, int hsys) {
    final traceId = '$_tabTag:houses:hsys=$hsys';
    try {
      final houseSystem =
          rs.HouseSystem.fromCharCode(hsys) ?? rs.HouseSystem.placidus;
      final r = _engine.houses(rs.JdUt1(jdUt), geolat, geolon, houseSystem);
      final result = HouseResult(
        cusps: r.cusps,
        ascmc: [
          r.ascmc.ascendant,
          r.ascmc.mc,
          r.ascmc.armc,
          r.ascmc.vertex,
          r.ascmc.equatorialAscendant,
          r.ascmc.coascendantKoch,
          r.ascmc.coascendantMunkasey,
          r.ascmc.polarAscendant,
        ],
        returnFlag: 0,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHouses,
          args: {
            'jdUt': jdUt,
            'geolat': geolat,
            'geolon': geolon,
            'hsys': hsys,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHouses,
          args: {
            'jdUt': jdUt,
            'geolat': geolat,
            'geolon': geolon,
            'hsys': hsys,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  double getAyanamsaUt(double jdUt) {
    final traceId = '$_tabTag:get_ayanamsa_ut';
    final r = _engine.getAyanamsaUt(rs.JdUt1(jdUt), rs.CalcFlags(0));
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweGetAyanamsaUt,
        args: {'jdUt': jdUt},
        category: CallCategory.calc,
        traceId: traceId,
        result: r.ayanamsa,
      ),
    );
    return r.ayanamsa;
  }

  @override
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags) {
    final traceId = '$_tabTag:get_ayanamsa_ex_ut';
    try {
      final (:ayanamsa, :flagsUsed) = _engine.getAyanamsaUt(
        rs.JdUt1(jdUt),
        rs.CalcFlags(flags),
      );
      final result = AyanamsaResult(
        ayanamsa: ayanamsa,
        returnFlag: flagsUsed.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGetAyanamsaExUt,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGetAyanamsaExUt,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  double deltat(double jd) {
    final traceId = '$_tabTag:deltat';
    final result = _engine.deltaT(rs.JdUt1(jd));
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweDeltat,
        args: {'jd': jd},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double sidTime(double jdUt) {
    final traceId = '$_tabTag:sid_time';
    final result = _engine.siderealTime(rs.JdUt1(jdUt));
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSidtime,
        args: {'jdUt': jdUt},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double sidTime0(double jdUt, double eps, double nut) {
    final traceId = '$_tabTag:sid_time0';
    final result = _engine.siderealTime0(rs.JdUt1(jdUt), eps, nut);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSidtime0,
        args: {'jdUt': jdUt, 'eps': eps, 'nut': nut},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double timeEqu(double jd) {
    final traceId = '$_tabTag:time_equ';
    final result = _engine.timeEqu(jd);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweTimeEqu,
        args: {'jd': jd},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double lmtToLat(double jdLmt, double geolon) {
    final traceId = '$_tabTag:lmt_to_lat';
    final result = _engine.lmtToLat(jdLmt, geolon);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweLmtToLat,
        args: {'jdLmt': jdLmt, 'geolon': geolon},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double latToLmt(double jdLat, double geolon) {
    final traceId = '$_tabTag:lat_to_lmt';
    final result = _engine.latToLmt(jdLat, geolon);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweLatToLmt,
        args: {'jdLat': jdLat, 'geolon': geolon},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  CoTransResult cotrans(double lon, double lat, double dist, double eps) {
    final traceId = '$_tabTag:cotrans';
    try {
      final r = rs.cotrans(lon, lat, dist, eps);
      final result = CoTransResult(lon: r[0], lat: r[1], dist: r[2]);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCotrans,
          args: {'lon': lon, 'lat': lat, 'dist': dist, 'eps': eps},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCotrans,
          args: {'lon': lon, 'lat': lat, 'dist': dist, 'eps': eps},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  double refrac(double altitude, double atpress, double attemp, int calcFlag) {
    final traceId = '$_tabTag:refrac:flag=$calcFlag';
    final dir = calcFlag == 0 ? rs.RefracDir.trueToApp : rs.RefracDir.appToTrue;
    final result = rs.refrac(altitude, atpress, attemp, dir);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweRefrac,
        args: {
          'altitude': altitude,
          'atpress': atpress,
          'attemp': attemp,
          'calcFlag': calcFlag,
        },
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  // --------------- Crossings ---------------

  @override
  double solCrossUt(double longitude, double jdUt, int flags) {
    final traceId = '$_tabTag:sol_cross_ut';
    try {
      final result = _engine.solcrossUt(
        longitude,
        rs.JdUt1(jdUt),
        rs.CalcFlags(flags),
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolcrossUt,
          args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolcrossUt,
          args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  double moonCrossUt(double longitude, double jdUt, int flags) {
    final traceId = '$_tabTag:moon_cross_ut';
    try {
      final result = _engine.mooncrossUt(
        longitude,
        rs.JdUt1(jdUt),
        rs.CalcFlags(flags),
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweMooncrossUt,
          args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweMooncrossUt,
          args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags) {
    final traceId = '$_tabTag:moon_cross_node_ut';
    try {
      final r = _engine.mooncrossNodeUt(rs.JdUt1(jdUt), rs.CalcFlags(flags));
      final result = MoonNodeCrossResult(
        jdUt: r.jd,
        longitude: r.longitude,
        latitude: r.latitude,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweMooncrossNodeUt,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweMooncrossNodeUt,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  double helioCrossUt(
    int body,
    double longitude,
    double jdUt,
    int flags,
    int dir,
  ) {
    final traceId = '$_tabTag:helio_cross_ut:body=$body';
    try {
      final result = _engine.helioCrossUt(
        rs.Body.fromRawId(body),
        longitude,
        rs.JdUt1(jdUt),
        rs.CalcFlags(flags),
        dir: dir,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHeliocrossUt,
          args: {
            'body': body,
            'longitude': longitude,
            'jdUt': jdUt,
            'iflag': flags,
            'dir': dir,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHeliocrossUt,
          args: {
            'body': body,
            'longitude': longitude,
            'jdUt': jdUt,
            'iflag': flags,
            'dir': dir,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  // --------------- Eclipses ---------------

  @override
  SolarEclipseLocalResult solEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    final traceId = '$_tabTag:sol_eclipse_when_loc';
    try {
      final r = _engine.solEclipseWhenLoc(
        rs.JdUt1(jdStart),
        rs.CalcFlags(flags),
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        backward: backward,
      );
      final result = SolarEclipseLocalResult(
        maxEclipse: r.timeMaximum,
        firstContact: r.timeFirstContact,
        secondContact: r.timeSecondContact,
        thirdContact: r.timeThirdContact,
        fourthContact: r.timeFourthContact,
        sunrise: r.timeSunrise,
        sunset: r.timeSunset,
        magnitude: r.attr.magnitude,
        diameterRatio: r.attr.diameterRatio,
        obscuration: r.attr.obscuration,
        coreShadowKm: r.attr.coreDiameterKm,
        sunAzimuth: r.attr.azimuth,
        sunTrueAltitude: r.attr.trueAltitude,
        sunApparentAltitude: r.attr.apparentAltitude,
        moonSunAngle: r.attr.elongation,
        magnitudeNasa: r.attr.nasaMagnitude,
        sarosSeries: r.attr.sarosSeries,
        sarosMember: r.attr.sarosMember,
        returnFlag: r.flags.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhenLoc,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhenLoc,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  SolarEclipseGlobalResult solEclipseWhenGlob(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    final traceId = '$_tabTag:sol_eclipse_when_glob';
    try {
      final r = _engine.solEclipseWhenGlob(
        rs.JdUt1(jdStart),
        rs.CalcFlags(flags),
        eclType: rs.EclipseFlags(eclType),
        backward: backward,
      );
      final result = SolarEclipseGlobalResult(
        maxEclipse: r.timeMaximum,
        localNoon: r.timeRaConjunction,
        begin: r.timeBegin,
        end: r.timeEnd,
        totalityBegin: r.timeTotalityBegin,
        totalityEnd: r.timeTotalityEnd,
        centerLineBegin: r.timeCenterlineBegin,
        centerLineEnd: r.timeCenterlineEnd,
        annularTotalBegin: 0,
        annularTotalEnd: 0,
        returnFlag: r.flags.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhenGlob,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'eclType': eclType,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhenGlob,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'eclType': eclType,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  SolarEclipseAttrResult solEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    final traceId = '$_tabTag:sol_eclipse_how';
    try {
      final r = _engine.solEclipseHow(
        rs.JdUt1(jdUt),
        rs.CalcFlags(flags),
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
      );
      final result = SolarEclipseAttrResult(
        magnitude: r.magnitude,
        diameterRatio: r.diameterRatio,
        obscuration: r.obscuration,
        coreShadowKm: r.coreDiameterKm,
        sunAzimuth: r.azimuth,
        sunTrueAltitude: r.trueAltitude,
        sunApparentAltitude: r.apparentAltitude,
        moonSunAngle: r.elongation,
        magnitudeNasa: r.nasaMagnitude,
        sarosSeries: r.sarosSeries,
        sarosMember: r.sarosMember,
        returnFlag: r.flags.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseHow,
          args: {
            'jdUt': jdUt,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseHow,
          args: {
            'jdUt': jdUt,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) {
    final traceId = '$_tabTag:sol_eclipse_where';
    try {
      final r = _engine.solEclipseWhere(rs.JdUt1(jdUt), rs.CalcFlags(flags));
      final result = EclipseWhereResult(
        geolon: r.centralLongitude,
        geolat: r.centralLatitude,
        magnitude: 0,
        diameterRatio: 0,
        obscuration: 0,
        coreShadowKm: r.coreDiameterKm,
        sunAzimuth: 0,
        sunTrueAltitude: 0,
        sunApparentAltitude: 0,
        moonSunAngle: 0,
        returnFlag: r.flags.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhere,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhere,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  LunarEclipseGlobalResult lunEclipseWhen(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    final traceId = '$_tabTag:lun_eclipse_when';
    try {
      final r = _engine.lunEclipseWhen(
        rs.JdUt1(jdStart),
        rs.CalcFlags(flags),
        eclType: rs.EclipseFlags(eclType),
        backward: backward,
      );
      final result = LunarEclipseGlobalResult(
        maxEclipse: r.timeMaximum,
        partialBegin: r.timePartialBegin,
        partialEnd: r.timePartialEnd,
        totalityBegin: r.timeTotalityBegin,
        totalityEnd: r.timeTotalityEnd,
        penumbralBegin: r.timePenumbralBegin,
        penumbralEnd: r.timePenumbralEnd,
        returnFlag: r.flags.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseWhen,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'eclType': eclType,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseWhen,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'eclType': eclType,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  LunarEclipseLocalResult lunEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    final traceId = '$_tabTag:lun_eclipse_when_loc';
    try {
      final r = _engine.lunEclipseWhenLoc(
        rs.JdUt1(jdStart),
        rs.CalcFlags(flags),
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        backward: backward,
      );
      final result = LunarEclipseLocalResult(
        maxEclipse: r.timeMaximum,
        partialBegin: r.timePartialBegin,
        partialEnd: r.timePartialEnd,
        totalityBegin: r.timeTotalityBegin,
        totalityEnd: r.timeTotalityEnd,
        penumbralBegin: r.timePenumbralBegin,
        penumbralEnd: r.timePenumbralEnd,
        moonrise: r.timeMoonrise,
        moonset: r.timeMoonset,
        umbralMagnitude: r.attr.umbralMagnitude,
        penumbralMagnitude: r.attr.penumbralMagnitude,
        moonAzimuth: r.attr.azimuth,
        moonTrueAltitude: r.attr.trueAltitude,
        moonApparentAltitude: r.attr.apparentAltitude,
        moonOppositionAngle: r.attr.distanceFromOpposition,
        sarosSeries: r.attr.sarosSeries,
        sarosMember: r.attr.sarosMember,
        returnFlag: r.flags.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseWhenLoc,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseWhenLoc,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  LunarEclipseAttrResult lunEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    final traceId = '$_tabTag:lun_eclipse_how';
    try {
      final r = _engine.lunEclipseHow(
        rs.JdUt1(jdUt),
        rs.CalcFlags(flags),
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
      );
      final result = LunarEclipseAttrResult(
        umbralMagnitude: r.umbralMagnitude,
        penumbralMagnitude: r.penumbralMagnitude,
        moonAzimuth: r.azimuth,
        moonTrueAltitude: r.trueAltitude,
        moonApparentAltitude: r.apparentAltitude,
        moonOppositionAngle: r.distanceFromOpposition,
        sarosSeries: r.sarosSeries,
        sarosMember: r.sarosMember,
        returnFlag: r.flags.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseHow,
          args: {
            'jdUt': jdUt,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseHow,
          args: {
            'jdUt': jdUt,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  // --------------- Rise/set ---------------

  @override
  RiseTransResult riseTrans(
    double jdUt,
    int body, {
    String? starName,
    int epheflag = 4,
    int rsmi = 1,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
  }) {
    final traceId = '$_tabTag:rise_trans:body=$body,rsmi=$rsmi';
    try {
      final r = _engine.riseTrans(
        rs.JdUt1(jdUt),
        rs.Body.fromRawId(body),
        rs.CalcFlags(epheflag),
        rs.RiseSetFlags(rsmi),
        starname: starName,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
      );
      final result = RiseTransResult(transitTime: r.time, returnFlag: 0);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweRiseTrans,
          args: {
            'jdUt': jdUt,
            'body': body,
            'starName': starName,
            'epheflag': epheflag,
            'rsmi': rsmi,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweRiseTrans,
          args: {
            'jdUt': jdUt,
            'body': body,
            'starName': starName,
            'epheflag': epheflag,
            'rsmi': rsmi,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  RiseTransResult riseTransTrueHor(
    double jdUt,
    int body, {
    String? starName,
    int epheflag = 4,
    int rsmi = 1,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    required double horizonHeight,
  }) {
    final traceId = '$_tabTag:rise_trans_true_hor:body=$body,rsmi=$rsmi';
    try {
      final r = _engine.riseTransTrueHor(
        rs.JdUt1(jdUt),
        rs.Body.fromRawId(body),
        rs.CalcFlags(epheflag),
        rs.RiseSetFlags(rsmi),
        starname: starName,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
        horhgt: horizonHeight,
      );
      final result = RiseTransResult(transitTime: r.time, returnFlag: 0);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweRiseTransTrueHor,
          args: {
            'jdUt': jdUt,
            'body': body,
            'starName': starName,
            'epheflag': epheflag,
            'rsmi': rsmi,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'horizonHeight': horizonHeight,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweRiseTransTrueHor,
          args: {
            'jdUt': jdUt,
            'body': body,
            'starName': starName,
            'epheflag': epheflag,
            'rsmi': rsmi,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'horizonHeight': horizonHeight,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  // --------------- Horizon ---------------

  @override
  AzAltResult azAlt(
    double jdUt,
    int calcFlag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    required double bodyLon,
    required double bodyLat,
    double bodyDist = 1.0,
  }) {
    final traceId = '$_tabTag:azalt:flag=$calcFlag';
    try {
      final dir = calcFlag == 0 ? rs.AzAltDir.eclToHor : rs.AzAltDir.equToHor;
      final r = _engine.azalt(
        rs.JdUt1(jdUt),
        dir,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
        xin0: bodyLon,
        xin1: bodyLat,
      );
      final result = AzAltResult(
        azimuth: r.azimuth,
        trueAltitude: r.trueAltitude,
        apparentAltitude: r.apparentAltitude,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweAzalt,
          args: {
            'jdUt': jdUt,
            'calcFlag': calcFlag,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'bodyLon': bodyLon,
            'bodyLat': bodyLat,
            'bodyDist': bodyDist,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweAzalt,
          args: {
            'jdUt': jdUt,
            'calcFlag': calcFlag,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'bodyLon': bodyLon,
            'bodyLat': bodyLat,
            'bodyDist': bodyDist,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  AzAltRevResult azAltRev(
    double jdUt,
    int calcFlag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required double azimuth,
    required double altitude,
  }) {
    final traceId = '$_tabTag:azalt_rev:flag=$calcFlag';
    try {
      final dir = calcFlag == 0 ? rs.HorDir.horToEcl : rs.HorDir.horToEqu;
      final r = _engine.azaltRev(
        rs.JdUt1(jdUt),
        dir,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        azimuth: azimuth,
        trueAltitude: altitude,
      );
      final result = AzAltRevResult(lon: r.lon, lat: r.lat);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweAzaltRev,
          args: {
            'jdUt': jdUt,
            'calcFlag': calcFlag,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'azimuth': azimuth,
            'altitude': altitude,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweAzaltRev,
          args: {
            'jdUt': jdUt,
            'calcFlag': calcFlag,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'azimuth': azimuth,
            'altitude': altitude,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  // --------------- Nodes, orbits, phenomena ---------------

  CalcResult _calcResultFrom6(List<double> v) {
    return CalcResult(
      longitude: v[0],
      latitude: v[1],
      distance: v[2],
      longitudeSpeed: v[3],
      latitudeSpeed: v[4],
      distanceSpeed: v[5],
      returnFlag: 0,
    );
  }

  @override
  NodeApsResult nodApsUt(double jdUt, int body, int flags, int method) {
    final traceId = '$_tabTag:nod_aps_ut:body=$body';
    try {
      final r = _engine.nodApsUt(
        rs.JdUt1(jdUt),
        rs.Body.fromRawId(body),
        rs.CalcFlags(flags),
        rs.NodApsMethod(method),
      );
      final result = NodeApsResult(
        ascending: _calcResultFrom6(r.ascending),
        descending: _calcResultFrom6(r.descending),
        perihelion: _calcResultFrom6(r.perihelion),
        aphelion: _calcResultFrom6(r.aphelion),
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweNodApsUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags, 'method': method},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweNodApsUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags, 'method': method},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  OrbitalElementsResult getOrbitalElements(double jdEt, int body, int flags) {
    final traceId = '$_tabTag:get_orbital_elements:body=$body';
    try {
      final r = _engine.getOrbitalElements(
        rs.JdTt(jdEt),
        rs.Body.fromRawId(body),
        rs.CalcFlags(flags),
      );
      final result = OrbitalElementsResult(
        semimajorAxis: r.semiMajorAxis,
        eccentricity: r.eccentricity,
        inclination: r.inclination,
        ascendingNode: r.ascendingNode,
        argPeriapsis: r.argPerihelion,
        lonPeriapsis: r.perihelionLon,
        meanAnomalyEpoch: r.meanAnomaly,
        trueAnomalyEpoch: r.trueAnomaly,
        eccentricAnomalyEpoch: r.eccentricAnomaly,
        meanLongitudeEpoch: r.meanLongitude,
        siderealPeriodYears: r.siderealPeriod,
        meanDailyMotion: r.meanDailyMotion,
        tropicalPeriodYears: r.tropicalPeriod,
        synodicPeriodDays: r.synodicPeriod,
        perihelionPassage: r.perihelionPassage,
        perihelionDistance: r.perihelionDistance,
        aphelionDistance: r.aphelionDistance,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGetOrbitalElements,
          args: {'jdEt': jdEt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGetOrbitalElements,
          args: {'jdEt': jdEt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  OrbitDistanceResult orbitMaxMinTrueDistance(
    double jdEt,
    int body,
    int flags,
  ) {
    final traceId = '$_tabTag:orbit_max_min_true_distance:body=$body';
    try {
      final r = _engine.orbitMaxMinTrueDistance(
        rs.JdTt(jdEt),
        rs.Body.fromRawId(body),
        rs.CalcFlags(flags),
      );
      final result = OrbitDistanceResult(
        maxDist: r.max,
        minDist: r.min,
        trueDist: r.trueDist,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweOrbitMaxMinTrueDistance,
          args: {'jdEt': jdEt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweOrbitMaxMinTrueDistance,
          args: {'jdEt': jdEt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  @override
  PhenoResult phenoUt(double jdUt, int body, int flags) {
    final traceId = '$_tabTag:pheno_ut:body=$body';
    try {
      final r = _engine.phenoUt(
        rs.JdUt1(jdUt),
        rs.Body.fromRawId(body),
        rs.CalcFlags(flags),
      );
      final result = PhenoResult(
        phaseAngle: r.phaseAngle,
        phase: r.phase,
        elongation: r.elongation,
        apparentDiameter: r.apparentDiameter,
        apparentMagnitude: r.apparentMagnitude,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.swePhenoUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.swePhenoUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  // --------------- Stars ---------------

  @override
  FixstarResult fixstar2Ut(String star, double jdUt, int flags) {
    final traceId = '$_tabTag:fixstar2_ut:star=$star';
    try {
      final r = _engine.fixstar2Ut(star, rs.JdUt1(jdUt), rs.CalcFlags(flags));
      final result = FixstarResult(
        starName: r.starName,
        longitude: r.longitude,
        latitude: r.latitude,
        distance: r.distance,
        longitudeSpeed: r.longitudeSpeed,
        latitudeSpeed: r.latitudeSpeed,
        distanceSpeed: r.distanceSpeed,
        returnFlag: r.flagsUsed.value,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweFixstar2Ut,
          args: {'star': star, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
          returnFlag: result.returnFlag,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweFixstar2Ut,
          args: {'star': star, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  // --------------- Gauquelin ---------------

  @override
  double gauquelinSector(
    double jdUt,
    int body,
    int flags,
    int method, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    String? starName,
  }) {
    final traceId = '$_tabTag:gauquelin_sector:body=$body';
    try {
      final result = _engine.gauquelinSector(
        rs.JdUt1(jdUt),
        rs.Body.fromRawId(body),
        rs.CalcFlags(flags),
        method,
        geolon,
        geolat,
        geoalt,
        atpress: atpress,
        attemp: attemp,
        starname: starName,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGauquelinSector,
          args: {
            'jdUt': jdUt,
            'body': body,
            'iflag': flags,
            'method': method,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'starName': starName,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGauquelinSector,
          args: {
            'jdUt': jdUt,
            'body': body,
            'iflag': flags,
            'method': method,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'starName': starName,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }

  // --------------- Heliacal ---------------

  static const _heliacalEventTypes = {
    1: rs.HeliacalEventType.morningFirst,
    2: rs.HeliacalEventType.eveningLast,
    3: rs.HeliacalEventType.eveningFirst,
    4: rs.HeliacalEventType.morningLast,
    5: rs.HeliacalEventType.acronychalRising,
    6: rs.HeliacalEventType.acronychalSetting,
  };

  @override
  HeliacalResult heliacalUt(
    double jdStart, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required AtmoConditions atmo,
    required ObserverConditions observer,
    required String objectName,
    required int typeEvent,
    int flags = 0,
  }) {
    final traceId = '$_tabTag:heliacal_ut:obj=$objectName,event=$typeEvent';
    try {
      final eventType =
          _heliacalEventTypes[typeEvent] ?? rs.HeliacalEventType.morningFirst;
      final r = _engine.heliacalUt(
        rs.JdUt1(jdStart),
        objectName,
        eventType,
        rs.CalcFlags(flags),
        rs.HeliacalFlags.none,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        pressure: atmo.pressure,
        temperature: atmo.temperature,
        humidity: atmo.humidity,
        extinction: atmo.extinction,
        age: observer.age,
        snellenRatio: observer.snellenRatio,
        opticType: observer.monoNoBino,
        aperture: observer.telescopeDia,
        magnification: observer.telescopeMag,
      );
      final result = HeliacalResult(
        startVisible: r.startVisible,
        bestVisible: r.optimumVisibility,
        endVisible: r.endVisible,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHeliacalUt,
          args: {
            'jdStart': jdStart,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'objectName': objectName,
            'typeEvent': typeEvent,
            'iflag': flags,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHeliacalUt,
          args: {
            'jdStart': jdStart,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'objectName': objectName,
            'typeEvent': typeEvent,
            'iflag': flags,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      if (e is rs.SweException) _translateAndThrow(e);
      rethrow;
    }
  }
}
