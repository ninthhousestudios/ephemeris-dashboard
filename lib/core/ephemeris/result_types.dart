// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

class CalcResult {
  final double longitude;
  final double latitude;
  final double distance;
  final double longitudeSpeed;
  final double latitudeSpeed;
  final double distanceSpeed;
  final int returnFlag;

  const CalcResult({
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.longitudeSpeed,
    required this.latitudeSpeed,
    required this.distanceSpeed,
    required this.returnFlag,
  });

  @override
  String toString() =>
      'CalcResult(lon: $longitude, lat: $latitude, dist: $distance, '
      'lonSpd: $longitudeSpeed, latSpd: $latitudeSpeed, distSpd: $distanceSpeed)';
}

class HouseResult {
  final List<double> cusps;
  final List<double> ascmc;
  final int returnFlag;

  const HouseResult({
    required this.cusps,
    required this.ascmc,
    required this.returnFlag,
  });

  double get ascendant => ascmc[0];
  double get mc => ascmc[1];
  double get armc => ascmc[2];
  double get vertex => ascmc[3];
}

class AyanamsaResult {
  final double ayanamsa;
  final int returnFlag;

  const AyanamsaResult({required this.ayanamsa, required this.returnFlag});
}

class DateResult {
  final int year;
  final int month;
  final int day;
  final double hour;

  const DateResult({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
  });

  @override
  String toString() => 'DateResult($year-$month-$day ${hour}h)';
}

class RiseTransResult {
  final double transitTime;
  final int returnFlag;

  const RiseTransResult({required this.transitTime, required this.returnFlag});
}

class FixstarResult {
  final String starName;
  final double longitude;
  final double latitude;
  final double distance;
  final double longitudeSpeed;
  final double latitudeSpeed;
  final double distanceSpeed;
  final int returnFlag;

  const FixstarResult({
    required this.starName,
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.longitudeSpeed,
    required this.latitudeSpeed,
    required this.distanceSpeed,
    required this.returnFlag,
  });
}

class MoonNodeCrossResult {
  final double jdUt;
  final double longitude;
  final double latitude;

  const MoonNodeCrossResult({
    required this.jdUt,
    required this.longitude,
    required this.latitude,
  });
}

class SolarEclipseLocalResult {
  final double maxEclipse;
  final double firstContact;
  final double secondContact;
  final double thirdContact;
  final double fourthContact;
  final double sunrise;
  final double sunset;
  final double magnitude;
  final double diameterRatio;
  final double obscuration;
  final double coreShadowKm;
  final double sunAzimuth;
  final double sunTrueAltitude;
  final double sunApparentAltitude;
  final double moonSunAngle;
  final double magnitudeNasa;
  final double sarosSeries;
  final double sarosMember;
  final int returnFlag;

  const SolarEclipseLocalResult({
    required this.maxEclipse,
    required this.firstContact,
    required this.secondContact,
    required this.thirdContact,
    required this.fourthContact,
    required this.sunrise,
    required this.sunset,
    required this.magnitude,
    required this.diameterRatio,
    required this.obscuration,
    required this.coreShadowKm,
    required this.sunAzimuth,
    required this.sunTrueAltitude,
    required this.sunApparentAltitude,
    required this.moonSunAngle,
    required this.magnitudeNasa,
    required this.sarosSeries,
    required this.sarosMember,
    required this.returnFlag,
  });
}

class SolarEclipseGlobalResult {
  final double maxEclipse;
  final double localNoon;
  final double begin;
  final double end;
  final double totalityBegin;
  final double totalityEnd;
  final double centerLineBegin;
  final double centerLineEnd;
  final double annularTotalBegin;
  final double annularTotalEnd;
  final int returnFlag;

  const SolarEclipseGlobalResult({
    required this.maxEclipse,
    required this.localNoon,
    required this.begin,
    required this.end,
    required this.totalityBegin,
    required this.totalityEnd,
    required this.centerLineBegin,
    required this.centerLineEnd,
    required this.annularTotalBegin,
    required this.annularTotalEnd,
    required this.returnFlag,
  });
}

