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
  double Function(double jdUt)? onGetAyanamsaUt;
  AyanamsaResult Function(double jdUt, int flags)? onGetAyanamsaExUt;
  FixstarResult Function(String star, double jdUt, int flags)? onFixstar2Ut;
  double Function(double longitude, double jdUt, int flags)? onSolCrossUt;
  double Function(double longitude, double jdUt, int flags)? onMoonCrossUt;
  MoonNodeCrossResult Function(double jdUt, int flags)? onMoonCrossNodeUt;
  double Function(double jd)? onDeltat;
  double Function(double jdUt)? onSidTime;
  NodeApsResult Function(double jdUt, int body, int flags, int method)?
  onNodApsUt;
  OrbitalElementsResult Function(double jdEt, int body, int flags)?
  onGetOrbitalElements;
  PhenoResult Function(double jdUt, int body, int flags)? onPhenoUt;

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
  }) => throw UnimplementedError('gauquelinSector not scripted');

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
  ) => throw UnimplementedError('helioCrossUt not scripted');

  @override
  SolarEclipseLocalResult solEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) => throw UnimplementedError('solEclipseWhenLoc not scripted');

  @override
  SolarEclipseGlobalResult solEclipseWhenGlob(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) => throw UnimplementedError('solEclipseWhenGlob not scripted');

  @override
  SolarEclipseAttrResult solEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) => throw UnimplementedError('solEclipseHow not scripted');

  @override
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) =>
      throw UnimplementedError('solEclipseWhere not scripted');

  @override
  LunarEclipseGlobalResult lunEclipseWhen(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) => throw UnimplementedError('lunEclipseWhen not scripted');

  @override
  LunarEclipseLocalResult lunEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) => throw UnimplementedError('lunEclipseWhenLoc not scripted');

  @override
  LunarEclipseAttrResult lunEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) => throw UnimplementedError('lunEclipseHow not scripted');

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
  }) => throw UnimplementedError('riseTrans not scripted');

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
  }) => throw UnimplementedError('riseTransTrueHor not scripted');

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
  }) => throw UnimplementedError('azAlt not scripted');

  @override
  AzAltRevResult azAltRev(
    double jdUt,
    int calcFlag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required double azimuth,
    required double altitude,
  }) => throw UnimplementedError('azAltRev not scripted');

  @override
  CoTransResult cotrans(double lon, double lat, double dist, double eps) =>
      throw UnimplementedError('cotrans not scripted');

  @override
  double refrac(double altitude, double atpress, double attemp, int calcFlag) =>
      throw UnimplementedError('refrac not scripted');

  @override
  double deltat(double jd) {
    if (onDeltat == null) throw UnimplementedError('deltat not scripted');
    return onDeltat!(jd);
  }

  @override
  double timeEqu(double jd) => throw UnimplementedError('timeEqu not scripted');

  @override
  double sidTime(double jdUt) {
    if (onSidTime == null) throw UnimplementedError('sidTime not scripted');
    return onSidTime!(jdUt);
  }

  @override
  double sidTime0(double jdUt, double eps, double nut) =>
      throw UnimplementedError('sidTime0 not scripted');

  @override
  double lmtToLat(double jdLmt, double geolon) =>
      throw UnimplementedError('lmtToLat not scripted');

  @override
  double latToLmt(double jdLat, double geolon) =>
      throw UnimplementedError('latToLmt not scripted');

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
  ) => throw UnimplementedError('orbitMaxMinTrueDistance not scripted');

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
  }) => throw UnimplementedError('heliacalUt not scripted');
}
