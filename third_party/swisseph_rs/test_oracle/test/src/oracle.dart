// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph/swisseph.dart' as swe;

class OracleCalcResult {
  final double longitude;
  final double latitude;
  final double distance;
  final double longitudeSpeed;
  final double latitudeSpeed;
  final double distanceSpeed;

  OracleCalcResult._fromSwe(swe.CalcResult r)
    : longitude = r.longitude,
      latitude = r.latitude,
      distance = r.distance,
      longitudeSpeed = r.longitudeSpeed,
      latitudeSpeed = r.latitudeSpeed,
      distanceSpeed = r.distanceSpeed;

  OracleCalcResult.fromFields({
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.longitudeSpeed,
    required this.latitudeSpeed,
    required this.distanceSpeed,
  });
}

class Oracle {
  final swe.SwissEph _swe;

  Oracle({String? ephePath}) : _swe = swe.SwissEph.find() {
    if (ephePath != null) _swe.setEphePath(ephePath);
  }

  OracleCalcResult calcUt(double jdUt, int body, int flags) {
    final result = _swe.calcUt(jdUt, body, flags);
    return OracleCalcResult._fromSwe(result);
  }

  OracleCalcResult calcUtSidereal(
    double jdUt,
    int body,
    int flags,
    int sidMode, {
    double t0 = 0,
    double ayanT0 = 0,
  }) {
    _swe.setSidMode(sidMode, t0: t0, ayanT0: ayanT0);
    try {
      final result = _swe.calcUt(jdUt, body, flags | swe.seFlgSidereal);
      return OracleCalcResult._fromSwe(result);
    } finally {
      _swe.setSidMode(0);
    }
  }

  OracleCalcResult calc(double jdEt, int body, int flags) {
    final result = _swe.calc(jdEt, body, flags);
    return OracleCalcResult._fromSwe(result);
  }

  OracleCalcResult calcSidereal(
    double jdEt,
    int body,
    int flags,
    int sidMode, {
    double t0 = 0,
    double ayanT0 = 0,
  }) {
    _swe.setSidMode(sidMode, t0: t0, ayanT0: ayanT0);
    try {
      final result = _swe.calc(jdEt, body, flags | swe.seFlgSidereal);
      return OracleCalcResult._fromSwe(result);
    } finally {
      _swe.setSidMode(0);
    }
  }

  OracleCalcResult calcTopo(
    double jdEt,
    int body,
    int flags,
    double geolon,
    double geolat,
    double altitude,
  ) {
    _swe.setTopo(geolon, geolat, altitude);
    final result = _swe.calc(jdEt, body, flags | swe.seFlgTopoCtr);
    return OracleCalcResult._fromSwe(result);
  }

  OracleCalcResult calcUtTopo(
    double jdUt,
    int body,
    int flags,
    double geolon,
    double geolat,
    double altitude,
  ) {
    _swe.setTopo(geolon, geolat, altitude);
    final result = _swe.calcUt(jdUt, body, flags | swe.seFlgTopoCtr);
    return OracleCalcResult._fromSwe(result);
  }

  OracleCalcResult calcPctr(double jdEt, int body, int centerBody, int flags) {
    final result = _swe.calcPctr(jdEt, body, centerBody, flags);
    return OracleCalcResult._fromSwe(result);
  }

  double julday(
    int year,
    int month,
    int day,
    double hour, {
    bool gregorian = true,
  }) {
    return _swe.julday(year, month, day, hour, gregorian: gregorian);
  }

  ({int year, int month, int day, double hour}) revjul(
    double jd, {
    bool gregorian = true,
  }) {
    final r = _swe.revjul(jd, gregorian: gregorian);
    return (year: r.year, month: r.month, day: r.day, hour: r.hour);
  }

  double? dateConversion(
    int year,
    int month,
    int day,
    double hour, {
    bool gregorian = true,
  }) {
    return _swe.dateConversion(year, month, day, hour, gregorian: gregorian);
  }

  int dayOfWeek(double jd) {
    return _swe.dayOfWeek(jd);
  }

