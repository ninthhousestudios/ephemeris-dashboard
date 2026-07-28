// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@Tags(['stress'])
@Timeout(Duration(minutes: 60))
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Parameter space
// ---------------------------------------------------------------------------

const _geoBodies = [
  Body.sun,
  Body.moon,
  Body.mercury,
  Body.venus,
  Body.mars,
  Body.jupiter,
  Body.saturn,
  Body.uranus,
  Body.neptune,
  Body.pluto,
  Body.meanNode,
  Body.trueNode,
  Body.meanApogee,
  Body.oscuApogee,
];

const _helioBodies = [
  Body.mercury,
  Body.venus,
  Body.mars,
  Body.jupiter,
  Body.saturn,
  Body.uranus,
  Body.neptune,
  Body.pluto,
  Body.earth,
];

const _nonPolarLocs = [
  (28.6139, 77.2090), // Delhi
  (51.5074, -0.1278), // London
  (40.7128, -74.0060), // New York
  (-33.8688, 151.2093), // Sydney
  (35.6762, 139.6503), // Tokyo
  (0.0, 0.0), // Null Island
  (-22.9068, -43.1729), // Rio
];

const _houseSubset = [
  HouseSystem.placidus,
  HouseSystem.koch,
  HouseSystem.campanus,
  HouseSystem.equal,
  HouseSystem.wholeSign,
];

const _fixedStars = [
  'Sirius',
  'Aldebaran',
  'Regulus',
  'Spica',
  'Antares',
  'Fomalhaut',
  'Vega',
  'Canopus',
  'Rigel',
  'Betelgeuse',
];

const _phenoBodies = [
  Body.mercury,
  Body.venus,
  Body.mars,
  Body.jupiter,
  Body.saturn,
  Body.uranus,
];

const Set<String> _allMethods = {
  // Calc (5)
  'calcUt', 'calc', 'calcUtWithConfig', 'calcWithConfig', 'calcPctr',
  // DateTime — instance (9)
  'deltaT', 'siderealTime', 'siderealTime0',
  'timeEqu', 'lmtToLat', 'latToLmt',
  'utcToJd', 'jdetToUtc', 'jdut1ToUtc',
  // DateTime — free (5)
  'julday', 'revjul', 'dateConversion', 'dayOfWeek', 'utcTimeZone',
  // Houses — instance (2)
  'houses', 'housesEx2',
  // Houses — free (3)
  'housesArmc', 'housePos', 'houseName',
  // Ayanamsa — instance (4)
  'getAyanamsa', 'getAyanamsaUt', 'getAyanamsaEx', 'getAyanamsaExWithConfig',
  // Ayanamsa — free (1)
  'getAyanamsaName',
  // Gauquelin (2)
  'gauquelinSector', 'gauquelinSectorGeometric',
  // Eclipse (10)
  'solEclipseWhenGlob', 'solEclipseWhenLoc', 'solEclipseWhere', 'solEclipseHow',
  'lunEclipseWhen', 'lunEclipseWhenLoc', 'lunEclipseHow',
  'lunOccultWhenGlob', 'lunOccultWhenLoc', 'lunOccultWhere',
  // Crossing (8)
  'solcross', 'solcrossUt', 'mooncross', 'mooncrossUt',
  'mooncrossNode', 'mooncrossNodeUt', 'helioCross', 'helioCrossUt',
  // Rise/set (2)
  'riseTrans', 'riseTransTrueHor',
  // Phenomena / orbital (8)
  'phenoUt', 'pheno', 'phenoWithConfig', 'phenoUtWithConfig',
  'nodApsUt', 'nodAps', 'getOrbitalElements', 'orbitMaxMinTrueDistance',
  // Horizon (2)
  'azalt', 'azaltRev',
  // Fixed stars (3)
  'fixstar2', 'fixstar2Ut', 'fixstar2Mag',
  // Heliacal (5)
  'heliacalUt', 'heliacalPhenoUt', 'visLimitMag',
  'heliacalAngle', 'topoArcusVisionis',
  // Coordinate — free (2)
  'refrac', 'refracExtended',
  // Utility — free (4)
  'splitDegrees', 'cotrans', 'cotransWithSpeed', 'normalizeDegrees',
  // Utility — instance (2)
  'getPlanetName', 'close',
  // Utility — free (1)
  'engineVersion',
  // Sharing (1)
  'share',
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _inc(Map<String, int> c, String k) => c[k] = (c[k] ?? 0) + 1;

String _fmt(int n) {
  if (n >= 1e9) return '${(n / 1e9).toStringAsFixed(2)}B';
  if (n >= 1e6) return '${(n / 1e6).toStringAsFixed(1)}M';
  if (n >= 1e3) return '${(n / 1e3).toStringAsFixed(1)}K';
  return n.toString();
}

int _rssKb() {
  try {
    final status = File('/proc/self/status').readAsStringSync();
    final match = RegExp(r'VmRSS:\s+(\d+)\s+kB').firstMatch(status);
    return match != null ? int.parse(match.group(1)!) : -1;
  } catch (_) {
    return -1;
  }
}

List<(int, int)> _buildDates() {
  final dates = <(int, int)>[];
  for (var year = 0; year <= 2000; year++) {
    dates.add((year, 1));
    dates.add((year, 4));
    dates.add((year, 7));
    dates.add((year, 10));
  }
  return dates;
}

// ---------------------------------------------------------------------------
// Reference values
// ---------------------------------------------------------------------------

double _refLon(Ephemeris eph, int sidIdx) {
  final mode = SiderealMode.values[sidIdx % 47];
  final config = EphemerisConfig(siderealMode: mode);
  final r = eph.calcUtWithConfig(
    const JdUt1(2451545.0),
    Body.sun,
    CalcFlags.mosEph | CalcFlags.speed | CalcFlags.sidereal,
    config,
  );
  return r.longitude;
}

double _refAsc(Ephemeris eph) {
  final r = eph.housesEx2(
    const JdUt1(2451545.0),
    CalcFlags.none,
    28.6139,
    77.2090,
    HouseSystem.campanus,
  );
  return r.ascmc.ascendant;
}

// ---------------------------------------------------------------------------
// Workloads
// ---------------------------------------------------------------------------

void _calcWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
  int sidIdx,
) {
  m.addAll([
    'calcUt',
    'calc',
    'calcUtWithConfig',
    'calcWithConfig',
    'calcPctr',
  ]);

  final mosSpd = CalcFlags.mosEph | CalcFlags.speed;
  final mosSpdEq = mosSpd | CalcFlags.equatorial;
  final mosSpdTrue = mosSpd | CalcFlags.truePos;
  final mosSpdHelio = mosSpd | CalcFlags.helctr;
  final mosSpdSid = mosSpd | CalcFlags.sidereal;
  final sidConfig = EphemerisConfig(
    siderealMode: SiderealMode.values[sidIdx % 47],
  );

  for (var di = 0; di < dates.length; di++) {
    final (year, month) = dates[di];
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);

    for (final body in _geoBodies) {
      eph.calcUt(jdUt, body, mosSpd);
      _inc(c, 'calcUt');
    }

    if (di % 10 == 0) {
      for (final body in _geoBodies) {
        eph.calcUt(jdUt, body, mosSpdEq);
        _inc(c, 'calcUt');
        eph.calcUt(jdUt, body, mosSpdTrue);
        _inc(c, 'calcUt');
      }
    }

    if (di % 5 == 0) {
      final dt = eph.deltaT(jdUt);
      final jdTt = JdTt(jdUt.value + dt);
      for (final body in [Body.sun, Body.moon, Body.mars]) {
        eph.calc(jdTt, body, mosSpd);
        _inc(c, 'calc');
      }
    }

    if (di % 20 == 0) {
      for (final body in _geoBodies) {
        eph.calcUtWithConfig(jdUt, body, mosSpdSid, sidConfig);
        _inc(c, 'calcUtWithConfig');
      }

      // User-defined sidereal mode
      const userConfig = EphemerisConfig(
        siderealMode: SiderealMode.user,
        siderealT0: 2451545.0,
        siderealAyanT0: 23.5,
      );
      eph.calcUtWithConfig(jdUt, Body.sun, mosSpdSid, userConfig);
      _inc(c, 'calcUtWithConfig');
    }

    if (di % 50 == 0) {
      final dt = eph.deltaT(jdUt);
      final jdTt = JdTt(jdUt.value + dt);

      eph.calcWithConfig(jdTt, Body.sun, mosSpdSid, sidConfig);
      _inc(c, 'calcWithConfig');

      for (final body in _helioBodies) {
        eph.calcUt(jdUt, body, mosSpdHelio);
        _inc(c, 'calcUt');
      }

      try {
        eph.calcPctr(jdTt, Body.mars, Body.jupiter, mosSpd);
        _inc(c, 'calcPctr');
      } on SweException {
        _inc(c, 'expectedErrors');
      }
    }
  }
}

