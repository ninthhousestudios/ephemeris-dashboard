// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph/swisseph.dart';

abstract class Ephemeris {
  // Context setters (Applied Globals)

  void setEphePath(String path);
  void setSidMode(int sidMode, {double t0, double ayanT0});
  void setTopo(double geolon, double geolat, double geoalt);
  void setJplFile(String filename);

  // Calculation methods

  CalcResult calcUt(double jdUt, int body, int flags);
  CalcResult calcPctr(double jdEt, int body, int centerBody, int flags);

  HouseResult houses(double jdUt, double geolat, double geolon, int hsys);

  double gauquelinSector(
    double jdUt,
    int body,
    int flags,
    int method, {
    required double geolon,
    required double geolat,
    double geoalt,
    double atpress,
    double attemp,
    String? starName,
  });

  double getAyanamsaUt(double jdUt);
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags);

  FixstarResult fixstar2Ut(String star, double jdUt, int flags);

  double solCrossUt(double longitude, double jdUt, int flags);
  double moonCrossUt(double longitude, double jdUt, int flags);
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags);
  double helioCrossUt(
    int body,
    double longitude,
    double jdUt,
    int flags,
    int dir,
  );

  SolarEclipseLocalResult solEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt,
    bool backward,
  });

  SolarEclipseGlobalResult solEclipseWhenGlob(
    double jdStart,
    int flags, {
    int eclType,
    bool backward,
  });

  SolarEclipseAttrResult solEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt,
  });

  EclipseWhereResult solEclipseWhere(double jdUt, int flags);

  LunarEclipseGlobalResult lunEclipseWhen(
    double jdStart,
    int flags, {
    int eclType,
    bool backward,
  });

  LunarEclipseLocalResult lunEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt,
    bool backward,
  });

  LunarEclipseAttrResult lunEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt,
  });

  RiseTransResult riseTrans(
    double jdUt,
    int body, {
    String? starName,
    int epheflag,
    int rsmi,
    required double geolon,
    required double geolat,
    double geoalt,
    double atpress,
    double attemp,
  });

  RiseTransResult riseTransTrueHor(
    double jdUt,
    int body, {
    String? starName,
    int epheflag,
    int rsmi,
    required double geolon,
    required double geolat,
    double geoalt,
    double atpress,
    double attemp,
    required double horizonHeight,
  });

  AzAltResult azAlt(
    double jdUt,
    int calcFlag, {
    required double geolon,
    required double geolat,
    double geoalt,
    double atpress,
    double attemp,
    required double bodyLon,
    required double bodyLat,
    double bodyDist,
  });

  AzAltRevResult azAltRev(
    double jdUt,
    int calcFlag, {
    required double geolon,
    required double geolat,
    double geoalt,
    required double azimuth,
    required double altitude,
  });

  CoTransResult cotrans(double lon, double lat, double dist, double eps);
  double refrac(double altitude, double atpress, double attemp, int calcFlag);

  double deltat(double jd);
  double timeEqu(double jd);
  double sidTime(double jdUt);
  double sidTime0(double jdUt, double eps, double nut);
  double lmtToLat(double jdLmt, double geolon);
  double latToLmt(double jdLat, double geolon);

  NodeApsResult nodApsUt(double jdUt, int body, int flags, int method);
  OrbitalElementsResult getOrbitalElements(double jdEt, int body, int flags);
  OrbitDistanceResult orbitMaxMinTrueDistance(double jdEt, int body, int flags);

  PhenoResult phenoUt(double jdUt, int body, int flags);

  HeliacalResult heliacalUt(
    double jdStart, {
    required double geolon,
    required double geolat,
    double geoalt,
    required AtmoConditions atmo,
    required ObserverConditions observer,
    required String objectName,
    required int typeEvent,
    int flags,
  });
}
