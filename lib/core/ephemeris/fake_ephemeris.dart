import 'package:swisseph/swisseph.dart';

import 'ephemeris.dart';

class FakeEphemeris implements Ephemeris {
  final List<({String method, Map<String, Object?> args})> contextCalls = [];

  // Context setters — record for assertion

  @override
  void setEphePath(String path) =>
      contextCalls.add((method: 'setEphePath', args: {'path': path}));

  @override
  void setSidMode(int sidMode, {double t0 = 0, double ayanT0 = 0}) =>
      contextCalls.add((
        method: 'setSidMode',
        args: {'sidMode': sidMode, 't0': t0, 'ayanT0': ayanT0},
      ));

  @override
  void setTopo(double geolon, double geolat, double geoalt) =>
      contextCalls.add((
        method: 'setTopo',
        args: {'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt},
      ));

  @override
  void setJplFile(String filename) =>
      contextCalls.add((method: 'setJplFile', args: {'filename': filename}));

  // Calculation methods — optional callbacks

  CalcResult Function(double jdUt, int body, int flags)? onCalcUt;
  CalcResult Function(double jdEt, int body, int centerBody, int flags)?
  onCalcPctr;
  HouseResult Function(double jdUt, double geolat, double geolon, int hsys)?
  onHouses;
  double Function(double jdUt, int body, int flags, int method)?
  onGauquelinSector;
  double Function(double jdUt)? onGetAyanamsaUt;
  AyanamsaResult Function(double jdUt, int flags)? onGetAyanamsaExUt;
  FixstarResult Function(String star, double jdUt, int flags)? onFixstar2Ut;
  double Function(double longitude, double jdUt, int flags)? onSolCrossUt;
  double Function(double longitude, double jdUt, int flags)? onMoonCrossUt;
  MoonNodeCrossResult Function(double jdUt, int flags)? onMoonCrossNodeUt;
  double Function(int body, double longitude, double jdUt, int flags, int dir)?
  onHelioCrossUt;
  SolarEclipseLocalResult Function(double jdStart, int flags)?
  onSolEclipseWhenLoc;
  SolarEclipseGlobalResult Function(double jdStart, int flags)?
  onSolEclipseWhenGlob;
  SolarEclipseAttrResult Function(double jdUt, int flags)? onSolEclipseHow;
  EclipseWhereResult Function(double jdUt, int flags)? onSolEclipseWhere;
  LunarEclipseGlobalResult Function(double jdStart, int flags)?
  onLunEclipseWhen;
  LunarEclipseLocalResult Function(double jdStart, int flags)?
  onLunEclipseWhenLoc;
  LunarEclipseAttrResult Function(double jdUt, int flags)? onLunEclipseHow;
  RiseTransResult Function(double jdUt, int body)? onRiseTrans;
  RiseTransResult Function(double jdUt, int body)? onRiseTransTrueHor;
  AzAltResult Function(double jdUt, int calcFlag)? onAzAlt;
  AzAltRevResult Function(double jdUt, int calcFlag)? onAzAltRev;
  CoTransResult Function(double lon, double lat, double dist, double eps)?
  onCotrans;
  double Function(double altitude, double atpress, double attemp, int calcFlag)?
  onRefrac;
  double Function(double jd)? onDeltat;
  double Function(double jd)? onTimeEqu;
  double Function(double jdUt)? onSidTime;
  double Function(double jdUt, double eps, double nut)? onSidTime0;
  double Function(double jdLmt, double geolon)? onLmtToLat;
  double Function(double jdLat, double geolon)? onLatToLmt;
  NodeApsResult Function(double jdUt, int body, int flags, int method)?
  onNodApsUt;
  OrbitalElementsResult Function(double jdEt, int body, int flags)?
  onGetOrbitalElements;
  OrbitDistanceResult Function(double jdEt, int body, int flags)?
  onOrbitMaxMinTrueDistance;
  PhenoResult Function(double jdUt, int body, int flags)? onPhenoUt;
  HeliacalResult Function(double jdStart, int typeEvent)? onHeliacalUt;

  @override
  CalcResult calcUt(double jdUt, int body, int flags) {
    if (onCalcUt == null) throw UnimplementedError('calcUt not scripted');
    return onCalcUt!(jdUt, body, flags);
  }

  @override
  CalcResult calcPctr(double jdEt, int body, int centerBody, int flags) {
    if (onCalcPctr == null) throw UnimplementedError('calcPctr not scripted');
    return onCalcPctr!(jdEt, body, centerBody, flags);
  }

  @override
  HouseResult houses(double jdUt, double geolat, double geolon, int hsys) {
    if (onHouses == null) throw UnimplementedError('houses not scripted');
    return onHouses!(jdUt, geolat, geolon, hsys);
  }

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
    if (onGauquelinSector == null) {
      throw UnimplementedError('gauquelinSector not scripted');
    }
    return onGauquelinSector!(jdUt, body, flags, method);
  }

