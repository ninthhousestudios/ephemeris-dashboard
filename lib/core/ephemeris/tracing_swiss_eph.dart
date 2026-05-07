import 'package:swisseph/swisseph.dart';
import 'package:swisseph/src/types.dart';

import 'trace_model.dart';

class TracingSwissEph implements SwissEph {
  TracingSwissEph(this._delegate);

  final SwissEph _delegate;
  final List<CallEntry> _entries = [];
  String _tabTag = '';

  List<CallEntry> get entries => List.unmodifiable(_entries);

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
  void setEphePath(String path) => _delegate.setEphePath(path);

  @override
  void setSidMode(int sidMode, {double t0 = 0, double ayanT0 = 0}) =>
      _delegate.setSidMode(sidMode, t0: t0, ayanT0: ayanT0);

  @override
  void setTopo(double geolon, double geolat, double geoalt) =>
      _delegate.setTopo(geolon, geolat, geoalt);

  @override
  void setJplFile(String filename) => _delegate.setJplFile(filename);

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
  CalcResult calcPctr(double jdEt, int body, int centerBody, int flags) =>
      _delegate.calcPctr(jdEt, body, centerBody, flags);

  @override
  HouseResult houses(double jdUt, double geolat, double geolon, int hsys) =>
      _delegate.houses(jdUt, geolat, geolon, hsys);

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
  }) =>
      _delegate.gauquelinSector(jdUt, body, flags, method,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atpress: atpress, attemp: attemp, starName: starName);

  @override
  double getAyanamsaUt(double jdUt) => _delegate.getAyanamsaUt(jdUt);

  @override
  double getAyanamsa(double jdEt) => _delegate.getAyanamsa(jdEt);

  @override
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags) =>
      _delegate.getAyanamsaExUt(jdUt, flags);

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
  FixstarResult fixstar2Ut(String star, double jdUt, int flags) =>
      _delegate.fixstar2Ut(star, jdUt, flags);

  @override
  FixstarResult fixstar2(String star, double jdEt, int flags) =>
      _delegate.fixstar2(star, jdEt, flags);

  @override
  double fixstar2Mag(String star) => _delegate.fixstar2Mag(star);

  @override
  double solCrossUt(double longitude, double jdUt, int flags) =>
      _delegate.solCrossUt(longitude, jdUt, flags);

  @override
  double solCross(double longitude, double jdEt, int flags) =>
      _delegate.solCross(longitude, jdEt, flags);

  @override
  double moonCrossUt(double longitude, double jdUt, int flags) =>
      _delegate.moonCrossUt(longitude, jdUt, flags);

  @override
  double moonCross(double longitude, double jdEt, int flags) =>
      _delegate.moonCross(longitude, jdEt, flags);

  @override
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags) =>
      _delegate.moonCrossNodeUt(jdUt, flags);

  @override
  MoonNodeCrossResult moonCrossNode(double jdEt, int flags) =>
      _delegate.moonCrossNode(jdEt, flags);

  @override
  double helioCrossUt(
          int body, double longitude, double jdUt, int flags, int dir) =>
      _delegate.helioCrossUt(body, longitude, jdUt, flags, dir);

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
          bool backward = false}) =>
      _delegate.solEclipseWhenLoc(jdStart, flags,
          geolon: geolon, geolat: geolat, geoalt: geoalt, backward: backward);

  @override
  SolarEclipseGlobalResult solEclipseWhenGlob(double jdStart, int flags,
          {int eclType = 0, bool backward = false}) =>
      _delegate.solEclipseWhenGlob(jdStart, flags,
          eclType: eclType, backward: backward);

  @override
  SolarEclipseAttrResult solEclipseHow(double jdUt, int flags,
          {required double geolon, required double geolat,
          double geoalt = 0}) =>
      _delegate.solEclipseHow(jdUt, flags,
          geolon: geolon, geolat: geolat, geoalt: geoalt);

  @override
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) =>
      _delegate.solEclipseWhere(jdUt, flags);

  @override
  LunarEclipseGlobalResult lunEclipseWhen(double jdStart, int flags,
          {int eclType = 0, bool backward = false}) =>
      _delegate.lunEclipseWhen(jdStart, flags,
          eclType: eclType, backward: backward);

  @override
  LunarEclipseLocalResult lunEclipseWhenLoc(double jdStart, int flags,
          {required double geolon, required double geolat, double geoalt = 0,
          bool backward = false}) =>
      _delegate.lunEclipseWhenLoc(jdStart, flags,
          geolon: geolon, geolat: geolat, geoalt: geoalt, backward: backward);

  @override
  LunarEclipseAttrResult lunEclipseHow(double jdUt, int flags,
          {required double geolon, required double geolat,
          double geoalt = 0}) =>
      _delegate.lunEclipseHow(jdUt, flags,
          geolon: geolon, geolat: geolat, geoalt: geoalt);

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
  }) =>
      _delegate.riseTrans(jdUt, body,
          starName: starName, epheflag: epheflag, rsmi: rsmi,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atpress: atpress, attemp: attemp);

  @override
  RiseTransResult riseTransTrueHor(double jdUt, int body, {
    String? starName,
    int epheflag = 4,
    int rsmi = 1,
    required double geolon, required double geolat,
    double geoalt = 0, double atpress = 1013.25, double attemp = 15.0,
    required double horizonHeight,
  }) =>
      _delegate.riseTransTrueHor(jdUt, body,
          starName: starName, epheflag: epheflag, rsmi: rsmi,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atpress: atpress, attemp: attemp, horizonHeight: horizonHeight);

  @override
  AzAltResult azAlt(double jdUt, int calcFlag,
          {required double geolon, required double geolat, double geoalt = 0,
          double atpress = 1013.25, double attemp = 15.0,
          required double bodyLon, required double bodyLat,
          double bodyDist = 1.0}) =>
      _delegate.azAlt(jdUt, calcFlag,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atpress: atpress, attemp: attemp,
          bodyLon: bodyLon, bodyLat: bodyLat, bodyDist: bodyDist);

  @override
  AzAltRevResult azAltRev(double jdUt, int calcFlag,
          {required double geolon, required double geolat, double geoalt = 0,
          required double azimuth, required double altitude}) =>
      _delegate.azAltRev(jdUt, calcFlag,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          azimuth: azimuth, altitude: altitude);

  @override
  CoTransResult cotrans(double lon, double lat, double dist, double eps) =>
      _delegate.cotrans(lon, lat, dist, eps);

  @override
  CoTransSpResult cotransSp(double lon, double lat, double dist,
          double lonSpeed, double latSpeed, double distSpeed, double eps) =>
      _delegate.cotransSp(lon, lat, dist, lonSpeed, latSpeed, distSpeed, eps);

  @override
  double refrac(double altitude, double atpress, double attemp,
          int calcFlag) =>
      _delegate.refrac(altitude, atpress, attemp, calcFlag);

  @override
  RefracResult refracExtended(double altitude, double geoalt, double atpress,
          double attemp, double lapseRate, int calcFlag) =>
      _delegate.refracExtended(
          altitude, geoalt, atpress, attemp, lapseRate, calcFlag);

  @override
  double deltat(double jd) => _delegate.deltat(jd);

  @override
  double deltatEx(double jd, int flags) => _delegate.deltatEx(jd, flags);

  @override
  double timeEqu(double jd) => _delegate.timeEqu(jd);

  @override
  double sidTime(double jdUt) => _delegate.sidTime(jdUt);

  @override
  double sidTime0(double jdUt, double eps, double nut) =>
      _delegate.sidTime0(jdUt, eps, nut);

  @override
  double lmtToLat(double jdLmt, double geolon) =>
      _delegate.lmtToLat(jdLmt, geolon);

  @override
  double latToLmt(double jdLat, double geolon) =>
      _delegate.latToLmt(jdLat, geolon);

  @override
  void setDeltaTUserdef(double dt) => _delegate.setDeltaTUserdef(dt);

  @override
  double getTidAcc() => _delegate.getTidAcc();

  @override
  void setTidAcc(double tidAcc) => _delegate.setTidAcc(tidAcc);

  @override
  NodeApsResult nodApsUt(double jdUt, int body, int flags, int method) =>
      _delegate.nodApsUt(jdUt, body, flags, method);

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
  PhenoResult phenoUt(double jdUt, int body, int flags) =>
      _delegate.phenoUt(jdUt, body, flags);

  @override
  PhenoResult pheno(double jdEt, int body, int flags) =>
      _delegate.pheno(jdEt, body, flags);

  @override
  HeliacalResult heliacalUt(double jdStart, {
    required double geolon, required double geolat, double geoalt = 0,
    required AtmoConditions atmo, required ObserverConditions observer,
    required String objectName, required int typeEvent, int flags = 0,
  }) =>
      _delegate.heliacalUt(jdStart,
          geolon: geolon, geolat: geolat, geoalt: geoalt,
          atmo: atmo, observer: observer,
          objectName: objectName, typeEvent: typeEvent, flags: flags);

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
