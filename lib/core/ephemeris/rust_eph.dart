// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph_rs/swisseph_rs.dart' as rs;

import 'ephemeris.dart';
import 'result_types.dart';

class RustEph implements Ephemeris {
  RustEph([rs.EphemerisConfig? config])
    : _engine = rs.Ephemeris(config ?? const rs.EphemerisConfig());

  rs.Ephemeris _engine;

  rs.Ephemeris get engine => _engine;

  void reconfigure(rs.EphemerisConfig config) {
    final replacement = rs.Ephemeris(config);
    _engine.close();
    _engine = replacement;
  }

  void close() {
    _engine.close();
  }

  // --------------- Core calculation families ---------------

  @override
  CalcResult calcUt(double jdUt, int body, int flags) {
    final r = _engine.calcUt(
      rs.JdUt1(jdUt),
      rs.Body.fromRawId(body),
      rs.CalcFlags(flags),
    );
    return CalcResult(
      longitude: r.longitude,
      latitude: r.latitude,
      distance: r.distance,
      longitudeSpeed: r.longitudeSpeed,
      latitudeSpeed: r.latitudeSpeed,
      distanceSpeed: r.distanceSpeed,
      returnFlag: r.flagsUsed.value,
    );
  }

  @override
  CalcResult calcPctr(double jdEt, int body, int centerBody, int flags) {
    final r = _engine.calcPctr(
      rs.JdTt(jdEt),
      rs.Body.fromRawId(body),
      rs.Body.fromRawId(centerBody),
      rs.CalcFlags(flags),
    );
    return CalcResult(
      longitude: r.longitude,
      latitude: r.latitude,
      distance: r.distance,
      longitudeSpeed: r.longitudeSpeed,
      latitudeSpeed: r.latitudeSpeed,
      distanceSpeed: r.distanceSpeed,
      returnFlag: r.flagsUsed.value,
    );
  }

  @override
  HouseResult houses(double jdUt, double geolat, double geolon, int hsys) {
    final houseSystem =
        rs.HouseSystem.fromCharCode(hsys) ?? rs.HouseSystem.placidus;
    final r = _engine.houses(rs.JdUt1(jdUt), geolat, geolon, houseSystem);
    return HouseResult(
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
  }

  @override
  double housePos(
    double armc,
    double geolat,
    double eps,
    int hsys,
    double bodyLon,
    double bodyLat,
  ) {
    final houseSystem =
        rs.HouseSystem.fromCharCode(hsys) ?? rs.HouseSystem.placidus;
    return rs.housePos(armc, geolat, eps, houseSystem, bodyLon, bodyLat);
  }

  @override
  double getAyanamsaUt(double jdUt) {
    final r = _engine.getAyanamsaUt(rs.JdUt1(jdUt), const rs.CalcFlags(0));
    return r.ayanamsa;
  }

  @override
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags) {
    final (:ayanamsa, :flagsUsed) = _engine.getAyanamsaUt(
      rs.JdUt1(jdUt),
      rs.CalcFlags(flags),
    );
    return AyanamsaResult(ayanamsa: ayanamsa, returnFlag: flagsUsed.value);
  }

  @override
  double deltat(double jd) {
    return _engine.deltaT(rs.JdUt1(jd));
  }

  @override
  double sidTime(double jdUt) {
    return _engine.siderealTime(rs.JdUt1(jdUt));
  }

  @override
  double sidTime0(double jdUt, double eps, double nut) {
    return _engine.siderealTime0(rs.JdUt1(jdUt), eps, nut);
  }

  @override
  double timeEqu(double jd) {
    return _engine.timeEqu(jd);
  }

  @override
  double lmtToLat(double jdLmt, double geolon) {
    return _engine.lmtToLat(jdLmt, geolon);
  }

  @override
  double latToLmt(double jdLat, double geolon) {
    return _engine.latToLmt(jdLat, geolon);
  }

  @override
  CoTransResult cotrans(double lon, double lat, double dist, double eps) {
    final r = rs.cotrans(lon, lat, dist, eps);
    return CoTransResult(lon: r[0], lat: r[1], dist: r[2]);
  }

  @override
  double refrac(double altitude, double atpress, double attemp, int calcFlag) {
    final dir = calcFlag == 0 ? rs.RefracDir.trueToApp : rs.RefracDir.appToTrue;
    return rs.refrac(altitude, atpress, attemp, dir);
  }

  // --------------- Crossings ---------------

  @override
  double solCrossUt(double longitude, double jdUt, int flags) {
    return _engine.solcrossUt(longitude, rs.JdUt1(jdUt), rs.CalcFlags(flags));
  }