  @override
  double getAyanamsaUt(double jdUt) {
    if (onGetAyanamsaUt == null) {
      throw UnimplementedError('getAyanamsaUt not scripted');
    }
    return onGetAyanamsaUt!(jdUt);
  }

  @override
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags) {
    if (onGetAyanamsaExUt == null) {
      throw UnimplementedError('getAyanamsaExUt not scripted');
    }
    return onGetAyanamsaExUt!(jdUt, flags);
  }

  @override
  FixstarResult fixstar2Ut(String star, double jdUt, int flags) {
    if (onFixstar2Ut == null) {
      throw UnimplementedError('fixstar2Ut not scripted');
    }
    return onFixstar2Ut!(star, jdUt, flags);
  }

  @override
  double solCrossUt(double longitude, double jdUt, int flags) {
    if (onSolCrossUt == null) {
      throw UnimplementedError('solCrossUt not scripted');
    }
    return onSolCrossUt!(longitude, jdUt, flags);
  }

  @override
  double moonCrossUt(double longitude, double jdUt, int flags) {
    if (onMoonCrossUt == null) {
      throw UnimplementedError('moonCrossUt not scripted');
    }
    return onMoonCrossUt!(longitude, jdUt, flags);
  }

  @override
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags) {
    if (onMoonCrossNodeUt == null) {
      throw UnimplementedError('moonCrossNodeUt not scripted');
    }
    return onMoonCrossNodeUt!(jdUt, flags);
  }

  @override
  double helioCrossUt(
    int body,
    double longitude,
    double jdUt,
    int flags,
    int dir,
  ) {
    if (onHelioCrossUt == null) {
      throw UnimplementedError('helioCrossUt not scripted');
    }
    return onHelioCrossUt!(body, longitude, jdUt, flags, dir);
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
    if (onSolEclipseWhenLoc == null) {
      throw UnimplementedError('solEclipseWhenLoc not scripted');
    }
    return onSolEclipseWhenLoc!(jdStart, flags);
  }

  @override
  SolarEclipseGlobalResult solEclipseWhenGlob(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    if (onSolEclipseWhenGlob == null) {
      throw UnimplementedError('solEclipseWhenGlob not scripted');
    }
    return onSolEclipseWhenGlob!(jdStart, flags);
  }

  @override
  SolarEclipseAttrResult solEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    if (onSolEclipseHow == null) {
      throw UnimplementedError('solEclipseHow not scripted');
    }
    return onSolEclipseHow!(jdUt, flags);
  }

  @override
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) {
    if (onSolEclipseWhere == null) {
      throw UnimplementedError('solEclipseWhere not scripted');
    }
    return onSolEclipseWhere!(jdUt, flags);
  }

  @override
  LunarEclipseGlobalResult lunEclipseWhen(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    if (onLunEclipseWhen == null) {
      throw UnimplementedError('lunEclipseWhen not scripted');
    }
    return onLunEclipseWhen!(jdStart, flags);
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
    if (onLunEclipseWhenLoc == null) {
      throw UnimplementedError('lunEclipseWhenLoc not scripted');
    }
    return onLunEclipseWhenLoc!(jdStart, flags);
  }

  @override
  LunarEclipseAttrResult lunEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    if (onLunEclipseHow == null) {
      throw UnimplementedError('lunEclipseHow not scripted');
    }
    return onLunEclipseHow!(jdUt, flags);
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
    if (onRiseTrans == null) {
      throw UnimplementedError('riseTrans not scripted');
    }
    return onRiseTrans!(jdUt, body);
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
    if (onRiseTransTrueHor == null) {
      throw UnimplementedError('riseTransTrueHor not scripted');
    }
    return onRiseTransTrueHor!(jdUt, body);
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
    if (onAzAlt == null) throw UnimplementedError('azAlt not scripted');
    return onAzAlt!(jdUt, calcFlag);
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
    if (onAzAltRev == null) throw UnimplementedError('azAltRev not scripted');
    return onAzAltRev!(jdUt, calcFlag);
  }

  @override
  CoTransResult cotrans(double lon, double lat, double dist, double eps) {
    if (onCotrans == null) throw UnimplementedError('cotrans not scripted');
    return onCotrans!(lon, lat, dist, eps);
  }

  @override
  double refrac(double altitude, double atpress, double attemp, int calcFlag) {
    if (onRefrac == null) throw UnimplementedError('refrac not scripted');
    return onRefrac!(altitude, atpress, attemp, calcFlag);
  }

  @override
  double deltat(double jd) {
    if (onDeltat == null) throw UnimplementedError('deltat not scripted');
    return onDeltat!(jd);
  }

  @override
  double timeEqu(double jd) {
    if (onTimeEqu == null) throw UnimplementedError('timeEqu not scripted');
    return onTimeEqu!(jd);
  }

  @override
  double sidTime(double jdUt) {
    if (onSidTime == null) throw UnimplementedError('sidTime not scripted');
    return onSidTime!(jdUt);
  }

  @override
  double sidTime0(double jdUt, double eps, double nut) {
    if (onSidTime0 == null) throw UnimplementedError('sidTime0 not scripted');
    return onSidTime0!(jdUt, eps, nut);
  }

  @override
  double lmtToLat(double jdLmt, double geolon) {
    if (onLmtToLat == null) throw UnimplementedError('lmtToLat not scripted');
    return onLmtToLat!(jdLmt, geolon);
  }

  @override
  double latToLmt(double jdLat, double geolon) {
    if (onLatToLmt == null) throw UnimplementedError('latToLmt not scripted');
    return onLatToLmt!(jdLat, geolon);
  }

  @override
  NodeApsResult nodApsUt(double jdUt, int body, int flags, int method) {
    if (onNodApsUt == null) throw UnimplementedError('nodApsUt not scripted');
    return onNodApsUt!(jdUt, body, flags, method);
  }

  @override
  OrbitalElementsResult getOrbitalElements(double jdEt, int body, int flags) {
    if (onGetOrbitalElements == null) {
      throw UnimplementedError('getOrbitalElements not scripted');
    }
    return onGetOrbitalElements!(jdEt, body, flags);
  }

  @override
  OrbitDistanceResult orbitMaxMinTrueDistance(
    double jdEt,
    int body,
    int flags,
  ) {
    if (onOrbitMaxMinTrueDistance == null) {
      throw UnimplementedError('orbitMaxMinTrueDistance not scripted');
    }
    return onOrbitMaxMinTrueDistance!(jdEt, body, flags);
  }

  @override
  PhenoResult phenoUt(double jdUt, int body, int flags) {
    if (onPhenoUt == null) throw UnimplementedError('phenoUt not scripted');
    return onPhenoUt!(jdUt, body, flags);
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
    if (onHeliacalUt == null) {
      throw UnimplementedError('heliacalUt not scripted');
    }
    return onHeliacalUt!(jdStart, typeEvent);
  }
}