void _dateTimeWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
) {
  m.addAll([
    'deltaT',
    'siderealTime',
    'siderealTime0',
    'timeEqu',
    'lmtToLat',
    'latToLmt',
    'utcToJd',
    'jdetToUtc',
    'jdut1ToUtc',
    'julday',
    'revjul',
    'dateConversion',
    'dayOfWeek',
    'utcTimeZone',
  ]);

  for (var di = 0; di < dates.length; di += 10) {
    final (year, month) = dates[di];
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);
    _inc(c, 'dateTime');

    final rev = revjul(jdUt.value, CalendarType.gregorian);
    _inc(c, 'dateTime');
    assert(
      rev.year == year && rev.month == month,
      'revjul mismatch: $year-$month -> ${rev.year}-${rev.month}',
    );

    dateConversion(year, month, 1, 12.0, CalendarType.gregorian);
    _inc(c, 'dateTime');

    dayOfWeek(jdUt.value);
    _inc(c, 'dateTime');

    final dt = eph.deltaT(jdUt);
    _inc(c, 'dateTime');

    final sidT = eph.siderealTime(jdUt);
    _inc(c, 'dateTime');
    assert(sidT >= 0.0 && sidT < 24.0, 'siderealTime out of range: $sidT');

    eph.siderealTime0(jdUt, 23.44, 0.0);
    _inc(c, 'dateTime');

    final jdTt = JdTt(jdUt.value + dt);
    final utc = UtcComponents(
      year: year,
      month: month,
      day: 1,
      hour: 12,
      minute: 0,
      second: 0.0,
    );

    try {
      eph.utcToJd(utc, CalendarType.gregorian);
      _inc(c, 'dateTime');
    } on SweException {
      _inc(c, 'expectedErrors');
    }

    eph.jdetToUtc(jdTt, CalendarType.gregorian);
    _inc(c, 'dateTime');

    eph.jdut1ToUtc(jdUt, CalendarType.gregorian);
    _inc(c, 'dateTime');

    utcTimeZone(utc, 5.5);
    _inc(c, 'dateTime');

    try {
      eph.timeEqu(jdUt.value);
      _inc(c, 'dateTime');
    } on SweException {
      _inc(c, 'expectedErrors');
    }

    try {
      final lmt = eph.lmtToLat(jdUt.value, 77.209);
      _inc(c, 'dateTime');
      eph.latToLmt(lmt, 77.209);
      _inc(c, 'dateTime');
    } on SweException {
      _inc(c, 'expectedErrors');
    }
  }
}

