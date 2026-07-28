// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'flags.dart';
import 'julian_day.dart';

/// Counterpart: swisseph::CalcResult
final class CalcResult {
  /// Longitude or right ascension (depends on flags).
  final double longitude;

  /// Latitude or declination.
  final double latitude;

  /// Distance (AU or km depends on body).
  final double distance;

  /// Speed in longitude (degrees/day).
  final double longitudeSpeed;

  /// Speed in latitude.
  final double latitudeSpeed;

  /// Speed in distance.
  final double distanceSpeed;

  /// Counterpart: swisseph::CalcResult::flags_used
  final CalcFlags flagsUsed;

  const CalcResult({
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.longitudeSpeed,
    required this.latitudeSpeed,
    required this.distanceSpeed,
    required this.flagsUsed,
  });
}

/// Counterpart: swisseph::types::UtcComponents
final class UtcComponents {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final double second;

  const UtcComponents({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.second,
  });
}

/// Counterpart: swisseph::types::UtcToJd
final class UtcToJd {
  final JdTt tt;
  final JdUt1 ut1;

  const UtcToJd({required this.tt, required this.ut1});
}

/// Counterpart: swisseph::types::DegreeParts
final class DegreeParts {
  final int degrees;
  final int minutes;
  final int seconds;
  final double secondFraction;
  final int sign;

  const DegreeParts({
    required this.degrees,
    required this.minutes,
    required this.seconds,
    required this.secondFraction,
    required this.sign,
  });
}

/// Counterpart: swisseph::houses::AscMc
final class AscMc {
  final double ascendant;
  final double mc;
  final double armc;
  final double vertex;
  final double equatorialAscendant;
  final double coascendantKoch;
  final double coascendantMunkasey;
  final double polarAscendant;

  const AscMc({
    required this.ascendant,
    required this.mc,
    required this.armc,
    required this.vertex,
    required this.equatorialAscendant,
    required this.coascendantKoch,
    required this.coascendantMunkasey,
    required this.polarAscendant,
  });
}

/// Counterpart: swisseph::houses::HouseResult
final class HouseResult {
  /// Cusp longitudes. Index 0 is unused; cusps are at indices 1..12
  /// (or 1..36 for Gauquelin sectors).
  final List<double> cusps;

  /// Cusp speeds in degrees/day, same indexing as [cusps].
  final List<double> cuspSpeeds;

  /// Angular points (Ascendant, MC, ARMC, Vertex, etc.).
  final AscMc ascmc;

  /// Angular-point speeds in degrees/day.
  final AscMc ascmcSpeeds;

  const HouseResult({
    required this.cusps,
    required this.cuspSpeeds,
    required this.ascmc,
    required this.ascmcSpeeds,
  });
}

// ---------------------------------------------------------------------------
// Eclipse & occultation result types
// ---------------------------------------------------------------------------

/// Counterpart: swisseph::eclipse::EclipseHow
final class EclipseHow {
  final double magnitude;
  final double diameterRatio;
  final double obscuration;
  final double coreDiameterKm;
  final double azimuth;
  final double trueAltitude;
  final double apparentAltitude;
  final double elongation;
  final double nasaMagnitude;
  final double sarosSeries;
  final double sarosMember;
  final EclipseFlags flags;

  const EclipseHow({
    required this.magnitude,
    required this.diameterRatio,
    required this.obscuration,
    required this.coreDiameterKm,
    required this.azimuth,
    required this.trueAltitude,
    required this.apparentAltitude,
    required this.elongation,
    required this.nasaMagnitude,
    required this.sarosSeries,
    required this.sarosMember,
    required this.flags,
  });
}

/// Counterpart: swisseph::eclipse::EclipseWhere
final class EclipseWhere {
  final double centralLongitude;
  final double centralLatitude;
  final double coreDiameterKm;
  final double penumbraDiameterKm;
  final double shadowAxisDistanceKm;
  final double umbraDiameterFundamentalKm;
  final double penumbraDiameterFundamentalKm;
  final double cosUmbraHalfAngle;
  final double cosPenumbraHalfAngle;
  final EclipseFlags flags;

