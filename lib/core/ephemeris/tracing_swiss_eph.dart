import 'package:swisseph/swisseph.dart';
import 'package:swisseph/src/types.dart';

import 'trace_model.dart';

class TracingSwissEph implements SwissEph {
  TracingSwissEph(this._delegate);

  final SwissEph _delegate;
  final List<CallEntry> _entries = [];
  String _tabTag = '';

  List<CallEntry> get entries => _entries;

  void setTabTag(String tag) => _tabTag = tag;

  void clearEntries() => _entries.clear();

  // --------------- Traced methods ---------------

  @override
  CalcResult calcUt(double jdUt, int body, int flags) {
    final traceId = '$_tabTag:calc_ut:body=$body';
    String? errorMessage;
    try {
      final result = _delegate.calcUt(jdUt, body, flags);
      _entries.add(CallEntry(
        functionName: 'swe_calc_ut',
        args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
        returnFlag: result.returnFlag,
      ));
      return result;
    } catch (e) {
      errorMessage = e.toString();
      _entries.add(CallEntry(
        functionName: 'swe_calc_ut',
        args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: errorMessage,
      ));
      rethrow;
    }
  }

  // --------------- Untraced forwarding ---------------

  @override
  void close() => _delegate.close();

  @override
  String version() => _delegate.version();

  @override
  double julday(int year, int month, int day, double hour,
          {bool gregorian = true}) =>
      _delegate.julday(year, month, day, hour, gregorian: gregorian);

  @override
  DateResult revjul(double jd, {bool gregorian = true}) =>
      _delegate.revjul(jd, gregorian: gregorian);

  @override
  JulianDayPair utcToJd(int year, int month, int day, int hour, int min,
          double sec,
          {bool gregorian = true}) =>
      _delegate.utcToJd(year, month, day, hour, min, sec,
          gregorian: gregorian);

  @override
  DateTimeResult jdToUtc(double jdUt, {bool gregorian = true}) =>
      _delegate.jdToUtc(jdUt, gregorian: gregorian);

  @override
  DateTimeResult jdetToUtc(double jdEt, {bool gregorian = true}) =>
      _delegate.jdetToUtc(jdEt, gregorian: gregorian);

  @override
  DateTimeResult utcTimeZone(int year, int month, int day, int hour, int min,
          double sec, double timezone) =>
      _delegate.utcTimeZone(year, month, day, hour, min, sec, timezone);

  @override
  double? dateConversion(int year, int month, int day, double hour,
          {bool gregorian = true}) =>
      _delegate.dateConversion(year, month, day, hour, gregorian: gregorian);

  @override
  int dayOfWeek(double jd) => _delegate.dayOfWeek(jd);

  @override
  void setEphePath(String path) {
    _entries.add(CallEntry(
      functionName: 'swe_set_ephe_path',
      args: {'path': path},
      category: CallCategory.context,
      traceId: '$_tabTag:set_ephe_path',
    ));
    _delegate.setEphePath(path);
  }

  @override
  void setSidMode(int sidMode, {double t0 = 0, double ayanT0 = 0}) {
    _entries.add(CallEntry(
      functionName: 'swe_set_sid_mode',
      args: {'sidMode': sidMode, 't0': t0, 'ayanT0': ayanT0},
      category: CallCategory.context,
      traceId: '$_tabTag:set_sid_mode',
    ));
    _delegate.setSidMode(sidMode, t0: t0, ayanT0: ayanT0);
  }