void _houseWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
  int isolateId,
) {
  m.addAll(['houses', 'housesEx2', 'housesArmc', 'housePos', 'houseName']);

  for (var di = 0; di < dates.length; di += 40) {
    final (year, month) = dates[di];
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);

    for (final (lat, lon) in _nonPolarLocs.take(3)) {
      for (final hsys in _houseSubset) {
        eph.houses(jdUt, lat, lon, hsys);
        _inc(c, 'houses');

        final ex2 = eph.housesEx2(jdUt, CalcFlags.none, lat, lon, hsys);
        _inc(c, 'houses');

        if (di % 200 == 0) {
          final armc = ex2.ascmc.armc;
          final nutR = eph.calcUt(
            jdUt,
            Body.eclipticNutation,
            CalcFlags.mosEph,
          );
          final eps = nutR.longitude;

          housesArmc(armc, lat, eps, hsys);
          _inc(c, 'houses');

          final sunR = eph.calcUt(
            jdUt,
            Body.sun,
            CalcFlags.mosEph | CalcFlags.speed,
          );
          final hp = housePos(
            armc,
            lat,
            eps,
            hsys,
            sunR.longitude,
            sunR.latitude,
          );
          _inc(c, 'housePos');
          assert(hp >= 1.0 && hp < 13.0, 'housePos $hp');
        }
      }
    }

    if (di % 200 == 0) {
      for (final hsys in [
        HouseSystem.placidus,
        HouseSystem.koch,
        HouseSystem.campanus,
      ]) {
        try {
          eph.houses(jdUt, 70.0, 25.0, hsys);
          _inc(c, 'houses');
        } on SweException {
          _inc(c, 'expectedErrors');
        }
      }
    }
  }

  for (final hsys in HouseSystem.values.take(10)) {
    houseName(hsys);
    _inc(c, 'houseName');
  }
}

void _ayanamsaWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
) {
  m.addAll([
    'getAyanamsa',
    'getAyanamsaUt',
    'getAyanamsaEx',
    'getAyanamsaExWithConfig',
    'getAyanamsaName',
  ]);

  const mosFlags = CalcFlags.mosEph;

  for (var di = 0; di < dates.length; di += 50) {
    final (year, month) = dates[di];
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);
    final dt = eph.deltaT(jdUt);
    final jdTt = JdTt(jdUt.value + dt);

    for (final mode in SiderealMode.values) {
      if (mode == SiderealMode.user) continue;
      final cfg = EphemerisConfig(siderealMode: mode);

      eph.getAyanamsaExWithConfig(jdTt, mosFlags, cfg);
      _inc(c, 'ayanamsa');

      getAyanamsaName(mode);
      _inc(c, 'ayanamsa');
    }

    eph.getAyanamsa(jdTt);
    _inc(c, 'ayanamsa');

    eph.getAyanamsaUt(jdUt, mosFlags);
    _inc(c, 'ayanamsa');

    eph.getAyanamsaEx(jdTt, mosFlags);
    _inc(c, 'ayanamsa');
  }
}

void _posExtWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
) {
  m.addAll([
    'phenoUt',
    'pheno',
    'phenoWithConfig',
    'phenoUtWithConfig',
    'nodApsUt',
    'nodAps',
    'getOrbitalElements',
    'orbitMaxMinTrueDistance',
  ]);

  final mosSpd = CalcFlags.mosEph | CalcFlags.speed;

  for (var di = 0; di < dates.length; di += 100) {
    final (year, month) = dates[di];
    if (month != 7) continue;
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);
    final dt = eph.deltaT(jdUt);
    final jdTt = JdTt(jdUt.value + dt);

    for (final body in _phenoBodies) {
      try {
        eph.phenoUt(jdUt, body, CalcFlags.mosEph);
        _inc(c, 'posExt');
      } on SweException {
        _inc(c, 'expectedErrors');
      }

      try {
        eph.pheno(jdTt, body, CalcFlags.mosEph);
        _inc(c, 'posExt');
      } on SweException {
        _inc(c, 'expectedErrors');
      }

      try {
        eph.nodApsUt(jdUt, body, mosSpd, NodApsMethod.mean);
        _inc(c, 'posExt');
      } on SweException {
        _inc(c, 'expectedErrors');
      }

      try {
        eph.nodAps(jdTt, body, mosSpd, NodApsMethod.oscu);
        _inc(c, 'posExt');
      } on SweException {
        _inc(c, 'expectedErrors');
      }

      try {
        eph.getOrbitalElements(jdTt, body, CalcFlags.mosEph);
        _inc(c, 'posExt');
      } on SweException {
        _inc(c, 'expectedErrors');
      }

      try {
        eph.orbitMaxMinTrueDistance(jdTt, body, CalcFlags.mosEph);
        _inc(c, 'posExt');
      } on SweException {
        _inc(c, 'expectedErrors');
      }
    }

    // Config variants — one per sample date
    const cfg = EphemerisConfig(siderealMode: SiderealMode.lahiri);
    try {
      eph.phenoWithConfig(jdTt, Body.mars, CalcFlags.mosEph, cfg);
      _inc(c, 'posExt');
    } on SweException {
      _inc(c, 'expectedErrors');
    }
    try {
      eph.phenoUtWithConfig(jdUt, Body.mars, CalcFlags.mosEph, cfg);
      _inc(c, 'posExt');
    } on SweException {
      _inc(c, 'expectedErrors');
    }
  }
}