  const EclipseWhere({
    required this.centralLongitude,
    required this.centralLatitude,
    required this.coreDiameterKm,
    required this.penumbraDiameterKm,
    required this.shadowAxisDistanceKm,
    required this.umbraDiameterFundamentalKm,
    required this.penumbraDiameterFundamentalKm,
    required this.cosUmbraHalfAngle,
    required this.cosPenumbraHalfAngle,
    required this.flags,
  });
}

/// Counterpart: swisseph::eclipse::SolarEclipseGlobal
final class SolarEclipseGlobal {
  final double timeMaximum;
  final double timeRaConjunction;
  final double timeBegin;
  final double timeEnd;
  final double timeTotalityBegin;
  final double timeTotalityEnd;
  final double timeCenterlineBegin;
  final double timeCenterlineEnd;
  final EclipseFlags flags;

  const SolarEclipseGlobal({
    required this.timeMaximum,
    required this.timeRaConjunction,
    required this.timeBegin,
    required this.timeEnd,
    required this.timeTotalityBegin,
    required this.timeTotalityEnd,
    required this.timeCenterlineBegin,
    required this.timeCenterlineEnd,
    required this.flags,
  });
}

/// Counterpart: swisseph::eclipse::SolarEclipseLocal
final class SolarEclipseLocal {
  final double timeMaximum;
  final double timeFirstContact;
  final double timeSecondContact;
  final double timeThirdContact;
  final double timeFourthContact;
  final double timeSunrise;
  final double timeSunset;
  final EclipseHow attr;
  final EclipseFlags flags;

  const SolarEclipseLocal({
    required this.timeMaximum,
    required this.timeFirstContact,
    required this.timeSecondContact,
    required this.timeThirdContact,
    required this.timeFourthContact,
    required this.timeSunrise,
    required this.timeSunset,
    required this.attr,
    required this.flags,
  });
}

/// Counterpart: swisseph::eclipse::LunarEclipseHow
final class LunarEclipseHow {
  final double umbralMagnitude;
  final double penumbralMagnitude;
  final double azimuth;
  final double trueAltitude;
  final double apparentAltitude;
  final double distanceFromOpposition;
  final double sarosSeries;
  final double sarosMember;
  final EclipseFlags flags;

  const LunarEclipseHow({
    required this.umbralMagnitude,
    required this.penumbralMagnitude,
    required this.azimuth,
    required this.trueAltitude,
    required this.apparentAltitude,
    required this.distanceFromOpposition,
    required this.sarosSeries,
    required this.sarosMember,
    required this.flags,
  });
}

/// Counterpart: swisseph::eclipse::LunarEclipseGlobal
final class LunarEclipseGlobal {
  final double timeMaximum;
  final double timePartialBegin;
  final double timePartialEnd;
  final double timeTotalityBegin;
  final double timeTotalityEnd;
  final double timePenumbralBegin;
  final double timePenumbralEnd;
  final EclipseFlags flags;

  const LunarEclipseGlobal({
    required this.timeMaximum,
    required this.timePartialBegin,
    required this.timePartialEnd,
    required this.timeTotalityBegin,
    required this.timeTotalityEnd,
    required this.timePenumbralBegin,
    required this.timePenumbralEnd,
    required this.flags,
  });
}

/// Counterpart: swisseph::eclipse::LunarEclipseLocal
final class LunarEclipseLocal {
  final double timeMaximum;
  final double timePartialBegin;
  final double timePartialEnd;
  final double timeTotalityBegin;
  final double timeTotalityEnd;
  final double timePenumbralBegin;
  final double timePenumbralEnd;
  final double timeMoonrise;
  final double timeMoonset;
  final LunarEclipseHow attr;
  final EclipseFlags flags;

  const LunarEclipseLocal({
    required this.timeMaximum,
    required this.timePartialBegin,
    required this.timePartialEnd,
    required this.timeTotalityBegin,
    required this.timeTotalityEnd,
    required this.timePenumbralBegin,
    required this.timePenumbralEnd,
    required this.timeMoonrise,
    required this.timeMoonset,
    required this.attr,
    required this.flags,
  });
}

/// Counterpart: swisseph::eclipse::OccultGlobal
final class OccultGlobal {
  final double timeMaximum;
  final double timeRaConjunction;
  final double timeBegin;
  final double timeEnd;
  final double timeTotalityBegin;
  final double timeTotalityEnd;
  final double timeCenterlineBegin;
  final double timeCenterlineEnd;
  final EclipseFlags flags;

