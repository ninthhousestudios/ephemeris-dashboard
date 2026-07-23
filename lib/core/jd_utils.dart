// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'calendar.dart';
import 'output_clock.dart';
import 'swe_utils.dart';
import 'time_scale.dart';

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

  /// Convert a civil (scale-time) [DateTime] to the canonical UT1 Julian Day.
  ///
  /// [dt]'s civil fields are interpreted on [scale]; the returned JD is always
  /// UT1 (the Moment), so nothing downstream ever learns a scale. Inverse of
  /// [jdUtToCivil]. On [TimeScale.utc] a value the engine rejects falls back to
  /// a plain UT1 read.
  double civilToJdUt(
    DateTime dt, {
    required Calendar calendar,
    required TimeScale scale,
  }) {
    switch (scale) {
      case TimeScale.ut1:
        return dateTimeToJd(dt, calendar: calendar);
      case TimeScale.tt:
        // `julday` yields a JD on the ET scale; step back one ΔT to UT1 (no
        // iteration, as swetest does).
        final et = dateTimeToJd(dt, calendar: calendar);
        return et - _swe.deltat(et);
      case TimeScale.utc:
        try {
          return _swe
              .utcToJd(
                dt.year,
                dt.month,
                dt.day,
                dt.hour,
                dt.minute,
                dt.second + dt.millisecond / 1000.0,
                gregorian: calendar.isGregorianForCivil(
                  dt.year,
                  dt.month,
                  dt.day,
                ),
              )
              .ut1;
        } catch (_) {
          return dateTimeToJd(dt, calendar: calendar);
        }
    }
  }

  /// Render the canonical UT1 Julian Day [jdUt] as a civil (scale-time)
  /// [DateTime] for display on [scale]. Inverse of [civilToJdUt], so entering a
  /// value on a scale and reading it back reproduces the same civil fields.
  DateTime jdUtToCivil(
    double jdUt, {
    required Calendar calendar,
    required TimeScale scale,
  }) {
    switch (scale) {
      case TimeScale.ut1:
        return jdToDateTime(jdUt, calendar: calendar);
      case TimeScale.tt:
        return jdToDateTime(jdUt + _swe.deltat(jdUt), calendar: calendar);
      case TimeScale.utc:
        try {
          final c = _swe.jdUt1ToUtc(
            jdUt,
            gregorian: calendar.isGregorianForJd(jdUt),
          );
          final ms = ((c.hour * 3600 + c.minute * 60 + c.second) * 1000)
              .round();
          return DateTime.utc(
            c.year,
            c.month,
            c.day,
          ).add(Duration(milliseconds: ms));
        } catch (_) {
          return jdToDateTime(jdUt, calendar: calendar);
        }
    }
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

/// Formats the canonical UT1 Julian Day [jd] as a civil date-time string.
///
/// The base render is the Moment expressed on the Context's Scale (UT1/TT/UTC)
/// and Calendar (both carried in [view]), so it shifts with them — not only the
/// clock. The selected output clock ([OutputClock], carried in [view] with the
/// longitude and UTC offset) is shown *alongside* it in parentheses when it
/// differs — so the base scale stays visible without the caller having to zero
/// the offset. The parenthetical carries its own date only when it crosses
/// midnight relative to the base (otherwise just the time, to stay compact).
///
/// [showLabel] appends the scale label (e.g. ` UT1`, ` TT`) to the base; pass
/// false for compact per-row renders.
/// [showCompanion] draws the parenthetical companion clock; pass false where the
/// width is tight and only the base instant is wanted (e.g. the SeriesBar label).
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

    // The base render honours the Context's Scale (UT1/TT/UTC) and Calendar,
    // so a Moment — including each series row — shifts with them, not just with
    // the companion clock.
    final base = jdUtils.jdUtToCivil(
      jd,
      calendar: view.calendar,
      scale: view.scale,
    );
    var s = render(base);
    if (showLabel) s = '$s ${view.scale.label}';

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
      final local = jdUtils.jdToDateTime(shifted, calendar: view.calendar);
      final sameDate =
          local.year == base.year &&
          local.month == base.month &&
          local.day == base.day;
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