class SolarEclipseAttrResult {
  final double magnitude;
  final double diameterRatio;
  final double obscuration;
  final double coreShadowKm;
  final double sunAzimuth;
  final double sunTrueAltitude;
  final double sunApparentAltitude;
  final double moonSunAngle;
  final double magnitudeNasa;
  final double sarosSeries;
  final double sarosMember;
  final int returnFlag;

  const SolarEclipseAttrResult({
    required this.magnitude,
    required this.diameterRatio,
    required this.obscuration,
    required this.coreShadowKm,
    required this.sunAzimuth,
    required this.sunTrueAltitude,
    required this.sunApparentAltitude,
    required this.moonSunAngle,
    required this.magnitudeNasa,
    required this.sarosSeries,
    required this.sarosMember,
    required this.returnFlag,
  });
}

class EclipseWhereResult {
  final double geolon;
  final double geolat;
  final double magnitude;
  final double diameterRatio;
  final double obscuration;
  final double coreShadowKm;
  final double sunAzimuth;
  final double sunTrueAltitude;
  final double sunApparentAltitude;
  final double moonSunAngle;
  final int returnFlag;

  const EclipseWhereResult({
    required this.geolon,
    required this.geolat,
    required this.magnitude,
    required this.diameterRatio,
    required this.obscuration,
    required this.coreShadowKm,
    required this.sunAzimuth,
    required this.sunTrueAltitude,
    required this.sunApparentAltitude,
    required this.moonSunAngle,
    required this.returnFlag,
  });
}

class LunarEclipseGlobalResult {
  final double maxEclipse;
  final double partialBegin;
  final double partialEnd;
  final double totalityBegin;
  final double totalityEnd;
  final double penumbralBegin;
  final double penumbralEnd;
  final int returnFlag;

  const LunarEclipseGlobalResult({
    required this.maxEclipse,
    required this.partialBegin,
    required this.partialEnd,
    required this.totalityBegin,
    required this.totalityEnd,
    required this.penumbralBegin,
    required this.penumbralEnd,
    required this.returnFlag,
  });
}

class LunarEclipseLocalResult {
  final double maxEclipse;
  final double partialBegin;
  final double partialEnd;
  final double totalityBegin;
  final double totalityEnd;
  final double penumbralBegin;
  final double penumbralEnd;
  final double moonrise;
  final double moonset;
  final double umbralMagnitude;
  final double penumbralMagnitude;
  final double moonAzimuth;
  final double moonTrueAltitude;
  final double moonApparentAltitude;
  final double moonOppositionAngle;
  final double sarosSeries;
  final double sarosMember;
  final int returnFlag;

  const LunarEclipseLocalResult({
    required this.maxEclipse,
    required this.partialBegin,
    required this.partialEnd,
    required this.totalityBegin,
    required this.totalityEnd,
    required this.penumbralBegin,
    required this.penumbralEnd,
    required this.moonrise,
    required this.moonset,
    required this.umbralMagnitude,
    required this.penumbralMagnitude,
    required this.moonAzimuth,
    required this.moonTrueAltitude,
    required this.moonApparentAltitude,
    required this.moonOppositionAngle,
    required this.sarosSeries,
    required this.sarosMember,
    required this.returnFlag,
  });
}

class LunarEclipseAttrResult {
  final double umbralMagnitude;
  final double penumbralMagnitude;
  final double moonAzimuth;
  final double moonTrueAltitude;
  final double moonApparentAltitude;
  final double moonOppositionAngle;
  final double sarosSeries;
  final double sarosMember;
  final int returnFlag;

  const LunarEclipseAttrResult({
    required this.umbralMagnitude,
    required this.penumbralMagnitude,
    required this.moonAzimuth,
    required this.moonTrueAltitude,
    required this.moonApparentAltitude,
    required this.moonOppositionAngle,
    required this.sarosSeries,
    required this.sarosMember,
    required this.returnFlag,
  });
}