  const OccultGlobal({
    required this.timeMaximum,
    required this.timeRaConjunction,
    required this.timeBegin,
    required this.timeEnd,
    required this.timeTotalityBegin,
    required this.timeTotalityEnd,
    required this.timeCenterlineBegin,
    required this.timeCenterlineEnd,
    required this.flags,
  });
}

/// Counterpart: swisseph::eclipse::OccultLocal
final class OccultLocal {
  final double timeMaximum;
  final double timeFirstContact;
  final double timeSecondContact;
  final double timeThirdContact;
  final double timeFourthContact;
  final double timeRise;
  final double timeSet;
  final EclipseHow attr;
  final EclipseFlags flags;

  const OccultLocal({
    required this.timeMaximum,
    required this.timeFirstContact,
    required this.timeSecondContact,
    required this.timeThirdContact,
    required this.timeFourthContact,
    required this.timeRise,
    required this.timeSet,
    required this.attr,
    required this.flags,
  });
}

// ---------------------------------------------------------------------------
// Crossing result types (task /32)
// ---------------------------------------------------------------------------

/// Counterpart: swisseph::crossings::MoonCrossing
final class MoonCrossing {
  final double jd;
  final double longitude;
  final double latitude;

  const MoonCrossing({
    required this.jd,
    required this.longitude,
    required this.latitude,
  });
}

/// Counterpart: swisseph::riseset::RiseSetResult
final class RiseSetResult {
  final double time;

  const RiseSetResult({required this.time});
}

// ---------------------------------------------------------------------------
// Phenomena & orbital result types (task /33)
// ---------------------------------------------------------------------------

/// Counterpart: swisseph::phenomena::Phenomena
final class Phenomena {
  final double phaseAngle;
  final double phase;
  final double elongation;
  final double apparentDiameter;
  final double apparentMagnitude;
  final double horizontalParallax;
  final CalcFlags flagsUsed;

  const Phenomena({
    required this.phaseAngle,
    required this.phase,
    required this.elongation,
    required this.apparentDiameter,
    required this.apparentMagnitude,
    required this.horizontalParallax,
    required this.flagsUsed,
  });
}

/// Counterpart: swisseph::nodaps::NodesApsides
final class NodesApsides {
  final List<double> ascending;
  final List<double> descending;
  final List<double> perihelion;
  final List<double> aphelion;

  const NodesApsides({
    required this.ascending,
    required this.descending,
    required this.perihelion,
    required this.aphelion,
  });
}

/// Counterpart: swisseph::orbit::OrbitalElements
final class OrbitalElements {
  final double semiMajorAxis;
  final double eccentricity;
  final double inclination;
  final double ascendingNode;
  final double argPerihelion;
  final double perihelionLon;
  final double meanAnomaly;
  final double trueAnomaly;
  final double eccentricAnomaly;
  final double meanLongitude;
  final double siderealPeriod;
  final double meanDailyMotion;
  final double tropicalPeriod;
  final double synodicPeriod;
  final double perihelionPassage;
  final double perihelionDistance;
  final double aphelionDistance;

  const OrbitalElements({
    required this.semiMajorAxis,
    required this.eccentricity,
    required this.inclination,
    required this.ascendingNode,
    required this.argPerihelion,
    required this.perihelionLon,
    required this.meanAnomaly,
    required this.trueAnomaly,
    required this.eccentricAnomaly,
    required this.meanLongitude,
    required this.siderealPeriod,
    required this.meanDailyMotion,
    required this.tropicalPeriod,
    required this.synodicPeriod,
    required this.perihelionPassage,
    required this.perihelionDistance,
    required this.aphelionDistance,
  });
}

/// Counterpart: swisseph::orbit::Ephemeris::orbit_max_min_true_distance
final class OrbitDistances {
  final double max;
  final double min;
  final double trueDist;

  const OrbitDistances({
    required this.max,
    required this.min,
    required this.trueDist,
  });
}

// ---------------------------------------------------------------------------
// Horizon & refraction result types (task /34)
// ---------------------------------------------------------------------------

/// Counterpart: swisseph::Ephemeris::azalt (return value)
final class AzaltResult {
  final double azimuth;
  final double trueAltitude;
  final double apparentAltitude;

  const AzaltResult({
    required this.azimuth,
    required this.trueAltitude,
    required this.apparentAltitude,
  });
}