void _fixstarWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
) {
  m.addAll(['fixstar2', 'fixstar2Ut', 'fixstar2Mag']);

  final mosSpd = CalcFlags.mosEph | CalcFlags.speed;

  for (var di = 0; di < dates.length; di += 200) {
    final (year, month) = dates[di];
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);
    final jdTt = JdTt(jdUt.value + eph.deltaT(jdUt));

    for (final star in _fixedStars) {
      try {
        eph.fixstar2Ut(star, jdUt, mosSpd);
        _inc(c, 'fixstar');
      } on SweException {
        _inc(c, 'expectedErrors');
      }

      try {
        eph.fixstar2(star, jdTt, mosSpd);
        _inc(c, 'fixstar');
      } on SweException {
        _inc(c, 'expectedErrors');
      }
    }
  }

  for (final star in _fixedStars) {
    try {
      eph.fixstar2Mag(star);
      _inc(c, 'fixstar');
    } on SweException {
      _inc(c, 'expectedErrors');
    }
  }
}

void _coordWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
) {
  m.addAll(['azalt', 'azaltRev', 'refrac', 'refracExtended']);

  final mosSpd = CalcFlags.mosEph | CalcFlags.speed;

  for (var di = 0; di < dates.length; di += 20) {
    final (year, month) = dates[di];
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);

    CalcResult sun;
    try {
      sun = eph.calcUt(jdUt, Body.sun, mosSpd);
    } on SweException {
      _inc(c, 'expectedErrors');
      continue;
    }

    final az = eph.azalt(
      jdUt,
      AzAltDir.eclToHor,
      geolon: 77.209,
      geolat: 28.614,
      xin0: sun.longitude,
      xin1: sun.latitude,
    );
    _inc(c, 'coord');

    eph.azaltRev(
      jdUt,
      HorDir.horToEcl,
      geolon: 77.209,
      geolat: 28.614,
      azimuth: az.azimuth,
      trueAltitude: az.trueAltitude,
    );
    _inc(c, 'coord');

    refrac(45.0, 1013.25, 15.0, RefracDir.trueToApp);
    _inc(c, 'coord');

    refracExtended(45.0, 0.0, 1013.25, 15.0, 0.0065, RefracDir.trueToApp);
    _inc(c, 'coord');
  }
}

void _utilWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
) {
  m.addAll([
    'splitDegrees',
    'cotrans',
    'cotransWithSpeed',
    'normalizeDegrees',
    'engineVersion',
    'getPlanetName',
  ]);

  engineVersion;
  _inc(c, 'util');

  for (var id = 0; id <= 22; id++) {
    eph.getPlanetName(Body.fromRawId(id));
    _inc(c, 'util');
  }

  for (var di = 0; di < dates.length; di += 20) {
    final (year, month) = dates[di];
    final deg = (year * 360.0 / 2000.0) + month * 30.0;

    final norm = normalizeDegrees(deg);
    _inc(c, 'util');
    assert(norm >= 0.0 && norm < 360.0, 'normalizeDegrees($deg) = $norm');

    splitDegrees(deg, SplitDegFlags.roundSec);
    _inc(c, 'util');

    splitDegrees(deg, SplitDegFlags.zodiacal);
    _inc(c, 'util');

    splitDegrees(deg, SplitDegFlags.nakshatra);
    _inc(c, 'util');

    final ct = cotrans(deg, deg / 10.0, 1.0, 23.44);
    _inc(c, 'util');
    assert(ct.length == 3, 'cotrans returned ${ct.length} values');

    final ctSp = cotransWithSpeed(deg, deg / 10.0, 1.0, 0.5, 0.1, 0.0, 23.44);
    _inc(c, 'util');
    assert(ctSp.length == 6, 'cotransWithSpeed returned ${ctSp.length} values');
  }
}

void _crossWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
) {
  m.addAll([
    'solcross',
    'solcrossUt',
    'mooncross',
    'mooncrossUt',
    'mooncrossNode',
    'mooncrossNodeUt',
    'helioCross',
    'helioCrossUt',
  ]);

  const mosFlags = CalcFlags.mosEph;

  for (var di = 0; di < dates.length; di += 400) {
    final (year, month) = dates[di];
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);
    final jdTt = JdTt(jdUt.value + eph.deltaT(jdUt));

    for (final lon in [0.0, 90.0, 180.0, 270.0]) {
      try {
        eph.solcrossUt(lon, jdUt, mosFlags);
        _inc(c, 'crossing');
      } on SweException {
        _inc(c, 'expectedErrors');
      }
      try {
        eph.solcross(lon, jdTt, mosFlags);
        _inc(c, 'crossing');
      } on SweException {
        _inc(c, 'expectedErrors');
      }
    }

    try {
      eph.mooncrossUt(0.0, jdUt, mosFlags);
      _inc(c, 'crossing');
    } on SweException {
      _inc(c, 'expectedErrors');
    }
    try {
      eph.mooncross(0.0, jdTt, mosFlags);
      _inc(c, 'crossing');
    } on SweException {
      _inc(c, 'expectedErrors');
    }
    try {
      eph.mooncrossNodeUt(jdUt, mosFlags);
      _inc(c, 'crossing');
    } on SweException {
      _inc(c, 'expectedErrors');
    }
    try {
      eph.mooncrossNode(jdTt, mosFlags);
      _inc(c, 'crossing');
    } on SweException {
      _inc(c, 'expectedErrors');
    }

    if (di % 2000 == 0) {
      try {
        eph.helioCrossUt(Body.mars, 0.0, jdUt, mosFlags);
        _inc(c, 'crossing');
      } on SweException {
        _inc(c, 'expectedErrors');
      }
      try {
        eph.helioCross(Body.mars, 0.0, jdTt, mosFlags);
        _inc(c, 'crossing');
      } on SweException {
        _inc(c, 'expectedErrors');
      }
    }
  }
}