class AzAltResult {
  final double azimuth;
  final double trueAltitude;
  final double apparentAltitude;

  const AzAltResult({
    required this.azimuth,
    required this.trueAltitude,
    required this.apparentAltitude,
  });
}

class AzAltRevResult {
  final double lon;
  final double lat;

  const AzAltRevResult({required this.lon, required this.lat});
}

class CoTransResult {
  final double lon;
  final double lat;
  final double dist;

  const CoTransResult({
    required this.lon,
    required this.lat,
    required this.dist,
  });
}

class NodeApsResult {
  final CalcResult ascending;
  final CalcResult descending;
  final CalcResult perihelion;
  final CalcResult aphelion;

  const NodeApsResult({
    required this.ascending,
    required this.descending,
    required this.perihelion,
    required this.aphelion,
  });
}

class OrbitalElementsResult {
  final double semimajorAxis;
  final double eccentricity;
  final double inclination;
  final double ascendingNode;
  final double argPeriapsis;
  final double lonPeriapsis;
  final double meanAnomalyEpoch;
  final double trueAnomalyEpoch;
  final double eccentricAnomalyEpoch;
  final double meanLongitudeEpoch;
  final double siderealPeriodYears;
  final double meanDailyMotion;
  final double tropicalPeriodYears;
  final double synodicPeriodDays;
  final double perihelionPassage;
  final double perihelionDistance;
  final double aphelionDistance;

  const OrbitalElementsResult({
    required this.semimajorAxis,
    required this.eccentricity,
    required this.inclination,
    required this.ascendingNode,
    required this.argPeriapsis,
    required this.lonPeriapsis,
    required this.meanAnomalyEpoch,
    required this.trueAnomalyEpoch,
    required this.eccentricAnomalyEpoch,
    required this.meanLongitudeEpoch,
    required this.siderealPeriodYears,
    required this.meanDailyMotion,
    required this.tropicalPeriodYears,
    required this.synodicPeriodDays,
    required this.perihelionPassage,
    required this.perihelionDistance,
    required this.aphelionDistance,
  });
}

class OrbitDistanceResult {
  final double maxDist;
  final double minDist;
  final double trueDist;

  const OrbitDistanceResult({
    required this.maxDist,
    required this.minDist,
    required this.trueDist,
  });
}

class PhenoResult {
  final double phaseAngle;
  final double phase;
  final double elongation;
  final double apparentDiameter;
  final double apparentMagnitude;

  const PhenoResult({
    required this.phaseAngle,
    required this.phase,
    required this.elongation,
    required this.apparentDiameter,
    required this.apparentMagnitude,
  });
}

class HeliacalResult {
  final double startVisible;
  final double bestVisible;
  final double endVisible;

  const HeliacalResult({
    required this.startVisible,
    required this.bestVisible,
    required this.endVisible,
  });
}

class AtmoConditions {
  final double pressure;
  final double temperature;
  final double humidity;
  final double extinction;

  const AtmoConditions({
    required this.pressure,
    required this.temperature,
    required this.humidity,
    required this.extinction,
  });
}

class ObserverConditions {
  final double age;
  final double snellenRatio;
  final double monoNoBino;
  final double telescopeDia;
  final double telescopeMag;
  final double eyeHeight;

  const ObserverConditions({
    this.age = 36,
    this.snellenRatio = 1.0,
    this.monoNoBino = 1,
    this.telescopeDia = 0,
    this.telescopeMag = 0,
    this.eyeHeight = 0,
  });
}

class SplitDegResult {
  final int degrees;
  final int minutes;
  final int seconds;
  final double secondsFraction;
  final int sign;

  const SplitDegResult({
    required this.degrees,
    required this.minutes,
    required this.seconds,
    required this.secondsFraction,
    required this.sign,
  });
}