  @override
  double moonCrossUt(double longitude, double jdUt, int flags) {
    return _engine.mooncrossUt(longitude, rs.JdUt1(jdUt), rs.CalcFlags(flags));
  }

  @override
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags) {
    final r = _engine.mooncrossNodeUt(rs.JdUt1(jdUt), rs.CalcFlags(flags));
    return MoonNodeCrossResult(
      jdUt: r.jd,
      longitude: r.longitude,
      latitude: r.latitude,
    );
  }

  @override
  double helioCrossUt(
    int body,
    double longitude,
    double jdUt,
    int flags,
    int dir,
  ) {
    return _engine.helioCrossUt(
      rs.Body.fromRawId(body),
      longitude,
      rs.JdUt1(jdUt),
      rs.CalcFlags(flags),
      dir: dir,
    );
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
    final r = _engine.solEclipseWhenLoc(
      rs.JdUt1(jdStart),
      rs.CalcFlags(flags),
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      backward: backward,
    );
    return SolarEclipseLocalResult(
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
  }

  @override
  SolarEclipseGlobalResult solEclipseWhenGlob(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    final r = _engine.solEclipseWhenGlob(
      rs.JdUt1(jdStart),
      rs.CalcFlags(flags),
      eclType: rs.EclipseFlags(eclType),
      backward: backward,
    );
    return SolarEclipseGlobalResult(
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
  }

  @override
  SolarEclipseAttrResult solEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    final r = _engine.solEclipseHow(
      rs.JdUt1(jdUt),
      rs.CalcFlags(flags),
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
    );
    return SolarEclipseAttrResult(
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
  }

  @override
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) {
    final r = _engine.solEclipseWhere(rs.JdUt1(jdUt), rs.CalcFlags(flags));
    return EclipseWhereResult(
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
  }

  @override
  LunarEclipseGlobalResult lunEclipseWhen(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    final r = _engine.lunEclipseWhen(
      rs.JdUt1(jdStart),
      rs.CalcFlags(flags),
      eclType: rs.EclipseFlags(eclType),
      backward: backward,
    );
    return LunarEclipseGlobalResult(
      maxEclipse: r.timeMaximum,
      partialBegin: r.timePartialBegin,
      partialEnd: r.timePartialEnd,
      totalityBegin: r.timeTotalityBegin,
      totalityEnd: r.timeTotalityEnd,
      penumbralBegin: r.timePenumbralBegin,
      penumbralEnd: r.timePenumbralEnd,
      returnFlag: r.flags.value,
    );
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
    final r = _engine.lunEclipseWhenLoc(
      rs.JdUt1(jdStart),
      rs.CalcFlags(flags),
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      backward: backward,
    );
    return LunarEclipseLocalResult(
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
  }

  @override
  LunarEclipseAttrResult lunEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    final r = _engine.lunEclipseHow(
      rs.JdUt1(jdUt),
      rs.CalcFlags(flags),
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
    );
    return LunarEclipseAttrResult(
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
  }

  // --------------- Occultations ---------------

  @override
  OccultGlobalResult lunOccultWhenGlob(
    double jdStart,
    int body,
    int flags, {
    String? starName,
    int eclType = 0,
    bool backward = false,
  }) {
    final r = _engine.lunOccultWhenGlob(
      rs.JdUt1(jdStart),
      rs.Body.fromRawId(body),
      rs.CalcFlags(flags),
      starname: starName,
      eclType: rs.EclipseFlags(eclType),
      backward: backward,
    );
    return OccultGlobalResult(
      maxEclipse: r.timeMaximum,
      localNoon: r.timeRaConjunction,
      begin: r.timeBegin,
      end: r.timeEnd,
      totalityBegin: r.timeTotalityBegin,
      totalityEnd: r.timeTotalityEnd,
      centerLineBegin: r.timeCenterlineBegin,
      centerLineEnd: r.timeCenterlineEnd,
      returnFlag: r.flags.value,
    );
  }

  @override
  OccultLocalResult lunOccultWhenLoc(
    double jdStart,
    int body,
    int flags, {
    String? starName,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    final r = _engine.lunOccultWhenLoc(
      rs.JdUt1(jdStart),
      rs.Body.fromRawId(body),
      rs.CalcFlags(flags),
      starname: starName,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      backward: backward,
    );
    return OccultLocalResult(
      maxEclipse: r.timeMaximum,
      firstContact: r.timeFirstContact,
      secondContact: r.timeSecondContact,
      thirdContact: r.timeThirdContact,
      fourthContact: r.timeFourthContact,
      rise: r.timeRise,
      set: r.timeSet,
      magnitude: r.attr.magnitude,
      diameterRatio: r.attr.diameterRatio,
      obscuration: r.attr.obscuration,
      coreShadowKm: r.attr.coreDiameterKm,
      azimuth: r.attr.azimuth,
      trueAltitude: r.attr.trueAltitude,
      apparentAltitude: r.attr.apparentAltitude,
      elongation: r.attr.elongation,
      returnFlag: r.flags.value,
    );
  }

  @override
  EclipseWhereResult lunOccultWhere(
    double jdUt,
    int body,
    int flags, {
    String? starName,
  }) {
    final r = _engine.lunOccultWhere(
      rs.JdUt1(jdUt),
      rs.Body.fromRawId(body),
      rs.CalcFlags(flags),
      starname: starName,
    );
    return EclipseWhereResult(
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
    return RiseTransResult(transitTime: r.time);
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
    return RiseTransResult(transitTime: r.time);
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
    return AzAltResult(
      azimuth: r.azimuth,
      trueAltitude: r.trueAltitude,
      apparentAltitude: r.apparentAltitude,
    );
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
    return AzAltRevResult(lon: r.lon, lat: r.lat);
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
    final r = _engine.nodApsUt(
      rs.JdUt1(jdUt),
      rs.Body.fromRawId(body),
      rs.CalcFlags(flags),
      rs.NodApsMethod(method),
    );
    return NodeApsResult(
      ascending: _calcResultFrom6(r.ascending),
      descending: _calcResultFrom6(r.descending),
      perihelion: _calcResultFrom6(r.perihelion),
      aphelion: _calcResultFrom6(r.aphelion),
    );
  }

  @override
  OrbitalElementsResult getOrbitalElements(double jdEt, int body, int flags) {
    final r = _engine.getOrbitalElements(
      rs.JdTt(jdEt),
      rs.Body.fromRawId(body),
      rs.CalcFlags(flags),
    );
    return OrbitalElementsResult(
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
  }

  @override
  OrbitDistanceResult orbitMaxMinTrueDistance(
    double jdEt,
    int body,
    int flags,
  ) {
    final r = _engine.orbitMaxMinTrueDistance(
      rs.JdTt(jdEt),
      rs.Body.fromRawId(body),
      rs.CalcFlags(flags),
    );
    return OrbitDistanceResult(
      maxDist: r.max,
      minDist: r.min,
      trueDist: r.trueDist,
    );
  }

  @override
  PhenoResult phenoUt(double jdUt, int body, int flags) {
    final r = _engine.phenoUt(
      rs.JdUt1(jdUt),
      rs.Body.fromRawId(body),
      rs.CalcFlags(flags),
    );
    return PhenoResult(
      phaseAngle: r.phaseAngle,
      phase: r.phase,
      elongation: r.elongation,
      apparentDiameter: r.apparentDiameter,
      apparentMagnitude: r.apparentMagnitude,
    );
  }

  // --------------- Stars ---------------

  @override
  FixstarResult fixstar2Ut(String star, double jdUt, int flags) {
    final r = _engine.fixstar2Ut(star, rs.JdUt1(jdUt), rs.CalcFlags(flags));
    return FixstarResult(
      starName: r.starName,
      longitude: r.longitude,
      latitude: r.latitude,
      distance: r.distance,
      longitudeSpeed: r.longitudeSpeed,
      latitudeSpeed: r.latitudeSpeed,
      distanceSpeed: r.distanceSpeed,
      returnFlag: r.flagsUsed.value,
    );
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
    return _engine.gauquelinSector(
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
    final eventType =
        _heliacalEventTypes[typeEvent] ?? rs.HeliacalEventType.morningFirst;
    // OPTICAL_PARAMS is what makes swe_heliacal_ut *read* the four optical
    // arguments below — without it they are zeroed on entry and the four
    // instrument inputs the tab collects are silently inert. Setting it
    // unconditionally is safe: with magnification 0 (the naked-eye default) SE
    // still falls back to naked-eye binocular vision, so an unconfigured
    // observer gets the same answer either way.
    final r = _engine.heliacalUt(
      rs.JdUt1(jdStart),
      objectName,
      eventType,
      rs.CalcFlags(flags),
      rs.HeliacalFlags.opticalParams,
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
      transmission: observer.transmission,
    );
    return HeliacalResult(
      startVisible: r.startVisible,
      bestVisible: r.optimumVisibility,
      endVisible: r.endVisible,
    );
  }
}