  ({int year, int month, int day, int hour, int min, double sec}) utcTimeZone(
    int year,
    int month,
    int day,
    int hour,
    int min,
    double sec,
    double timezone,
  ) {
    final r = _swe.utcTimeZone(year, month, day, hour, min, sec, timezone);
    return (
      year: r.year,
      month: r.month,
      day: r.day,
      hour: r.hour,
      min: r.min,
      sec: r.sec,
    );
  }

  ({double et, double ut1}) utcToJd(
    int year,
    int month,
    int day,
    int hour,
    int min,
    double sec, {
    bool gregorian = true,
  }) {
    final r = _swe.utcToJd(
      year,
      month,
      day,
      hour,
      min,
      sec,
      gregorian: gregorian,
    );
    return (et: r.et, ut1: r.ut1);
  }

  ({int year, int month, int day, int hour, int min, double sec}) jdetToUtc(
    double jdEt, {
    bool gregorian = true,
  }) {
    final r = _swe.jdetToUtc(jdEt, gregorian: gregorian);
    return (
      year: r.year,
      month: r.month,
      day: r.day,
      hour: r.hour,
      min: r.min,
      sec: r.sec,
    );
  }

  ({int year, int month, int day, int hour, int min, double sec}) jdut1ToUtc(
    double jdUt, {
    bool gregorian = true,
  }) {
    final r = _swe.jdToUtc(jdUt, gregorian: gregorian);
    return (
      year: r.year,
      month: r.month,
      day: r.day,
      hour: r.hour,
      min: r.min,
      sec: r.sec,
    );
  }

  double deltat(double jd) {
    return _swe.deltat(jd);
  }

  double siderealTime(double jdUt) {
    return _swe.sidTime(jdUt);
  }

  double siderealTime0(double jdUt, double eps, double nut) {
    return _swe.sidTime0(jdUt, eps, nut);
  }

  double timeEqu(double jd) {
    return _swe.timeEqu(jd);
  }

  double lmtToLat(double jdLmt, double geolon) {
    return _swe.lmtToLat(jdLmt, geolon);
  }

  double latToLmt(double jdLat, double geolon) {
    return _swe.latToLmt(jdLat, geolon);
  }

  String getPlanetName(int body) {
    return _swe.getPlanetName(body);
  }

  ({int degrees, int minutes, int seconds, double secondsFraction, int sign})
  splitDeg(double degrees, int roundFlag) {
    final r = _swe.splitDeg(degrees, roundFlag);
    return (
      degrees: r.degrees,
      minutes: r.minutes,
      seconds: r.seconds,
      secondsFraction: r.secondsFraction,
      sign: r.sign,
    );
  }

  ({double lon, double lat, double dist}) cotrans(
    double lon,
    double lat,
    double dist,
    double eps,
  ) {
    final r = _swe.cotrans(lon, lat, dist, eps);
    return (lon: r.lon, lat: r.lat, dist: r.dist);
  }

  // -----------------------------------------------------------------------
  // Houses
  // -----------------------------------------------------------------------

  ({
    List<double> cusps,
    List<double> ascmc,
    List<double> cuspSpeeds,
    List<double> ascmcSpeeds,
  })
  houses(double jdUt, double geolat, double geolon, int hsys) {
    final r = _swe.housesEx2(jdUt, 0, geolat, geolon, hsys);
    return (
      cusps: r.cusps,
      ascmc: r.ascmc,
      cuspSpeeds: r.cuspSpeeds,
      ascmcSpeeds: r.ascmcSpeeds,
    );
  }

  ({
    List<double> cusps,
    List<double> ascmc,
    List<double> cuspSpeeds,
    List<double> ascmcSpeeds,
  })
  housesEx2(double jdUt, int flags, double geolat, double geolon, int hsys) {
    final r = _swe.housesEx2(jdUt, flags, geolat, geolon, hsys);
    return (
      cusps: r.cusps,
      ascmc: r.ascmc,
      cuspSpeeds: r.cuspSpeeds,
      ascmcSpeeds: r.ascmcSpeeds,
    );
  }