/// Counterpart: swisseph::azalt::refrac_extended (dret out-param)
final class RefracExtendedResult {
  final double returnValue;
  final double trueAltitude;
  final double apparentAltitude;
  final double refraction;
  final double horizonDip;

  const RefracExtendedResult({
    required this.returnValue,
    required this.trueAltitude,
    required this.apparentAltitude,
    required this.refraction,
    required this.horizonDip,
  });
}

// ---------------------------------------------------------------------------
// Fixed star result types (task /33)
// ---------------------------------------------------------------------------

/// Counterpart: swisseph::Ephemeris::fixstar2 (result)
final class FixstarResult {
  final String starName;
  final double longitude;
  final double latitude;
  final double distance;
  final double longitudeSpeed;
  final double latitudeSpeed;
  final double distanceSpeed;
  final CalcFlags flagsUsed;

  const FixstarResult({
    required this.starName,
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.longitudeSpeed,
    required this.latitudeSpeed,
    required this.distanceSpeed,
    required this.flagsUsed,
  });
}

/// Counterpart: swisseph::Ephemeris::fixstar2_mag (result)
final class FixstarMagResult {
  final String starName;
  final double magnitude;

  const FixstarMagResult({required this.starName, required this.magnitude});
}

// ---------------------------------------------------------------------------
// Heliacal result types (task /33)
// ---------------------------------------------------------------------------

/// Counterpart: swisseph::heliacal::VisLimitResult
final class VisLimitMagResult {
  final double limitingMagnitude;
  final double altitudeObject;
  final double azimuthObject;
  final double altitudeSun;
  final double azimuthSun;
  final double altitudeMoon;
  final double azimuthMoon;
  final double magnitudeObject;
  final VisLimFlags vision;
  final bool belowHorizon;

  const VisLimitMagResult({
    required this.limitingMagnitude,
    required this.altitudeObject,
    required this.azimuthObject,
    required this.altitudeSun,
    required this.azimuthSun,
    required this.altitudeMoon,
    required this.azimuthMoon,
    required this.magnitudeObject,
    required this.vision,
    required this.belowHorizon,
  });
}

/// Counterpart: swisseph::heliacal::HeliacalAngleResult
final class HeliacalAngleResult {
  final double optimalAltitude;
  final double arcusVisionis;
  final double sunAltitudeDiff;

  const HeliacalAngleResult({
    required this.optimalAltitude,
    required this.arcusVisionis,
    required this.sunAltitudeDiff,
  });
}

/// Counterpart: swisseph::heliacal::HeliacalPheno
final class HeliacalPheno {
  final double tcAltitude;
  final double tcApparentAltitude;
  final double gcAltitude;
  final double azimuthObject;
  final double tcSunAltitude;
  final double sunAzimuth;
  final double tavAct;
  final double arcvAct;
  final double dazAct;
  final double arclAct;
  final double kact;
  final double minTav;
  final double tFirstVr;
  final double tBestVr;
  final double tLastVr;
  final double tBestYallop;
  final double wMoon;
  final double qYallop;
  final double qCrit;
  final double parO;
  final double magnO;
  final double riseO;
  final double riseS;
  final double lag;
  final double tVisVr;
  final double lMoon;
  final double elongation;
  final double illumination;

  const HeliacalPheno({
    required this.tcAltitude,
    required this.tcApparentAltitude,
    required this.gcAltitude,
    required this.azimuthObject,
    required this.tcSunAltitude,
    required this.sunAzimuth,
    required this.tavAct,
    required this.arcvAct,
    required this.dazAct,
    required this.arclAct,
    required this.kact,
    required this.minTav,
    required this.tFirstVr,
    required this.tBestVr,
    required this.tLastVr,
    required this.tBestYallop,
    required this.wMoon,
    required this.qYallop,
    required this.qCrit,
    required this.parO,
    required this.magnO,
    required this.riseO,
    required this.riseS,
    required this.lag,
    required this.tVisVr,
    required this.lMoon,
    required this.elongation,
    required this.illumination,
  });
}

/// Counterpart: swisseph::heliacal::HeliacalEvent
final class HeliacalEvent {
  final double startVisible;
  final double optimumVisibility;
  final double endVisible;

  const HeliacalEvent({
    required this.startVisible,
    required this.optimumVisibility,
    required this.endVisible,
  });
}