  @override
  void setTopo(double geolon, double geolat, double geoalt) {
    _entries.add(CallEntry(
      functionName: 'swe_set_topo',
      args: {'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt},
      category: CallCategory.context,
      traceId: '$_tabTag:set_topo',
    ));
    _delegate.setTopo(geolon, geolat, geoalt);
  }

  @override
  void setJplFile(String filename) {
    _entries.add(CallEntry(
      functionName: 'swe_set_jpl_file',
      args: {'filename': filename},
      category: CallCategory.context,
      traceId: '$_tabTag:set_jpl_file',
    ));
    _delegate.setJplFile(filename);
  }

  @override
  String getLibraryPath() => _delegate.getLibraryPath();

  @override
  FileDataResult getCurrentFileData(int fileNum) =>
      _delegate.getCurrentFileData(fileNum);

  @override
  void setInterpolateNut(bool doInterpolate) =>
      _delegate.setInterpolateNut(doInterpolate);

  @override
  void setAstroModels(List<int> models, {int iflag = 0}) =>
      _delegate.setAstroModels(models, iflag: iflag);

  @override
  AstroModelsResult getAstroModels({int iflag = 0}) =>
      _delegate.getAstroModels(iflag: iflag);

  @override
  void setLapseRate(double lapseRate) => _delegate.setLapseRate(lapseRate);

  @override
  CalcResult calc(double jdEt, int body, int flags) =>
      _delegate.calc(jdEt, body, flags);

  @override
  CalcResult calcPctr(double jdEt, int body, int centerBody, int flags) {
    final traceId = '$_tabTag:calc_pctr:body=$body,center=$centerBody';
    try {
      final result = _delegate.calcPctr(jdEt, body, centerBody, flags);
      _entries.add(CallEntry(
        functionName: 'swe_calc_pctr',
        args: {'jdEt': jdEt, 'body': body, 'centerBody': centerBody, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
        returnFlag: result.returnFlag,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_calc_pctr',
        args: {'jdEt': jdEt, 'body': body, 'centerBody': centerBody, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  HouseResult houses(double jdUt, double geolat, double geolon, int hsys) {
    final traceId = '$_tabTag:houses:hsys=$hsys';
    try {
      final result = _delegate.houses(jdUt, geolat, geolon, hsys);
      _entries.add(CallEntry(
        functionName: 'swe_houses',
        args: {'jdUt': jdUt, 'geolat': geolat, 'geolon': geolon, 'hsys': hsys},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_houses',
        args: {'jdUt': jdUt, 'geolat': geolat, 'geolon': geolon, 'hsys': hsys},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  HouseResult housesEx(
          double jdUt, int flags, double geolat, double geolon, int hsys) =>
      _delegate.housesEx(jdUt, flags, geolat, geolon, hsys);

  @override
  HouseResultEx housesEx2(
          double jdUt, int flags, double geolat, double geolon, int hsys) =>
      _delegate.housesEx2(jdUt, flags, geolat, geolon, hsys);

  @override
  HouseResult housesArmc(double armc, double geolat, double eps, int hsys) =>
      _delegate.housesArmc(armc, geolat, eps, hsys);

  @override
  HouseResultEx housesArmcEx2(
          double armc, double geolat, double eps, int hsys) =>
      _delegate.housesArmcEx2(armc, geolat, eps, hsys);

  @override
  double housePos(double armc, double geolat, double eps, int hsys,
          double bodyLon, double bodyLat) =>
      _delegate.housePos(armc, geolat, eps, hsys, bodyLon, bodyLat);

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
      final result = _delegate.gauquelinSector(jdUt, body, flags, method,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atpress: atpress, attemp: attemp, starName: starName);
      _entries.add(CallEntry(
        functionName: 'swe_gauquelin_sector',
        args: {'jdUt': jdUt, 'body': body, 'iflag': flags, 'method': method,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'atpress': atpress, 'attemp': attemp},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_gauquelin_sector',
        args: {'jdUt': jdUt, 'body': body, 'iflag': flags, 'method': method,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'atpress': atpress, 'attemp': attemp},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  double getAyanamsaUt(double jdUt) => _delegate.getAyanamsaUt(jdUt);

  @override
  double getAyanamsa(double jdEt) => _delegate.getAyanamsa(jdEt);

  @override
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags) {
    final traceId = '$_tabTag:get_ayanamsa_ex_ut';
    try {
      final result = _delegate.getAyanamsaExUt(jdUt, flags);
      _entries.add(CallEntry(
        functionName: 'swe_get_ayanamsa_ex_ut',
        args: {'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_get_ayanamsa_ex_ut',
        args: {'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  AyanamsaResult getAyanamsaEx(double jdEt, int flags) =>
      _delegate.getAyanamsaEx(jdEt, flags);

  @override
  String getAyanamsaName(int sidMode) => _delegate.getAyanamsaName(sidMode);

  @override
  String getPlanetName(int body) => _delegate.getPlanetName(body);

  @override
  String houseName(int hsys) => _delegate.houseName(hsys);

  @override
  FixstarResult fixstar2Ut(String star, double jdUt, int flags) {
    final traceId = '$_tabTag:fixstar2_ut:star=$star';
    try {
      final result = _delegate.fixstar2Ut(star, jdUt, flags);
      _entries.add(CallEntry(
        functionName: 'swe_fixstar2_ut',
        args: {'star': star, 'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
        returnFlag: result.returnFlag,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_fixstar2_ut',
        args: {'star': star, 'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  FixstarResult fixstar2(String star, double jdEt, int flags) =>
      _delegate.fixstar2(star, jdEt, flags);

  @override
  double fixstar2Mag(String star) => _delegate.fixstar2Mag(star);

  @override
  double solCrossUt(double longitude, double jdUt, int flags) {
    final traceId = '$_tabTag:sol_cross_ut:lon=$longitude';
    try {
      final result = _delegate.solCrossUt(longitude, jdUt, flags);
      _entries.add(CallEntry(
        functionName: 'swe_solcross_ut',
        args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_solcross_ut',
        args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  double solCross(double longitude, double jdEt, int flags) =>
      _delegate.solCross(longitude, jdEt, flags);

  @override
  double moonCrossUt(double longitude, double jdUt, int flags) {
    final traceId = '$_tabTag:moon_cross_ut:lon=$longitude';
    try {
      final result = _delegate.moonCrossUt(longitude, jdUt, flags);
      _entries.add(CallEntry(
        functionName: 'swe_mooncross_ut',
        args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_mooncross_ut',
        args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  double moonCross(double longitude, double jdEt, int flags) =>
      _delegate.moonCross(longitude, jdEt, flags);

  @override
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags) {
    final traceId = '$_tabTag:moon_cross_node_ut';
    try {
      final result = _delegate.moonCrossNodeUt(jdUt, flags);
      _entries.add(CallEntry(
        functionName: 'swe_mooncross_node_ut',
        args: {'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_mooncross_node_ut',
        args: {'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  MoonNodeCrossResult moonCrossNode(double jdEt, int flags) =>
      _delegate.moonCrossNode(jdEt, flags);

  @override
  double helioCrossUt(
          int body, double longitude, double jdUt, int flags, int dir) {
    final traceId = '$_tabTag:helio_cross_ut:body=$body,lon=$longitude';
    try {
      final result = _delegate.helioCrossUt(body, longitude, jdUt, flags, dir);
      _entries.add(CallEntry(
        functionName: 'swe_heliocross_ut',
        args: {'body': body, 'longitude': longitude, 'jdUt': jdUt,
               'iflag': flags, 'dir': dir},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_heliocross_ut',
        args: {'body': body, 'longitude': longitude, 'jdUt': jdUt,
               'iflag': flags, 'dir': dir},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  double helioCross(
          int body, double longitude, double jdEt, int flags, int dir) =>
      _delegate.helioCross(body, longitude, jdEt, flags, dir);

  @override
  double degnorm(double x) => _delegate.degnorm(x);

  @override
  double radNorm(double x) => _delegate.radNorm(x);

  @override
  double degMidp(double x1, double x0) => _delegate.degMidp(x1, x0);

  @override
  double radMidp(double x1, double x0) => _delegate.radMidp(x1, x0);

  @override
  SplitDegResult splitDeg(double degrees, int roundFlag) =>
      _delegate.splitDeg(degrees, roundFlag);

  @override
  double difDegn(double p1, double p2) => _delegate.difDegn(p1, p2);

  @override
  double difDeg2n(double p1, double p2) => _delegate.difDeg2n(p1, p2);

  @override
  SolarEclipseLocalResult solEclipseWhenLoc(double jdStart, int flags,
          {required double geolon, required double geolat, double geoalt = 0,
          bool backward = false}) {
    final traceId = '$_tabTag:sol_eclipse_when_loc';
    try {
      final result = _delegate.solEclipseWhenLoc(jdStart, flags,
          geolon: geolon, geolat: geolat, geoalt: geoalt, backward: backward);
      _entries.add(CallEntry(
        functionName: 'swe_sol_eclipse_when_loc',
        args: {'jdStart': jdStart, 'iflag': flags, 'geolon': geolon,
               'geolat': geolat, 'geoalt': geoalt, 'backward': backward},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_sol_eclipse_when_loc',
        args: {'jdStart': jdStart, 'iflag': flags, 'geolon': geolon,
               'geolat': geolat, 'geoalt': geoalt, 'backward': backward},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  SolarEclipseGlobalResult solEclipseWhenGlob(double jdStart, int flags,
          {int eclType = 0, bool backward = false}) {
    final traceId = '$_tabTag:sol_eclipse_when_glob';
    try {
      final result = _delegate.solEclipseWhenGlob(jdStart, flags,
          eclType: eclType, backward: backward);
      _entries.add(CallEntry(
        functionName: 'swe_sol_eclipse_when_glob',
        args: {'jdStart': jdStart, 'iflag': flags, 'eclType': eclType,
               'backward': backward},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_sol_eclipse_when_glob',
        args: {'jdStart': jdStart, 'iflag': flags, 'eclType': eclType,
               'backward': backward},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  SolarEclipseAttrResult solEclipseHow(double jdUt, int flags,
          {required double geolon, required double geolat,
          double geoalt = 0}) {
    final traceId = '$_tabTag:sol_eclipse_how';
    try {
      final result = _delegate.solEclipseHow(jdUt, flags,
          geolon: geolon, geolat: geolat, geoalt: geoalt);
      _entries.add(CallEntry(
        functionName: 'swe_sol_eclipse_how',
        args: {'jdUt': jdUt, 'iflag': flags, 'geolon': geolon,
               'geolat': geolat, 'geoalt': geoalt},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_sol_eclipse_how',
        args: {'jdUt': jdUt, 'iflag': flags, 'geolon': geolon,
               'geolat': geolat, 'geoalt': geoalt},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) {
    final traceId = '$_tabTag:sol_eclipse_where';
    try {
      final result = _delegate.solEclipseWhere(jdUt, flags);
      _entries.add(CallEntry(
        functionName: 'swe_sol_eclipse_where',
        args: {'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_sol_eclipse_where',
        args: {'jdUt': jdUt, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  LunarEclipseGlobalResult lunEclipseWhen(double jdStart, int flags,
          {int eclType = 0, bool backward = false}) {
    final traceId = '$_tabTag:lun_eclipse_when';
    try {
      final result = _delegate.lunEclipseWhen(jdStart, flags,
          eclType: eclType, backward: backward);
      _entries.add(CallEntry(
        functionName: 'swe_lun_eclipse_when',
        args: {'jdStart': jdStart, 'iflag': flags, 'eclType': eclType,
               'backward': backward},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_lun_eclipse_when',
        args: {'jdStart': jdStart, 'iflag': flags, 'eclType': eclType,
               'backward': backward},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  LunarEclipseLocalResult lunEclipseWhenLoc(double jdStart, int flags,
          {required double geolon, required double geolat, double geoalt = 0,
          bool backward = false}) {
    final traceId = '$_tabTag:lun_eclipse_when_loc';
    try {
      final result = _delegate.lunEclipseWhenLoc(jdStart, flags,
          geolon: geolon, geolat: geolat, geoalt: geoalt, backward: backward);
      _entries.add(CallEntry(
        functionName: 'swe_lun_eclipse_when_loc',
        args: {'jdStart': jdStart, 'iflag': flags, 'geolon': geolon,
               'geolat': geolat, 'geoalt': geoalt, 'backward': backward},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_lun_eclipse_when_loc',
        args: {'jdStart': jdStart, 'iflag': flags, 'geolon': geolon,
               'geolat': geolat, 'geoalt': geoalt, 'backward': backward},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  LunarEclipseAttrResult lunEclipseHow(double jdUt, int flags,
          {required double geolon, required double geolat,
          double geoalt = 0}) {
    final traceId = '$_tabTag:lun_eclipse_how';
    try {
      final result = _delegate.lunEclipseHow(jdUt, flags,
          geolon: geolon, geolat: geolat, geoalt: geoalt);
      _entries.add(CallEntry(
        functionName: 'swe_lun_eclipse_how',
        args: {'jdUt': jdUt, 'iflag': flags, 'geolon': geolon,
               'geolat': geolat, 'geoalt': geoalt},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_lun_eclipse_how',
        args: {'jdUt': jdUt, 'iflag': flags, 'geolon': geolon,
               'geolat': geolat, 'geoalt': geoalt},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  SolarEclipseLocalResult lunOccultWhenLoc(double jdStart, int body, int flags,
          {String? starname, required double geolon, required double geolat,
          double geoalt = 0, bool backward = false}) =>
      _delegate.lunOccultWhenLoc(jdStart, body, flags,
          starname: starname, geolon: geolon, geolat: geolat, geoalt: geoalt,
          backward: backward);

  @override
  SolarEclipseGlobalResult lunOccultWhenGlob(
          double jdStart, int body, int flags,
          {String? starname, int eclType = 0, bool backward = false}) =>
      _delegate.lunOccultWhenGlob(jdStart, body, flags,
          starname: starname, eclType: eclType, backward: backward);

  @override
  EclipseWhereResult lunOccultWhere(double jdUt, int body, int flags,
          {String? starname}) =>
      _delegate.lunOccultWhere(jdUt, body, flags, starname: starname);

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
      final result = _delegate.riseTrans(jdUt, body,
          starName: starName, epheflag: epheflag, rsmi: rsmi,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atpress: atpress, attemp: attemp);
      _entries.add(CallEntry(
        functionName: 'swe_rise_trans',
        args: {'jdUt': jdUt, 'body': body, 'epheflag': epheflag, 'rsmi': rsmi,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'atpress': atpress, 'attemp': attemp},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_rise_trans',
        args: {'jdUt': jdUt, 'body': body, 'epheflag': epheflag, 'rsmi': rsmi,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'atpress': atpress, 'attemp': attemp},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  RiseTransResult riseTransTrueHor(double jdUt, int body, {
    String? starName,
    int epheflag = 4,
    int rsmi = 1,
    required double geolon, required double geolat,
    double geoalt = 0, double atpress = 1013.25, double attemp = 15.0,
    required double horizonHeight,
  }) {
    final traceId = '$_tabTag:rise_trans_true_hor:body=$body,rsmi=$rsmi';
    try {
      final result = _delegate.riseTransTrueHor(jdUt, body,
          starName: starName, epheflag: epheflag, rsmi: rsmi,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atpress: atpress, attemp: attemp, horizonHeight: horizonHeight);
      _entries.add(CallEntry(
        functionName: 'swe_rise_trans_true_hor',
        args: {'jdUt': jdUt, 'body': body, 'epheflag': epheflag, 'rsmi': rsmi,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'atpress': atpress, 'attemp': attemp,
               'horizonHeight': horizonHeight},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_rise_trans_true_hor',
        args: {'jdUt': jdUt, 'body': body, 'epheflag': epheflag, 'rsmi': rsmi,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'atpress': atpress, 'attemp': attemp,
               'horizonHeight': horizonHeight},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  AzAltResult azAlt(double jdUt, int calcFlag,
          {required double geolon, required double geolat, double geoalt = 0,
          double atpress = 1013.25, double attemp = 15.0,
          required double bodyLon, required double bodyLat,
          double bodyDist = 1.0}) {
    final traceId = '$_tabTag:azalt:flag=$calcFlag';
    try {
      final result = _delegate.azAlt(jdUt, calcFlag,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atpress: atpress, attemp: attemp,
          bodyLon: bodyLon, bodyLat: bodyLat, bodyDist: bodyDist);
      _entries.add(CallEntry(
        functionName: 'swe_azalt',
        args: {'jdUt': jdUt, 'calcFlag': calcFlag,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'atpress': atpress, 'attemp': attemp,
               'bodyLon': bodyLon, 'bodyLat': bodyLat, 'bodyDist': bodyDist},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_azalt',
        args: {'jdUt': jdUt, 'calcFlag': calcFlag,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'atpress': atpress, 'attemp': attemp,
               'bodyLon': bodyLon, 'bodyLat': bodyLat, 'bodyDist': bodyDist},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  AzAltRevResult azAltRev(double jdUt, int calcFlag,
          {required double geolon, required double geolat, double geoalt = 0,
          required double azimuth, required double altitude}) {
    final traceId = '$_tabTag:azalt_rev:flag=$calcFlag';
    try {
      final result = _delegate.azAltRev(jdUt, calcFlag,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          azimuth: azimuth, altitude: altitude);
      _entries.add(CallEntry(
        functionName: 'swe_azalt_rev',
        args: {'jdUt': jdUt, 'calcFlag': calcFlag,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'azimuth': azimuth, 'altitude': altitude},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_azalt_rev',
        args: {'jdUt': jdUt, 'calcFlag': calcFlag,
               'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt,
               'azimuth': azimuth, 'altitude': altitude},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  CoTransResult cotrans(double lon, double lat, double dist, double eps) {
    final traceId = '$_tabTag:cotrans';
    try {
      final result = _delegate.cotrans(lon, lat, dist, eps);
      _entries.add(CallEntry(
        functionName: 'swe_cotrans',
        args: {'lon': lon, 'lat': lat, 'dist': dist, 'eps': eps},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_cotrans',
        args: {'lon': lon, 'lat': lat, 'dist': dist, 'eps': eps},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  CoTransSpResult cotransSp(double lon, double lat, double dist,
          double lonSpeed, double latSpeed, double distSpeed, double eps) =>
      _delegate.cotransSp(lon, lat, dist, lonSpeed, latSpeed, distSpeed, eps);

  @override
  double refrac(double altitude, double atpress, double attemp,
          int calcFlag) {
    final traceId = '$_tabTag:refrac:flag=$calcFlag';
    final result = _delegate.refrac(altitude, atpress, attemp, calcFlag);
    _entries.add(CallEntry(
      functionName: 'swe_refrac',
      args: {'altitude': altitude, 'atpress': atpress, 'attemp': attemp,
             'calcFlag': calcFlag},
      category: CallCategory.calc,
      traceId: traceId,
      result: result,
    ));
    return result;
  }

  @override
  RefracResult refracExtended(double altitude, double geoalt, double atpress,
          double attemp, double lapseRate, int calcFlag) =>
      _delegate.refracExtended(
          altitude, geoalt, atpress, attemp, lapseRate, calcFlag);

  @override
  double deltat(double jd) {
    final traceId = '$_tabTag:deltat';
    final result = _delegate.deltat(jd);
    _entries.add(CallEntry(
      functionName: 'swe_deltat',
      args: {'jd': jd},
      category: CallCategory.calc,
      traceId: traceId,
      result: result,
    ));
    return result;
  }

  @override
  double deltatEx(double jd, int flags) => _delegate.deltatEx(jd, flags);

  @override
  double timeEqu(double jd) {
    final traceId = '$_tabTag:time_equ';
    final result = _delegate.timeEqu(jd);
    _entries.add(CallEntry(
      functionName: 'swe_time_equ',
      args: {'jd': jd},
      category: CallCategory.calc,
      traceId: traceId,
      result: result,
    ));
    return result;
  }

  @override
  double sidTime(double jdUt) {
    final traceId = '$_tabTag:sid_time';
    final result = _delegate.sidTime(jdUt);
    _entries.add(CallEntry(
      functionName: 'swe_sidtime',
      args: {'jdUt': jdUt},
      category: CallCategory.calc,
      traceId: traceId,
      result: result,
    ));
    return result;
  }

  @override
  double sidTime0(double jdUt, double eps, double nut) {
    final traceId = '$_tabTag:sid_time0';
    final result = _delegate.sidTime0(jdUt, eps, nut);
    _entries.add(CallEntry(
      functionName: 'swe_sidtime0',
      args: {'jdUt': jdUt, 'eps': eps, 'nut': nut},
      category: CallCategory.calc,
      traceId: traceId,
      result: result,
    ));
    return result;
  }

  @override
  double lmtToLat(double jdLmt, double geolon) {
    final traceId = '$_tabTag:lmt_to_lat';
    final result = _delegate.lmtToLat(jdLmt, geolon);
    _entries.add(CallEntry(
      functionName: 'swe_lmt_to_lat',
      args: {'jdLmt': jdLmt, 'geolon': geolon},
      category: CallCategory.calc,
      traceId: traceId,
      result: result,
    ));
    return result;
  }

  @override
  double latToLmt(double jdLat, double geolon) {
    final traceId = '$_tabTag:lat_to_lmt';
    final result = _delegate.latToLmt(jdLat, geolon);
    _entries.add(CallEntry(
      functionName: 'swe_lat_to_lmt',
      args: {'jdLat': jdLat, 'geolon': geolon},
      category: CallCategory.calc,
      traceId: traceId,
      result: result,
    ));
    return result;
  }

  @override
  void setDeltaTUserdef(double dt) => _delegate.setDeltaTUserdef(dt);

  @override
  double getTidAcc() => _delegate.getTidAcc();

  @override
  void setTidAcc(double tidAcc) => _delegate.setTidAcc(tidAcc);

  @override
  NodeApsResult nodApsUt(double jdUt, int body, int flags, int method) {
    final traceId = '$_tabTag:nod_aps_ut:body=$body';
    try {
      final result = _delegate.nodApsUt(jdUt, body, flags, method);
      _entries.add(CallEntry(
        functionName: 'swe_nod_aps_ut',
        args: {'jdUt': jdUt, 'body': body, 'iflag': flags, 'method': method},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_nod_aps_ut',
        args: {'jdUt': jdUt, 'body': body, 'iflag': flags, 'method': method},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  NodeApsResult nodAps(double jdEt, int body, int flags, int method) =>
      _delegate.nodAps(jdEt, body, flags, method);

  @override
  OrbitalElementsResult getOrbitalElements(
          double jdEt, int body, int flags) =>
      _delegate.getOrbitalElements(jdEt, body, flags);

  @override
  OrbitDistanceResult orbitMaxMinTrueDistance(
          double jdEt, int body, int flags) =>
      _delegate.orbitMaxMinTrueDistance(jdEt, body, flags);

  @override
  PhenoResult phenoUt(double jdUt, int body, int flags) {
    final traceId = '$_tabTag:pheno_ut:body=$body';
    try {
      final result = _delegate.phenoUt(jdUt, body, flags);
      _entries.add(CallEntry(
        functionName: 'swe_pheno_ut',
        args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_pheno_ut',
        args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  PhenoResult pheno(double jdEt, int body, int flags) =>
      _delegate.pheno(jdEt, body, flags);

  @override
  HeliacalResult heliacalUt(double jdStart, {
    required double geolon, required double geolat, double geoalt = 0,
    required AtmoConditions atmo, required ObserverConditions observer,
    required String objectName, required int typeEvent, int flags = 0,
  }) {
    final traceId = '$_tabTag:heliacal_ut:obj=$objectName,event=$typeEvent';
    try {
      final result = _delegate.heliacalUt(jdStart,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atmo: atmo, observer: observer,
          objectName: objectName, typeEvent: typeEvent, flags: flags);
      _entries.add(CallEntry(
        functionName: 'swe_heliacal_ut',
        args: {'jdStart': jdStart, 'geolon': geolon, 'geolat': geolat,
               'geoalt': geoalt, 'objectName': objectName,
               'typeEvent': typeEvent, 'flags': flags},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ));
      return result;
    } catch (e) {
      _entries.add(CallEntry(
        functionName: 'swe_heliacal_ut',
        args: {'jdStart': jdStart, 'geolon': geolon, 'geolat': geolat,
               'geoalt': geoalt, 'objectName': objectName,
               'typeEvent': typeEvent, 'flags': flags},
        category: CallCategory.calc,
        traceId: traceId,
        errorMessage: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  HeliacalPhenoResult heliacalPhenoUt(double jdUt, {
    required double geolon, required double geolat, double geoalt = 0,
    required AtmoConditions atmo, required ObserverConditions observer,
    required String objectName, required int typeEvent, int flags = 0,
  }) =>
      _delegate.heliacalPhenoUt(jdUt,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atmo: atmo, observer: observer,
          objectName: objectName, typeEvent: typeEvent, flags: flags);

  @override
  HeliacalAngleResult heliacalAngle(double jdUt, {
    required double geolon, required double geolat, double geoalt = 0,
    required AtmoConditions atmo, required ObserverConditions observer,
    required int helflag, required double mag,
    required double aziObj, required double aziSun,
    required double aziMoon, required double altMoon,
  }) =>
      _delegate.heliacalAngle(jdUt,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atmo: atmo, observer: observer,
          helflag: helflag, mag: mag,
          aziObj: aziObj, aziSun: aziSun,
          aziMoon: aziMoon, altMoon: altMoon);

  @override
  double topoArcusVisionis(double jdUt, {
    required double geolon, required double geolat, double geoalt = 0,
    required AtmoConditions atmo, required ObserverConditions observer,
    required int helflag, required double mag,
    required double aziObj, required double altObj,
    required double aziSun, required double aziMoon, required double altMoon,
  }) =>
      _delegate.topoArcusVisionis(jdUt,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atmo: atmo, observer: observer,
          helflag: helflag, mag: mag,
          aziObj: aziObj, altObj: altObj,
          aziSun: aziSun, aziMoon: aziMoon, altMoon: altMoon);

  @override
  VisLimitResult visLimitMag(double jdUt, {
    required double geolon, required double geolat, double geoalt = 0,
    required AtmoConditions atmo, required ObserverConditions observer,
    required String objectName, int flags = 0,
  }) =>
      _delegate.visLimitMag(jdUt,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atmo: atmo, observer: observer,
          objectName: objectName, flags: flags);

}