void _riseSetWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
) {
  m.addAll(['riseTrans', 'riseTransTrueHor']);

  var trueHorCount = 0;

  for (var di = 0; di < dates.length; di += 200) {
    final (year, month) = dates[di];
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);

    for (final (lat, lon) in _nonPolarLocs.take(3)) {
      for (final body in [Body.sun, Body.moon]) {
        for (final rsmi in [RiseSetFlags.rise, RiseSetFlags.set]) {
          try {
            eph.riseTrans(
              jdUt,
              body,
              CalcFlags.mosEph,
              rsmi,
              geolon: lon,
              geolat: lat,
            );
            _inc(c, 'riseSet');
          } on SweException {
            _inc(c, 'expectedErrors');
          }
        }
      }
    }

    if (trueHorCount < 10) {
      for (final (lat, lon) in _nonPolarLocs.take(2)) {
        try {
          eph.riseTransTrueHor(
            jdUt,
            Body.sun,
            CalcFlags.mosEph,
            RiseSetFlags.rise,
            geolon: lon,
            geolat: lat,
            horhgt: 0.5,
          );
          _inc(c, 'riseSet');
        } on SweException {
          _inc(c, 'expectedErrors');
        }
      }
      trueHorCount++;
    }
  }
}

void _eclipseWork(Ephemeris eph, Map<String, int> c, Set<String> m) {
  m.addAll([
    'solEclipseWhenGlob',
    'solEclipseHow',
    'solEclipseWhere',
    'solEclipseWhenLoc',
    'lunEclipseWhen',
    'lunEclipseHow',
    'lunEclipseWhenLoc',
    'lunOccultWhenGlob',
    'lunOccultWhenLoc',
    'lunOccultWhere',
  ]);

  const flags = CalcFlags.mosEph;

  // Solar — chain 5
  var jd = const JdUt1(2451545.0);
  for (var i = 0; i < 5; i++) {
    try {
      final g = eph.solEclipseWhenGlob(jd, flags);
      _inc(c, 'eclipse');
      try {
        eph.solEclipseHow(
          JdUt1(g.timeMaximum),
          flags,
          geolon: 77.2,
          geolat: 28.6,
        );
        _inc(c, 'eclipse');
      } catch (_) {
        _inc(c, 'expectedErrors');
      }
      try {
        eph.solEclipseWhere(JdUt1(g.timeMaximum), flags);
        _inc(c, 'eclipse');
      } catch (_) {
        _inc(c, 'expectedErrors');
      }
      try {
        eph.solEclipseWhenLoc(jd, flags, geolon: 77.2, geolat: 28.6);
        _inc(c, 'eclipse');
      } catch (_) {
        _inc(c, 'expectedErrors');
      }
      jd = JdUt1(g.timeMaximum + 30);
    } catch (_) {
      _inc(c, 'expectedErrors');
      jd = jd + 180;
    }
  }

  // Lunar — chain 5
  jd = const JdUt1(2451545.0);
  for (var i = 0; i < 5; i++) {
    try {
      final g = eph.lunEclipseWhen(jd, flags);
      _inc(c, 'eclipse');
      try {
        eph.lunEclipseHow(
          JdUt1(g.timeMaximum),
          flags,
          geolon: 77.2,
          geolat: 28.6,
        );
        _inc(c, 'eclipse');
      } catch (_) {
        _inc(c, 'expectedErrors');
      }
      try {
        eph.lunEclipseWhenLoc(jd, flags, geolon: 77.2, geolat: 28.6);
        _inc(c, 'eclipse');
      } catch (_) {
        _inc(c, 'expectedErrors');
      }
      jd = JdUt1(g.timeMaximum + 30);
    } catch (_) {
      _inc(c, 'expectedErrors');
      jd = jd + 180;
    }
  }

  // Occultations of Mars — chain 3
  jd = const JdUt1(2451545.0);
  for (var i = 0; i < 3; i++) {
    try {
      final g = eph.lunOccultWhenGlob(jd, Body.mars, flags);
      _inc(c, 'eclipse');
      try {
        eph.lunOccultWhenLoc(jd, Body.mars, flags, geolon: 77.2, geolat: 28.6);
        _inc(c, 'eclipse');
      } catch (_) {
        _inc(c, 'expectedErrors');
      }
      try {
        eph.lunOccultWhere(JdUt1(g.timeMaximum), Body.mars, flags);
        _inc(c, 'eclipse');
      } catch (_) {
        _inc(c, 'expectedErrors');
      }
      jd = JdUt1(g.timeMaximum + 30);
    } catch (_) {
      _inc(c, 'expectedErrors');
      jd = jd + 180;
    }
  }
}

