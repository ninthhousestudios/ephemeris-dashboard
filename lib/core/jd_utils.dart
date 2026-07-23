// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'calendar.dart';
import 'swe_utils.dart';

/// DateTime ↔ Julian Day conversion helpers.
///
/// Uses SweUtils.julday/revjul for astronomically correct conversions. Each
/// direction takes a [Calendar]: the Dart [DateTime] carries civil fields only
/// (its own epoch is proleptic Gregorian and never used for absolute
/// arithmetic here), so the calendar decides how those fields map to the JD.
class JdUtils {
  const JdUtils(this._swe);
  final SweUtils _swe;

  /// Convert a Dart [DateTime] (treated as UT) to Julian Day, reading its civil
  /// fields on [calendar].
  double dateTimeToJd(DateTime dt, {Calendar calendar = Calendar.gregorian}) {
    final hour =
        dt.hour +
        dt.minute / 60.0 +
        dt.second / 3600.0 +
        dt.millisecond / 3600000.0;
    return _swe.julday(
      dt.year,
      dt.month,
      dt.day,
      hour,
      gregorian: calendar.isGregorianForCivil(dt.year, dt.month, dt.day),
    );
  }

  /// Convert a Julian Day to Dart [DateTime] (UT), rendering the civil date on
  /// [calendar].
  DateTime jdToDateTime(double jd, {Calendar calendar = Calendar.gregorian}) {
    final result = _swe.revjul(jd, gregorian: calendar.isGregorianForJd(jd));
    final totalMs = (result.hour * 3600000).round();
    final midnight = DateTime.utc(result.year, result.month, result.day);
    return midnight.add(Duration(milliseconds: totalMs));
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

String _p2(int n) => n.toString().padLeft(2, '0');

/// Formats a Julian Day (UT) as a civil date-time string.
String formatJdDateTime(
  SweUtils swe,
  double jd, {
  bool seconds = true,
  bool utLabel = true,
  double utcOffset = 0.0,
  String? emptyPlaceholder,
  int fallbackDigits = 6,
}) {
  if (emptyPlaceholder != null && (jd.isNaN || jd == 0.0)) {
    return emptyPlaceholder;
  }
  try {
    final utc = JdUtils(swe).jdToDateTime(jd);
    String hms(DateTime dt) => seconds
        ? '${_p2(dt.hour)}:${_p2(dt.minute)}:${_p2(dt.second)}'
        : '${_p2(dt.hour)}:${_p2(dt.minute)}';
    var s = '${utc.year}-${_p2(utc.month)}-${_p2(utc.day)} ${hms(utc)}';
    if (utLabel) s = '$s UT';
    if (utcOffset != 0.0) {
      final local = utc.add(Duration(minutes: (utcOffset * 60).round()));
      final sign = utcOffset >= 0 ? '+' : '';
      final off = utcOffset == utcOffset.roundToDouble()
          ? '$sign${utcOffset.round()}'
          : '$sign${utcOffset.toStringAsFixed(1)}';
      s = '$s  (${hms(local)} UTC$off)';
    }
    return s;
  } catch (_) {
    return jd.toStringAsFixed(fallbackDigits);
  }
}
