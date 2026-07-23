// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'calendar.dart';
import 'output_clock.dart';
import 'swe_utils.dart';
import 'time_scale.dart';

/// A civil date-time as raw integer fields.
///
/// Dart's [DateTime] is proleptic Gregorian and silently rolls a date it cannot
/// represent (e.g. `DateTime.utc(1900, 2, 29)` → 1 Mar 1900), so it is an
/// unsound carrier for a calendar-aware civil value: a Julian-only date such as
/// 29 Feb 1900 (a valid Julian leap day) would not survive a round-trip. These
/// fields do, because nothing normalises them behind the calendar's back.
typedef Civil = ({
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
});

/// DateTime ↔ Julian Day conversion helpers.
///
/// Uses SweUtils.julday/revjul for astronomically correct conversions. Each
/// direction takes a [Calendar]: the Dart [DateTime] carries civil fields only
/// (its own epoch is proleptic Gregorian and never used for absolute
/// arithmetic here), so the calendar decides how those fields map to the JD.
///
/// The [DateTime]-returning members are kept for callers on representable
/// (proleptic-Gregorian) dates; the [Civil]-field members ([localCivilOf],
/// [localCivilToJdUt], [civilFieldsOn]) are the ones to use wherever a
/// Julian-only civil date must survive, e.g. the context bar's date/time fields.
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

  /// Civil fields for the day-instant containing [jd], rendered on [calendar].
  ///
  /// Raw-field twin of [jdToDateTime]. The JD is first snapped to a whole second
  /// (in JD space, where the calendar is irrelevant) so rounding the time of day
  /// can never carry it past midnight onto the wrong civil day.
  Civil civilFieldsOn(double jd, Calendar calendar) {
    final snapped = (jd * 86400).roundToDouble() / 86400.0;
    final r = _swe.revjul(
      snapped,
      gregorian: calendar.isGregorianForJd(snapped),
    );
    final secs = (r.hour * 3600).round().clamp(0, 86399);
    return (
      year: r.year,
      month: r.month,
      day: r.day,
      hour: secs ~/ 3600,
      minute: (secs % 3600) ~/ 60,
      second: secs % 60,
    );
  }

  /// Local civil fields for the Moment [jdUt], rendered on [scale]/[calendar]
  /// and shifted to local by [offsetHours].
  ///
  /// The raw-field twin of [jdUtToCivil] + [applyUtcOffset]. The offset is
  /// applied in JD space (`offsetHours / 24` days) so no intermediate [DateTime]
  /// can normalise a Julian-only civil date away.
  Civil localCivilOf(
    double jdUt, {
    required Calendar calendar,
    required TimeScale scale,
    required double offsetHours,
  }) {
    switch (scale) {
      case TimeScale.ut1:
        return civilFieldsOn(jdUt + offsetHours / 24.0, calendar);
      case TimeScale.tt:
        return civilFieldsOn(
          jdUt + _swe.deltat(jdUt) + offsetHours / 24.0,
          calendar,
        );
      case TimeScale.utc:
        // UTC exists only from 1972 on — always proleptic Gregorian — so the
        // DateTime path is safe here and keeps the leap-second handling.
        final dt = applyUtcOffset(
          jdUtToCivil(jdUt, calendar: calendar, scale: scale),
          offsetHours,
        );
        return (
          year: dt.year,
          month: dt.month,
          day: dt.day,
          hour: dt.hour,
          minute: dt.minute,
          second: dt.second,
        );
    }
  }

  /// Map local civil fields (read on [scale]/[calendar], shifted by
  /// [offsetHours]) back to the canonical UT1 Julian Day.
  ///
  /// The raw-field twin of [removeUtcOffset] + [civilToJdUt]. The offset is
  /// removed in JD space, so a Julian-only date such as 29 Feb 1900 maps to its
  /// true JD instead of being rolled to 1 Mar by a [DateTime] intermediary.
  double localCivilToJdUt(
    Civil civil, {
    required Calendar calendar,
    required TimeScale scale,
    required double offsetHours,
  }) {
    final hour = civil.hour + civil.minute / 60.0 + civil.second / 3600.0;
    final greg = calendar.isGregorianForCivil(
      civil.year,
      civil.month,
      civil.day,
    );
    // JD of the local fields read as if UT, then shifted to the scale reading by
    // removing the offset (offsetHours / 24 days).
    final scaleJd =
        _swe.julday(civil.year, civil.month, civil.day, hour, gregorian: greg) -
        offsetHours / 24.0;
    switch (scale) {
      case TimeScale.ut1:
        return scaleJd;
      case TimeScale.tt:
        // scaleJd is on the ET scale; step back one ΔT to UT1 (as swetest does).
        return scaleJd - _swe.deltat(scaleJd);
      case TimeScale.utc:
        try {
          final f = civilFieldsOn(scaleJd, calendar);
          return _swe
              .utcToJd(
                f.year,
                f.month,
                f.day,
                f.hour,
                f.minute,
                f.second.toDouble(),
                gregorian: calendar.isGregorianForJd(scaleJd),
              )
              .ut1;
        } catch (_) {
          return scaleJd;
        }
    }
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
    String hms(Civil c) => seconds
        ? '${_p2(c.hour)}:${_p2(c.minute)}:${_p2(c.second)}'
        : '${_p2(c.hour)}:${_p2(c.minute)}';
    String render(Civil c) =>
        '${c.year}-${_p2(c.month)}-${_p2(c.day)} ${hms(c)}';

    // The base render honours the Context's Scale (UT1/TT/UTC) and Calendar,
    // so a Moment — including each series row — shifts with them, not just with
    // the companion clock. Raw civil fields (not a DateTime) so a Julian-only
    // date such as 29 Feb 1900 renders truthfully.
    final base = jdUtils.localCivilOf(
      jd,
      calendar: view.calendar,
      scale: view.scale,
      offsetHours: 0,
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
      final local = jdUtils.civilFieldsOn(shifted, view.calendar);
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
