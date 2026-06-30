import 'package:swisseph/swisseph.dart';

/// DateTime ↔ Julian Day conversion helpers.
///
/// Uses SwissEph.julday/revjul for astronomically correct conversions.
class JdUtils {
  const JdUtils(this._swe);
  final SwissEph _swe;

  /// Convert a Dart [DateTime] (treated as UT) to Julian Day.
  double dateTimeToJd(DateTime dt) {
    final hour =
        dt.hour +
        dt.minute / 60.0 +
        dt.second / 3600.0 +
        dt.millisecond / 3600000.0;
    return _swe.julday(dt.year, dt.month, dt.day, hour);
  }

  /// Convert a Julian Day to Dart [DateTime] (UT).
  DateTime jdToDateTime(double jd) {
    final result = _swe.revjul(jd);
    final hour = result.hour;
    final h = hour.truncate();
    final minuteFrac = (hour - h) * 60.0;
    final m = minuteFrac.truncate();
    final secondFrac = (minuteFrac - m) * 60.0;
    final s = secondFrac.truncate();
    var ms = ((secondFrac - s) * 1000).round();
    // Clamp to avoid invalid DateTime when rounding pushes ms to 1000.
    if (ms >= 1000) ms = 999;
    return DateTime.utc(result.year, result.month, result.day, h, m, s, ms);
  }

  /// Apply a UTC offset (in hours) to get local DateTime for display.
  DateTime applyUtcOffset(DateTime utcDt, double offsetHours) {
    final totalMinutes = (offsetHours * 60).round();
    return utcDt.add(Duration(minutes: totalMinutes));
  }

  /// Remove a UTC offset to get back to UT.
  DateTime removeUtcOffset(DateTime localDt, double offsetHours) {
    final totalMinutes = (offsetHours * 60).round();
    return localDt.subtract(Duration(minutes: totalMinutes));
  }
}