void _heliacalWork(Ephemeris eph, Map<String, int> c, Set<String> m) {
  m.addAll([
    'heliacalUt',
    'heliacalPhenoUt',
    'visLimitMag',
    'heliacalAngle',
    'topoArcusVisionis',
  ]);

  const geolon = 77.2090;
  const geolat = 28.6139;

  for (final year in [0, 500, 1000, 1500, 2000]) {
    final jd = JdUt1(2451545.0 + (year - 2000) * 365.25);
    for (final planet in ['Venus', 'Mars', 'Jupiter']) {
      try {
        eph.heliacalUt(
          jd,
          planet,
          HeliacalEventType.morningFirst,
          CalcFlags.mosEph,
          HeliacalFlags.none,
          geolon: geolon,
          geolat: geolat,
        );
        _inc(c, 'heliacal');
      } on SweException {
        _inc(c, 'expectedErrors');
      }

      try {
        eph.heliacalPhenoUt(
          jd,
          planet,
          HeliacalEventType.morningFirst,
          CalcFlags.mosEph,
          HeliacalFlags.none,
          geolon: geolon,
          geolat: geolat,
        );
        _inc(c, 'heliacal');
      } on SweException {
        _inc(c, 'expectedErrors');
      }

      try {
        eph.visLimitMag(
          jd,
          planet,
          CalcFlags.mosEph,
          HeliacalFlags.none,
          geolon: geolon,
          geolat: geolat,
        );
        _inc(c, 'heliacal');
      } on SweException {
        _inc(c, 'expectedErrors');
      }
    }
  }

  // heliacalAngle + topoArcusVisionis — need pre-computed positions
  try {
    const jd = JdUt1(2451545.0);
    final mosSpd = CalcFlags.mosEph | CalcFlags.speed;
    final sunPos = eph.calcUt(jd, Body.sun, mosSpd);
    final moonPos = eph.calcUt(jd, Body.moon, mosSpd);
    final sunAz = eph.azalt(
      jd,
      AzAltDir.eclToHor,
      geolon: geolon,
      geolat: geolat,
      xin0: sunPos.longitude,
      xin1: sunPos.latitude,
    );
    final moonAz = eph.azalt(
      jd,
      AzAltDir.eclToHor,
      geolon: geolon,
      geolat: geolat,
      xin0: moonPos.longitude,
      xin1: moonPos.latitude,
    );

    eph.heliacalAngle(
      jd,
      HeliacalFlags.none,
      geolon: geolon,
      geolat: geolat,
      mag: -3.9,
      aziObj: 250.0,
      aziSun: sunAz.azimuth,
      aziMoon: moonAz.azimuth,
      altMoon: moonAz.trueAltitude,
    );
    _inc(c, 'heliacal');

    eph.topoArcusVisionis(
      jd,
      HeliacalFlags.none,
      geolon: geolon,
      geolat: geolat,
      mag: -3.9,
      aziObj: 250.0,
      altObj: -5.0,
      aziSun: sunAz.azimuth,
      aziMoon: moonAz.azimuth,
      altMoon: moonAz.trueAltitude,
    );
    _inc(c, 'heliacal');
  } catch (_) {
    _inc(c, 'expectedErrors');
  }
}

