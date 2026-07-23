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

/// Formats a Julian Day (UT) as a civil date-time string.
///
/// The canonical UT time is always the base render; the selected output clock
/// ([OutputClock], carried in [view] with the longitude and UTC offset) is
/// shown *alongside* it in parentheses when it differs from UT — so UT stays
/// visible without the caller having to zero the offset. The parenthetical
/// carries its own date only when it crosses midnight relative to UT (otherwise
/// just the time, to stay compact).
///
/// [showLabel] appends ` UT` to the base; pass false for compact per-row renders.
/// [showCompanion] draws the parenthetical companion clock; pass false where the
/// width is tight and only the UT instant is wanted (e.g. the SeriesBar label).
String formatJdDateTime(
  SweUtils swe,
  double jd, {
  ClockView view = ClockView.ut,
  bool seconds = true,
  bool showLabel = true,
  bool showCompanion = true,
  String? emptyPlaceholder,
  int fallbackDigits = 6,
}) {
  if (emptyPlaceholder != null && (jd.isNaN || jd == 0.0)) {
    return emptyPlaceholder;
  }
  try {
    final jdUtils = JdUtils(swe);
    String hms(DateTime dt) => seconds
        ? '${_p2(dt.hour)}:${_p2(dt.minute)}:${_p2(dt.second)}'
        : '${_p2(dt.hour)}:${_p2(dt.minute)}';
    String render(DateTime dt) =>
        '${dt.year}-${_p2(dt.month)}-${_p2(dt.day)} ${hms(dt)}';

    final utc = jdUtils.jdToDateTime(jd);
    var s = render(utc);
    if (showLabel) s = '$s UT';

    // The companion clock, shown next to UT. LMT = UT + longitude/15h
    // (= /360 days); LAT = LMT + equation of time. Standard at offset 0 *is*
    // UT, so it adds nothing.
    final (double? shifted, String? label) = !showCompanion
        ? (null, null)
        : switch (view.clock) {
            OutputClock.standard =>
              view.utcOffset == 0.0
                  ? (null, null)
                  : (
                      jd + view.utcOffset / 24.0,
                      'UTC${_fmtOffset(view.utcOffset)}',
                    ),
            OutputClock.lmt => (jd + view.longitude / 360.0, 'LMT'),
            OutputClock.lat => (
              jd + view.longitude / 360.0 + swe.timeEqu(jd),
              'LAT',
            ),
          };
    if (shifted != null) {
      final local = jdUtils.jdToDateTime(shifted);
      final sameDate =
          local.year == utc.year &&
          local.month == utc.month &&
          local.day == utc.day;
      final localStr = sameDate ? hms(local) : render(local);
      s = '$s  ($localStr $label)';
    }
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
