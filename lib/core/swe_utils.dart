// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph/swisseph.dart' show DateResult, SplitDegResult;
import 'package:swisseph_rs/swisseph_rs.dart' as rs;

/// Dashboard-owned facade over the untraced SwissEph utility surface.
///
/// These are pure functions / metadata lookups that tabs currently call
/// directly on the SwissEph instance from sweProvider. The facade preserves
/// the same call names, backed by swisseph_rs. Tab call sites switch to this
/// at cutover (S4).
class SweUtils {
  SweUtils(this._engine);

  final rs.Ephemeris _engine;

  String getPlanetName(int body) {
    return _engine.getPlanetName(rs.Body.fromRawId(body));
  }

  DateResult revjul(double jd, {bool gregorian = true}) {
    final cal = gregorian ? rs.CalendarType.gregorian : rs.CalendarType.julian;
    final r = rs.revjul(jd, cal);
    return DateResult(year: r.year, month: r.month, day: r.day, hour: r.hour);
  }

  double julday(
    int year,
    int month,
    int day,
    double hour, {
    bool gregorian = true,
  }) {
    final cal = gregorian ? rs.CalendarType.gregorian : rs.CalendarType.julian;
    return rs.julday(year, month, day, hour, cal).value;
  }

  int dayOfWeek(double jd) {
    return rs.dayOfWeek(jd);
  }

  double degnorm(double x) {
    return rs.normalizeDegrees(x);
  }

  String houseName(int hsys) {
    final system = rs.HouseSystem.fromCharCode(hsys);
    if (system == null) return '';
    return rs.houseName(system);
  }

  double radNorm(double x) {
    var result = x % (2 * 3.14159265358979323846);
    if (result < 0) result += 2 * 3.14159265358979323846;
    return result;
  }

  double degMidp(double x1, double x0) {
    var d = degnorm(x1 - x0);
    if (d >= 180) d -= 360;
    return degnorm(x0 + d / 2);
  }

  double radMidp(double x1, double x0) {
    const twoPi = 2 * 3.14159265358979323846;
    var d = (x1 - x0) % twoPi;
    if (d < 0) d += twoPi;
    if (d >= 3.14159265358979323846) d -= twoPi;
    return radNorm(x0 + d / 2);
  }

  SplitDegResult splitDeg(double degrees, int roundFlag) {
    final r = rs.splitDegrees(degrees, rs.SplitDegFlags(roundFlag));
    return SplitDegResult(
      degrees: r.degrees,
      minutes: r.minutes,
      seconds: r.seconds,
      secondsFraction: r.secondFraction,
      sign: r.sign,
    );
  }
}
