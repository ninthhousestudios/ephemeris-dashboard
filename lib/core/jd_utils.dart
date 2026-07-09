// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

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
    // result.hour is fractional hours in [0, 24). Convert to whole milliseconds
    // (rounded, not truncated) and add to midnight so DateTime carries across
    // second/minute/hour/day boundaries. Truncating here dropped a second on
    // round-trip values like 14:30:44.9999, and clamping ms to 999 masked it;
    // rounding+carry also folds the hour == 24.0 case into the next day.
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

/// Formats a Julian Day (UT) as a civil date-time string. Moment = JD canonical,
/// civil derived (CONTEXT.md). Single source for every tab's JD→string variant:
///
/// - [seconds]: include `:SS` (and, when [utcOffset] is set, in the local bracket)
/// - [utLabel]: append ` UT` to the UT portion
/// - [utcOffset]: when non-zero, append `  (HH:MM[:SS] UTC±o)` local time
/// - [emptyPlaceholder]: when non-null, return it for `NaN`/`0.0` JDs
/// - [fallbackDigits]: `toStringAsFixed` precision when `revjul` throws
///
/// Uses the carry-safe [JdUtils.jdToDateTime] path, so hour == 24.0 rolls into
/// the next day rather than rendering `24:00`.
String formatJdDateTime(
  SwissEph swe,
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