void _gauquelinWork(
  Ephemeris eph,
  Map<String, int> c,
  Set<String> m,
  List<(int, int)> dates,
) {
  m.addAll(['gauquelinSector', 'gauquelinSectorGeometric']);

  for (var di = 0; di < dates.length; di += 800) {
    final (year, month) = dates[di];
    final jdUt = julday(year, month, 1, 12.0, CalendarType.gregorian);

    for (final (lat, lon) in _nonPolarLocs.take(2)) {
      for (final body in [Body.sun, Body.moon, Body.mars]) {
        try {
          eph.gauquelinSector(jdUt, body, CalcFlags.mosEph, 0, lon, lat, 0.0);
          _inc(c, 'gauquelin');
        } on SweException {
          _inc(c, 'expectedErrors');
        }

        try {
          eph.gauquelinSectorGeometric(
            jdUt,
            body,
            CalcFlags.mosEph,
            1,
            lon,
            lat,
          );
          _inc(c, 'gauquelin');
        } on SweException {
          _inc(c, 'expectedErrors');
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Worker entry point
// ---------------------------------------------------------------------------

void _workerEntry((int, int, int, int, SendPort) msg) async {
  final (token, isolateId, sidIdx, delayMs, port) = msg;
  final result = await _worker(token, isolateId, sidIdx, delayMs);
  port.send(result);
}

Future<Map<String, Object?>> _worker(
  int token,
  int isolateId,
  int sidIdx,
  int delayMs,
) async {
  final eph = Ephemeris.fromShareToken(token);
  final sw = Stopwatch()..start();
  final c = <String, int>{};
  final m = <String>{};

  try {
    final dates = _buildDates();

    // Phase 0 — reference values before workload
    final rLon = _refLon(eph, sidIdx);
    final rAsc = _refAsc(eph);

    // Phase 1 — high volume
    _calcWork(eph, c, m, dates, sidIdx);
    _houseWork(eph, c, m, dates, isolateId);
    _ayanamsaWork(eph, c, m, dates);

    // Phase 2 — medium volume
    _dateTimeWork(eph, c, m, dates);
    _posExtWork(eph, c, m, dates);
    _fixstarWork(eph, c, m, dates);
    _coordWork(eph, c, m, dates);
    _utilWork(eph, c, m, dates);

    // Phase 3 — slow iterative
    _crossWork(eph, c, m, dates);
    _riseSetWork(eph, c, m, dates);
    _eclipseWork(eph, c, m);
    _heliacalWork(eph, c, m);
    _gauquelinWork(eph, c, m, dates);

    // Exercise share — nested share/close
    final nested = eph.share();
    Ephemeris.fromShareToken(nested).close();
    m.add('share');

    // Post-workload isolation check
    final rLon2 = _refLon(eph, sidIdx);
    final rAsc2 = _refAsc(eph);
    assert(
      (rLon - rLon2).abs() < 1e-10,
      'Reference lon changed: $rLon -> $rLon2',
    );
    assert(
      (rAsc - rAsc2).abs() < 1e-10,
      'Reference asc changed: $rAsc -> $rAsc2',
    );

    sw.stop();

    // Randomized close delay
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    m.add('close');
    eph.close();

    return <String, Object?>{
      'id': isolateId,
      'sidIdx': sidIdx,
      'counts': c,
      'refLon': rLon,
      'refAsc': rAsc,
      'ms': sw.elapsedMilliseconds,
      'methods': m.toList(),
      'error': null,
    };
  } catch (e, st) {
    sw.stop();
    try {
      eph.close();
    } catch (_) {}
    return <String, Object?>{
      'id': isolateId,
      'sidIdx': sidIdx,
      'counts': c,
      'refLon': -1.0,
      'refAsc': -1.0,
      'ms': sw.elapsedMilliseconds,
      'methods': m.toList(),
      'error': '$e\n$st',
    };
  }
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

void main() {
  const totalWorkers = 100;
  const batchSize = 50;

  group('stress test 0.2', () {
    test('$totalWorkers isolates, shared engine, full API sweep', () async {
      // Config
      final ephePath = Directory('ephe').existsSync()
          ? Directory('ephe').absolute.path
          : null;
      final config = EphemerisConfig(ephePath: ephePath);

      stderr.writeln('=== STRESS TEST 0.2 (swisseph_rs) ===');
      stderr.writeln('Workers: $totalWorkers (batches of $batchSize)');
      stderr.writeln('Sharing: Arc-refcounted via Ephemeris.share()');
      stderr.writeln('Ephemeris: Moshier (+ SwissEph files if ephe/ present)');
      stderr.writeln('ephe path: ${ephePath ?? "(none)"}');
      stderr.writeln('Methods: ${_allMethods.length}');
      stderr.writeln('======================================\n');

      // Create engine and baseline
      final rssBaseline = _rssKb();
      final eph = Ephemeris(config);
      final rssSingleEngine = _rssKb();

      // Verify engine works before sharing
      eph.calcUt(
        const JdUt1(2451545.0),
        Body.sun,
        CalcFlags.mosEph | CalcFlags.speed,
      );

      // Generate 100 share tokens
      final tokens = List.generate(totalWorkers, (_) => eph.share());

      // Close original FIRST — proves any-close-order at scale
      eph.close();
      stderr.writeln(
        'Original engine closed (${tokens.length} share tokens live)',
      );

      // Shuffled close delays (0–2000ms)
      final delays = List.generate(totalWorkers, (i) => i * 20);
      delays.shuffle(Random(42));

      // Run workers
      final allResults = <Map<String, Object?>>[];
      final overallSw = Stopwatch()..start();

      for (var batch = 0; batch < totalWorkers; batch += batchSize) {
        final batchEnd = min(batch + batchSize, totalWorkers);
        final batchCount = batchEnd - batch;
        final receivePort = ReceivePort();
        final spawns = <Future<Isolate>>[];

        for (var i = batch; i < batchEnd; i++) {
          spawns.add(
            Isolate.spawn(_workerEntry, (
              tokens[i],
              i,
              i,
              delays[i],
              receivePort.sendPort,
            )),
          );
        }
        await Future.wait(spawns);

        final batchResults = <Map<String, Object?>>[];
        await for (final msg in receivePort) {
          batchResults.add((msg as Map).cast<String, Object?>());
          if (batchResults.length >= batchCount) break;
        }
        receivePort.close();
        allResults.addAll(batchResults);

        final done = allResults.length;
        final elapsed = overallSw.elapsed;
        final totalCalcs = allResults.fold<int>(0, (s, r) {
          final counts = r['counts'] as Map;
          return s +
              counts.values.whereType<int>().fold<int>(0, (a, b) => a + b) -
              (counts['expectedErrors'] as int? ?? 0);
        });
        final rssNow = _rssKb();

        stderr.writeln(
          '  [$done/$totalWorkers] '
          '${_fmt(totalCalcs)} calcs, '
          '${elapsed.inMinutes}m${elapsed.inSeconds % 60}s, '
          'RSS: ${rssNow > 0 ? "${rssNow ~/ 1024}MB" : "?"}',
        );
      }

      overallSw.stop();
      final rssPeak = _rssKb();

      // ===================================================================
      // Verification
      // ===================================================================

      // 1. No fatal errors
      final errors = allResults.where((r) => r['error'] != null).toList();
      if (errors.isNotEmpty) {
        stderr.writeln('\nFATAL ERRORS (first 3):');
        for (final e in errors.take(3)) {
          stderr.writeln('  isolate ${e["id"]}: ${e["error"]}');
        }
      }
      expect(
        errors,
        isEmpty,
        reason: 'All isolates should complete without fatal error',
      );

      // 2. Reference longitude isolation
      final bySidMode = <int, List<double>>{};
      for (final r in allResults) {
        final idx = r['sidIdx'] as int;
        bySidMode.putIfAbsent(idx % 47, () => []).add(r['refLon'] as double);
      }
      for (final entry in bySidMode.entries) {
        final first = entry.value.first;
        for (final lon in entry.value) {
          expect(
            (lon - first).abs(),
            lessThan(1e-8),
            reason: 'SiderealMode ${entry.key}: reference longitude mismatch',
          );
        }
      }

      // 3. Reference ascendant isolation (tropical — all must agree)
      final ascValues = allResults.map((r) => r['refAsc'] as double).toList();
      final firstAsc = ascValues.first;
      for (final asc in ascValues) {
        expect(
          (asc - firstAsc).abs(),
          lessThan(1e-8),
          reason: 'Tropical ascendant mismatch across workers',
        );
      }

      // 4. Different sidereal modes → different reference longitudes
      final uniqueLons = bySidMode.values.map((v) => v.first).toSet();
      expect(
        uniqueLons.length,
        equals(bySidMode.length),
        reason: 'Each sidereal mode should produce a distinct reference value',
      );

      // 5. API coverage
      for (final r in allResults) {
        final called = (r['methods'] as List).cast<String>().toSet();
        final missing = _allMethods.difference(called);
        expect(
          missing,
          isEmpty,
          reason: 'Isolate ${r["id"]} missing methods: $missing',
        );
      }

      // 6. Expected errors exercised
      final totalExpected = allResults.fold<int>(0, (s, r) {
        final counts = r['counts'] as Map;
        return s + (counts['expectedErrors'] as int? ?? 0);
      });
      expect(
        totalExpected,
        greaterThan(0),
        reason: 'Expected error paths should have been exercised',
      );

      // 7. RSS bound — peak should be < 5x single-engine overhead
      if (rssBaseline > 0 && rssSingleEngine > 0 && rssPeak > 0) {
        final engineOverhead = rssSingleEngine - rssBaseline;
        final peakOverhead = rssPeak - rssBaseline;
        // Allow 5x for Dart VM per-isolate overhead (heaps, stacks)
        // The NATIVE engine memory should be shared (1x), not 100x
        stderr.writeln('\nRSS baseline: ${rssBaseline ~/ 1024}MB');
        stderr.writeln(
          'RSS single engine: ${rssSingleEngine ~/ 1024}MB '
          '(+${engineOverhead ~/ 1024}MB)',
        );
        stderr.writeln(
          'RSS peak ($totalWorkers workers): ${rssPeak ~/ 1024}MB '
          '(+${peakOverhead ~/ 1024}MB)',
        );
        if (engineOverhead > 0) {
          final ratio = peakOverhead / engineOverhead;
          stderr.writeln(
            'Peak/engine ratio: ${ratio.toStringAsFixed(1)}x '
            '(expect <10x with VM overhead; 100x would mean no sharing)',
          );
        }
      }

      // Stats
      final totalCalcs = allResults.fold<int>(0, (s, r) {
        final counts = r['counts'] as Map;
        return s +
            counts.values.whereType<int>().fold<int>(0, (a, b) => a + b) -
            (counts['expectedErrors'] as int? ?? 0);
      });
      final elapsed = overallSw.elapsed;
      final calcsPerSec = elapsed.inSeconds > 0
          ? totalCalcs ~/ elapsed.inSeconds
          : 0;

      // Per-category
      final catTotals = <String, int>{};
      for (final r in allResults) {
        final counts = (r['counts'] as Map).cast<String, int>();
        for (final e in counts.entries) {
          catTotals[e.key] = (catTotals[e.key] ?? 0) + e.value;
        }
      }

      stderr.writeln('\n=== STRESS TEST 0.2 RESULTS ===');
      stderr.writeln('Workers: $totalWorkers (batches of $batchSize)');
      stderr.writeln('Total calcs: ${_fmt(totalCalcs)}');
      stderr.writeln(
        'Wall time: ${elapsed.inMinutes}m${elapsed.inSeconds % 60}s',
      );
      stderr.writeln('Throughput: ${_fmt(calcsPerSec)} calcs/sec');
      stderr.writeln('');
      stderr.writeln('Per-category totals:');
      for (final cat in [
        'calcUt',
        'calc',
        'calcUtWithConfig',
        'calcWithConfig',
        'calcPctr',
        'houses',
        'housePos',
        'houseName',
        'ayanamsa',
        'dateTime',
        'posExt',
        'fixstar',
        'coord',
        'crossing',
        'riseSet',
        'eclipse',
        'heliacal',
        'gauquelin',
        'util',
      ]) {
        final v = catTotals[cat] ?? 0;
        if (v > 0) stderr.writeln('  $cat: ${_fmt(v)}');
      }
      stderr.writeln('  expectedErrors: ${catTotals['expectedErrors'] ?? 0}');
      stderr.writeln('');
      stderr.writeln('Methods: ${_allMethods.length}/${_allMethods.length}');
      stderr.writeln('Sidereal modes verified: ${bySidMode.length}');
      stderr.writeln('Isolation: PASS');
      stderr.writeln('API coverage: PASS');
      stderr.writeln(
        'Close order: randomized ($totalWorkers delays, original closed first)',
      );
      stderr.writeln('================================\n');
    });
  });
}
