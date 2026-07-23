// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'result_types.dart';

abstract class Ephemeris {
  CalcResult calcUt(double jdUt, int body, int flags);
  CalcResult calcPctr(double jdEt, int body, int centerBody, int flags);

  HouseResult houses(double jdUt, double geolat, double geolon, int hsys);

  /// House position of an ecliptic point under [hsys], as swisseph's
  /// `swe_house_pos`: returns a value in 1.0–12.999999 (1.0–36.99 for the
  /// Gauquelin sectors) whose integer part is the house number and whose
  /// fraction is the position within that house. [armc] and [eps] come from the
  /// [houses] call for the same Moment/place; [bodyLon]/[bodyLat] are the point's
  /// tropical ecliptic coordinates.
  double housePos(
    double armc,
    double geolat,
    double eps,
    int hsys,
    double bodyLon,
    double bodyLat,
  );

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

  /// Next occultation of a body ([body], a planet id) or a fixed star
  /// ([starName], overriding [body] when non-null) by the Moon, anywhere on
  /// Earth. Backs `swe_lun_occult_when_glob`.
  OccultGlobalResult lunOccultWhenGlob(
    double jdStart,
    int body,
    int flags, {
    String? starName,
    int eclType,
    bool backward,
  });

  /// Next occultation visible from a given place. Backs
  /// `swe_lun_occult_when_loc`.
  OccultLocalResult lunOccultWhenLoc(
    double jdStart,
    int body,
    int flags, {
    String? starName,
    required double geolon,
    required double geolat,
    double geoalt,
    bool backward,
  });

  /// Geographic position where the occultation is central/maximal. Backs
  /// `swe_lun_occult_where`.
  EclipseWhereResult lunOccultWhere(
    double jdUt,
    int body,
    int flags, {
    String? starName,
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