  ({List<double> cusps, List<double> ascmc}) housesArmc(
    double armc,
    double geolat,
    double eps,
    int hsys,
  ) {
    final r = _swe.housesArmc(armc, geolat, eps, hsys);
    return (cusps: r.cusps, ascmc: r.ascmc);
  }

  double housePos(
    double armc,
    double geolat,
    double eps,
    int hsys,
    double bodyLon,
    double bodyLat,
  ) {
    return _swe.housePos(armc, geolat, eps, hsys, bodyLon, bodyLat);
  }

  String houseName(int hsys) {
    return _swe.houseName(hsys);
  }

  double gauquelinSector(
    double jdUt,
    int body,
    int flags,
    int method, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 0,
    double attemp = 0,
  }) {
    return _swe.gauquelinSector(
      jdUt,
      body,
      flags,
      method,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atpress: atpress,
      attemp: attemp,
    );
  }

  // -----------------------------------------------------------------------
  // Ayanamsa
  // -----------------------------------------------------------------------

  double getAyanamsaEx(
    double jdEt,
    int flags,
    int sidMode, {
    double t0 = 0,
    double ayanT0 = 0,
  }) {
    _swe.setSidMode(sidMode, t0: t0, ayanT0: ayanT0);
    try {
      return _swe.getAyanamsaEx(jdEt, flags).ayanamsa;
    } finally {
      _swe.setSidMode(0);
    }
  }

  double getAyanamsaUt(
    double jdUt,
    int flags,
    int sidMode, {
    double t0 = 0,
    double ayanT0 = 0,
  }) {
    _swe.setSidMode(sidMode, t0: t0, ayanT0: ayanT0);
    try {
      return _swe.getAyanamsaExUt(jdUt, flags).ayanamsa;
    } finally {
      _swe.setSidMode(0);
    }
  }

  double getAyanamsa(
    double jdEt,
    int sidMode, {
    double t0 = 0,
    double ayanT0 = 0,
  }) {
    _swe.setSidMode(sidMode, t0: t0, ayanT0: ayanT0);
    try {
      return _swe.getAyanamsa(jdEt);
    } finally {
      _swe.setSidMode(0);
    }
  }

  String getAyanamsaName(int sidMode) {
    return _swe.getAyanamsaName(sidMode);
  }

  // -----------------------------------------------------------------------
  // Eclipses & occultations
  // -----------------------------------------------------------------------

  swe.SolarEclipseGlobalResult solEclipseWhenGlob(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    return _swe.solEclipseWhenGlob(
      jdStart,
      flags,
      eclType: eclType,
      backward: backward,
    );
  }

  swe.SolarEclipseLocalResult solEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    return _swe.solEclipseWhenLoc(
      jdStart,
      flags,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      backward: backward,
    );
  }

  swe.SolarEclipseAttrResult solEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    return _swe.solEclipseHow(
      jdUt,
      flags,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
    );
  }

  swe.EclipseWhereResult solEclipseWhere(double jdUt, int flags) {
    return _swe.solEclipseWhere(jdUt, flags);
  }

  swe.LunarEclipseAttrResult lunEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    return _swe.lunEclipseHow(
      jdUt,
      flags,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
    );
  }

  swe.LunarEclipseGlobalResult lunEclipseWhen(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    return _swe.lunEclipseWhen(
      jdStart,
      flags,
      eclType: eclType,
      backward: backward,
    );
  }

  swe.LunarEclipseLocalResult lunEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    return _swe.lunEclipseWhenLoc(
      jdStart,
      flags,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      backward: backward,
    );
  }

  swe.SolarEclipseGlobalResult lunOccultWhenGlob(
    double jdStart,
    int body,
    int flags, {
    String? starname,
    int eclType = 0,
    bool backward = false,
  }) {
    return _swe.lunOccultWhenGlob(
      jdStart,
      body,
      flags,
      starname: starname,
      eclType: eclType,
      backward: backward,
    );
  }

  swe.SolarEclipseLocalResult lunOccultWhenLoc(
    double jdStart,
    int body,
    int flags, {
    String? starname,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    return _swe.lunOccultWhenLoc(
      jdStart,
      body,
      flags,
      starname: starname,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      backward: backward,
    );
  }

  swe.EclipseWhereResult lunOccultWhere(
    double jdUt,
    int body,
    int flags, {
    String? starname,
  }) {
    return _swe.lunOccultWhere(jdUt, body, flags, starname: starname);
  }

  // -----------------------------------------------------------------------
  // Rise/set & crossings (task /32)
  // -----------------------------------------------------------------------

  swe.RiseTransResult riseTrans(
    double jdUt,
    int body, {
    String? starName,
    int epheflag = 0,
    int rsmi = swe.seCalcRise,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
  }) {
    return _swe.riseTrans(
      jdUt,
      body,
      starName: starName,
      epheflag: epheflag,
      rsmi: rsmi,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atpress: atpress,
      attemp: attemp,
    );
  }

  swe.RiseTransResult riseTransTrueHor(
    double jdUt,
    int body, {
    String? starName,
    int epheflag = 0,
    int rsmi = swe.seCalcRise,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    required double horizonHeight,
  }) {
    return _swe.riseTransTrueHor(
      jdUt,
      body,
      starName: starName,
      epheflag: epheflag,
      rsmi: rsmi,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atpress: atpress,
      attemp: attemp,
      horizonHeight: horizonHeight,
    );
  }

  double solcrossUt(double longitude, double jdUt, int flags) {
    return _swe.solCrossUt(longitude, jdUt, flags);
  }

  double solcross(double longitude, double jdEt, int flags) {
    return _swe.solCross(longitude, jdEt, flags);
  }

  double mooncrossUt(double longitude, double jdUt, int flags) {
    return _swe.moonCrossUt(longitude, jdUt, flags);
  }

  double mooncross(double longitude, double jdEt, int flags) {
    return _swe.moonCross(longitude, jdEt, flags);
  }

  swe.MoonNodeCrossResult mooncrossNodeUt(double jdUt, int flags) {
    return _swe.moonCrossNodeUt(jdUt, flags);
  }

  swe.MoonNodeCrossResult mooncrossNode(double jdEt, int flags) {
    return _swe.moonCrossNode(jdEt, flags);
  }

  double helioCrossUt(
    int body,
    double longitude,
    double jdUt,
    int flags,
    int dir,
  ) {
    return _swe.helioCrossUt(body, longitude, jdUt, flags, dir);
  }

  double helioCross(
    int body,
    double longitude,
    double jdEt,
    int flags,
    int dir,
  ) {
    return _swe.helioCross(body, longitude, jdEt, flags, dir);
  }

  // -----------------------------------------------------------------------
  // Phenomena, orbital, nodes/apsides (task /33)
  // -----------------------------------------------------------------------

  swe.PhenoResult phenoUt(double jdUt, int body, int flags) {
    return _swe.phenoUt(jdUt, body, flags);
  }

  swe.PhenoResult pheno(double jdEt, int body, int flags) {
    return _swe.pheno(jdEt, body, flags);
  }

  swe.NodeApsResult nodApsUt(double jdUt, int body, int flags, int method) {
    return _swe.nodApsUt(jdUt, body, flags, method);
  }

  swe.NodeApsResult nodAps(double jdEt, int body, int flags, int method) {
    return _swe.nodAps(jdEt, body, flags, method);
  }

  swe.OrbitalElementsResult getOrbitalElements(
    double jdEt,
    int body,
    int flags,
  ) {
    return _swe.getOrbitalElements(jdEt, body, flags);
  }

  swe.OrbitDistanceResult orbitMaxMinTrueDistance(
    double jdEt,
    int body,
    int flags,
  ) {
    return _swe.orbitMaxMinTrueDistance(jdEt, body, flags);
  }

  // -----------------------------------------------------------------------
  // Fixed stars (task /33)
  // -----------------------------------------------------------------------

  swe.FixstarResult fixstar2Ut(String star, double jdUt, int flags) {
    return _swe.fixstar2Ut(star, jdUt, flags);
  }

  swe.FixstarResult fixstar2(String star, double jdEt, int flags) {
    return _swe.fixstar2(star, jdEt, flags);
  }

  double fixstar2Mag(String star) {
    return _swe.fixstar2Mag(star);
  }

  // -----------------------------------------------------------------------
  // Heliacal (task /33)
  // -----------------------------------------------------------------------

  swe.HeliacalResult heliacalUt(
    double jdStart, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required swe.AtmoConditions atmo,
    required swe.ObserverConditions observer,
    required String objectName,
    required int typeEvent,
    int flags = 0,
  }) {
    return _swe.heliacalUt(
      jdStart,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atmo: atmo,
      observer: observer,
      objectName: objectName,
      typeEvent: typeEvent,
      flags: flags,
    );
  }

  swe.HeliacalPhenoResult heliacalPhenoUt(
    double jdUt, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required swe.AtmoConditions atmo,
    required swe.ObserverConditions observer,
    required String objectName,
    required int typeEvent,
    int flags = 0,
  }) {
    return _swe.heliacalPhenoUt(
      jdUt,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atmo: atmo,
      observer: observer,
      objectName: objectName,
      typeEvent: typeEvent,
      flags: flags,
    );
  }

  swe.VisLimitResult visLimitMag(
    double jdUt, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required swe.AtmoConditions atmo,
    required swe.ObserverConditions observer,
    required String objectName,
    int flags = 0,
  }) {
    return _swe.visLimitMag(
      jdUt,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atmo: atmo,
      observer: observer,
      objectName: objectName,
      flags: flags,
    );
  }

  swe.HeliacalAngleResult heliacalAngle(
    double jdUt, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required swe.AtmoConditions atmo,
    required swe.ObserverConditions observer,
    required int helflag,
    required double mag,
    required double aziObj,
    required double aziSun,
    required double aziMoon,
    required double altMoon,
  }) {
    return _swe.heliacalAngle(
      jdUt,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atmo: atmo,
      observer: observer,
      helflag: helflag,
      mag: mag,
      aziObj: aziObj,
      aziSun: aziSun,
      aziMoon: aziMoon,
      altMoon: altMoon,
    );
  }

  double topoArcusVisionis(
    double jdUt, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required swe.AtmoConditions atmo,
    required swe.ObserverConditions observer,
    required int helflag,
    required double mag,
    required double aziObj,
    required double altObj,
    required double aziSun,
    required double aziMoon,
    required double altMoon,
  }) {
    return _swe.topoArcusVisionis(
      jdUt,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atmo: atmo,
      observer: observer,
      helflag: helflag,
      mag: mag,
      aziObj: aziObj,
      altObj: altObj,
      aziSun: aziSun,
      aziMoon: aziMoon,
      altMoon: altMoon,
    );
  }

  // -----------------------------------------------------------------------
  // Horizon & refraction (task /34)
  // -----------------------------------------------------------------------

  swe.AzAltResult azalt(
    double jdUt,
    int calcFlag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    required double xin0,
    required double xin1,
  }) {
    return _swe.azAlt(
      jdUt,
      calcFlag,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atpress: atpress,
      attemp: attemp,
      bodyLon: xin0,
      bodyLat: xin1,
    );
  }

  swe.AzAltRevResult azaltRev(
    double jdUt,
    int calcFlag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required double azimuth,
    required double altitude,
  }) {
    return _swe.azAltRev(
      jdUt,
      calcFlag,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      azimuth: azimuth,
      altitude: altitude,
    );
  }

  double refrac(double altitude, double atpress, double attemp, int calcFlag) {
    return _swe.refrac(altitude, atpress, attemp, calcFlag);
  }

  swe.RefracResult refracExtended(
    double altitude,
    double geoalt,
    double atpress,
    double attemp,
    double lapseRate,
    int calcFlag,
  ) {
    return _swe.refracExtended(
      altitude,
      geoalt,
      atpress,
      attemp,
      lapseRate,
      calcFlag,
    );
  }

  void close() => _swe.close();
}
