// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'calendar.dart';
import 'output_clock.dart';
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

/// Formats a Julian Day (UT) as a civil date-time string in the selected
/// output clock (UT / civil UTC offset / LMT / LAT — see [OutputClock]).
///
/// [jd] is always the canonical UT Julian Day; [view] carries the clock choice
/// plus the longitude (for LMT/LAT) and UTC offset (for the civil clock).
/// [showLabel] appends the clock label (e.g. ` UT`, ` LMT`, ` UTC+2`); pass
/// false for compact per-row renders where the global clock is already shown.
String formatJdDateTime(
  SweUtils swe,
  double jd, {
  ClockView view = ClockView.ut,
  bool seconds = true,
  bool showLabel = true,
  String? emptyPlaceholder,
  int fallbackDigits = 6,
}) {
  if (emptyPlaceholder != null && (jd.isNaN || jd == 0.0)) {
    return emptyPlaceholder;
  }
  try {
    // Shift the UT Julian Day onto the selected output clock, then render its
    // civil fields. LMT = UT + longitude/15h (= /360 days); LAT = LMT + eqTime.
    final (double shifted, String label) = switch (view.clock) {
      OutputClock.standard => (
        jd + view.utcOffset / 24.0,
        view.utcOffset == 0.0 ? 'UT' : 'UTC${_fmtOffset(view.utcOffset)}',
      ),
      OutputClock.lmt => (jd + view.longitude / 360.0, 'LMT'),
      OutputClock.lat => (jd + view.longitude / 360.0 + swe.timeEqu(jd), 'LAT'),
    };
    final dt = JdUtils(swe).jdToDateTime(shifted);
    final hms = seconds
        ? '${_p2(dt.hour)}:${_p2(dt.minute)}:${_p2(dt.second)}'
        : '${_p2(dt.hour)}:${_p2(dt.minute)}';
    var s = '${dt.year}-${_p2(dt.month)}-${_p2(dt.day)} $hms';
    if (showLabel) s = '$s $label';
    return s;
  } catch (_) {
    return jd.toStringAsFixed(fallbackDigits);
  }
}

/// Signed UTC-offset suffix, e.g. `+2`, `-5.5`, `+0`.
String _fmtOffset(double offsetHours) {
  final sign = offsetHours >= 0 ? '+' : '';
  return offsetHours == offsetHours.roundToDouble()
      ? '$sign${offsetHours.round()}'
      : '$sign${offsetHours.toStringAsFixed(1)}';
}
