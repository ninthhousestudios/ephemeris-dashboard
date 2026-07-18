// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph/swisseph.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;

import 'ephemeris.dart';
import 'swe_symbol_catalog.dart';
import 'trace_model.dart';

class TracingRustEph implements Ephemeris {
  TracingRustEph() {
    _engine = rs.Ephemeris(_buildConfig());
  }

  late rs.Ephemeris _engine;
  final List<CallEntry> _entries = [];
  String _tabTag = '';

  // Stored context (stateful → stateless bridge)
  String? _ephePath;
  rs.SiderealMode? _sidMode;
  double _t0 = 0;
  double _ayanT0 = 0;
  double? _geolon;
  double? _geolat;
  double? _geoalt;
  String? _jplFile;

  List<CallEntry> get entries => _entries;

  void setTabTag(String tag) => _tabTag = tag;

  void clearEntries() => _entries.clear();

  void close() {
    _engine.close();
  }

  rs.EphemerisConfig _buildConfig() {
    return rs.EphemerisConfig(
      ephePath: _ephePath,
      jplFilename: _jplFile,
      siderealMode: _sidMode,
      siderealT0: _t0,
      siderealAyanT0: _ayanT0,
      topographic: (_geolon != null)
          ? rs.TopoPosition(
              longitude: _geolon!,
              latitude: _geolat!,
              altitude: _geoalt!,
            )
          : null,
    );
  }

  void _rebuildEngine() {
    _engine.close();
    _engine = rs.Ephemeris(_buildConfig());
  }

  // --------------- Context setters ---------------

  @override
  void setEphePath(String path) {
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSetEphePath,
        args: {'path': path},
        category: CallCategory.context,
        traceId: '$_tabTag:set_ephe_path',
      ),
    );
    _ephePath = path;
    _rebuildEngine();
  }

  @override
  void setSidMode(int sidMode, {double t0 = 0, double ayanT0 = 0}) {
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSetSidMode,
        args: {'sidMode': sidMode, 't0': t0, 'ayanT0': ayanT0},
        category: CallCategory.context,
        traceId: '$_tabTag:set_sid_mode',
      ),
    );
    _sidMode = rs.SiderealMode.values.firstWhere(
      (m) => m.value == (sidMode & 0xFF),
      orElse: () => rs.SiderealMode.faganBradley,
    );
    _t0 = t0;
    _ayanT0 = ayanT0;
    _rebuildEngine();
  }

  @override
  void setTopo(double geolon, double geolat, double geoalt) {
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSetTopo,
        args: {'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt},
        category: CallCategory.context,
        traceId: '$_tabTag:set_topo',
      ),
    );
    _geolon = geolon;
    _geolat = geolat;
    _geoalt = geoalt;
    _rebuildEngine();
  }

  @override
  void setJplFile(String filename) {
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSetJplFile,
        args: {'filename': filename},
        category: CallCategory.context,
        traceId: '$_tabTag:set_jpl_file',
      ),
    );
    _jplFile = filename;
    _rebuildEngine();
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
      rethrow;
    }
  }

  @override
  double getAyanamsaUt(double jdUt) {
    final traceId = '$_tabTag:get_ayanamsa_ut';
    final dt = _engine.deltaT(rs.JdUt1(jdUt));
    final result = _engine.getAyanamsa(rs.JdTt(jdUt + dt));
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweGetAyanamsaUt,
        args: {'jdUt': jdUt},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags) {
    final traceId = '$_tabTag:get_ayanamsa_ex_ut';
    try {
      final ayanamsa = _engine.getAyanamsaUt(
        rs.JdUt1(jdUt),
        rs.CalcFlags(flags),
      );
      final result = AyanamsaResult(ayanamsa: ayanamsa, returnFlag: flags);
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

  // --------------- Families not in scope for S2 ---------------

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
    throw UnsupportedError('TracingRustEph: gauquelinSector not yet bridged');
  }

  @override
  FixstarResult fixstar2Ut(String star, double jdUt, int flags) {
    throw UnsupportedError('TracingRustEph: fixstar2Ut not yet bridged');
  }

  @override
  double solCrossUt(double longitude, double jdUt, int flags) {
    throw UnsupportedError('TracingRustEph: solCrossUt not yet bridged');
  }

  @override
  double moonCrossUt(double longitude, double jdUt, int flags) {
    throw UnsupportedError('TracingRustEph: moonCrossUt not yet bridged');
  }

  @override
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags) {
    throw UnsupportedError('TracingRustEph: moonCrossNodeUt not yet bridged');
  }

  @override
  double helioCrossUt(
    int body,
    double longitude,
    double jdUt,
    int flags,
    int dir,
  ) {
    throw UnsupportedError('TracingRustEph: helioCrossUt not yet bridged');
  }

  @override
  SolarEclipseLocalResult solEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    throw UnsupportedError('TracingRustEph: solEclipseWhenLoc not yet bridged');
  }

  @override
  SolarEclipseGlobalResult solEclipseWhenGlob(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    throw UnsupportedError(
      'TracingRustEph: solEclipseWhenGlob not yet bridged',
    );
  }

  @override
  SolarEclipseAttrResult solEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    throw UnsupportedError('TracingRustEph: solEclipseHow not yet bridged');
  }

  @override
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) {
    throw UnsupportedError('TracingRustEph: solEclipseWhere not yet bridged');
  }

  @override
  LunarEclipseGlobalResult lunEclipseWhen(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    throw UnsupportedError('TracingRustEph: lunEclipseWhen not yet bridged');
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
    throw UnsupportedError('TracingRustEph: lunEclipseWhenLoc not yet bridged');
  }

  @override
  LunarEclipseAttrResult lunEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    throw UnsupportedError('TracingRustEph: lunEclipseHow not yet bridged');
  }

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
    throw UnsupportedError('TracingRustEph: riseTrans not yet bridged');
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
    throw UnsupportedError('TracingRustEph: riseTransTrueHor not yet bridged');
  }

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
    throw UnsupportedError('TracingRustEph: azAlt not yet bridged');
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
    throw UnsupportedError('TracingRustEph: azAltRev not yet bridged');
  }

  @override
  NodeApsResult nodApsUt(double jdUt, int body, int flags, int method) {
    throw UnsupportedError('TracingRustEph: nodApsUt not yet bridged');
  }

  @override
  OrbitalElementsResult getOrbitalElements(double jdEt, int body, int flags) {
    throw UnsupportedError(
      'TracingRustEph: getOrbitalElements not yet bridged',
    );
  }

  @override
  OrbitDistanceResult orbitMaxMinTrueDistance(
    double jdEt,
    int body,
    int flags,
  ) {
    throw UnsupportedError(
      'TracingRustEph: orbitMaxMinTrueDistance not yet bridged',
    );
  }

  @override
  PhenoResult phenoUt(double jdUt, int body, int flags) {
    throw UnsupportedError('TracingRustEph: phenoUt not yet bridged');
  }

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
    throw UnsupportedError('TracingRustEph: heliacalUt not yet bridged');
  }
}
