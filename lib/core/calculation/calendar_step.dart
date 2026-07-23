// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Calendar-aware arithmetic on a Julian Day.
///
/// Months and years have no fixed length, so a monthly or yearly series has to
/// step the civil calendar rather than add days. The conversion is integer
/// arithmetic on the Julian Day Number (proleptic Gregorian, Fliegel–Van
/// Flandern) so the series core stays engine-free: `rs.julday`/`rs.revjul`
/// would drag the native library into every unit test that builds a series.
///
/// The time of day is carried across untouched — the day fraction is split off
/// before the conversion and added back after — so a step never drifts by
/// rounding through a civil clock.
///
/// The conversions honour a [Calendar]: proleptic Gregorian by default, but a
/// Julian or [Calendar.auto] series steps the civil calendar it is read in. In
/// [Calendar.auto] each step re-derives which calendar the resulting civil date
/// falls in, so a monthly walk crossing Oct 1582 flips Julian → Gregorian
/// exactly where swetest does (15.9.1582 jul → 15.10.1582 greg, a 20-day jump).
library;

import '../calendar.dart';

/// Floor division. Dart's `~/` truncates toward zero, which is wrong for the
/// negative operands the conversions below see before ~4800 BCE — the era
/// boundary is well inside the ephemeris range, so this is not a theoretical
/// concern. Dart's `%` already floors for a positive divisor, so only the
/// quotient needs correcting.
int _floorDiv(int a, int b) {
  final q = a ~/ b;
  return a - q * b < 0 ? q - 1 : q;
}

/// Civil date of the day containing Julian Day Number [jdn], on the calendar
/// [gregorian] selects.
({int year, int month, int day}) _civilFromJdn(
  int jdn, {
  required bool gregorian,
}) => gregorian ? _civilFromJdnGregorian(jdn) : _civilFromJdnJulian(jdn);

/// Julian Day Number of [year]-[month]-[day] on the calendar [gregorian]
/// selects.
int _jdnFromCivil(int year, int month, int day, {required bool gregorian}) =>
    gregorian
    ? _jdnFromCivilGregorian(year, month, day)
    : _jdnFromCivilJulian(year, month, day);

/// Civil date of the Gregorian day containing Julian Day Number [jdn].
({int year, int month, int day}) _civilFromJdnGregorian(int jdn) {
  final j = jdn + 32044;
  final g = _floorDiv(j, 146097);
  // Flooring [g] keeps [dg] non-negative, so every division below this line
  // has non-negative operands and truncation and flooring agree.
  final dg = j - g * 146097;
  final c = (dg ~/ 36524 + 1) * 3 ~/ 4;
  final dc = dg - c * 36524;
  final b = dc ~/ 1461;
  final db = dc % 1461;
  final a = (db ~/ 365 + 1) * 3 ~/ 4;
  final da = db - a * 365;
  final y = g * 400 + c * 100 + b * 4 + a;
  final m = (da * 5 + 308) ~/ 153 - 2;
  final d = da - (m + 4) * 153 ~/ 5 + 122;
  return (year: y - 4800 + (m + 2) ~/ 12, month: (m + 2) % 12 + 1, day: d + 1);
}

/// Julian Day Number of the Gregorian date [year]-[month]-[day].
int _jdnFromCivilGregorian(int year, int month, int day) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  // [y] goes negative before ~4800 BCE, so its divisions must floor.
  return day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      _floorDiv(y, 4) -
      _floorDiv(y, 100) +
      _floorDiv(y, 400) -
      32045;
}

/// Civil date of the Julian day containing Julian Day Number [jdn].
///
/// Richards' integer algorithm (Julian variant). Julian Day Numbers stay
/// positive across the whole ephemeris range (5400 BCE onward), so the plain
/// `~/` and `%` are safe here — no flooring correction is needed, unlike the
/// civil → JDN direction whose year term goes negative before ~4800 BCE.
({int year, int month, int day}) _civilFromJdnJulian(int jdn) {
  final e = 4 * (jdn + 1401) + 3;
  final h = 5 * ((e % 1461) ~/ 4) + 2;
  final day = (h % 153) ~/ 5 + 1;
  final month = (h ~/ 153 + 2) % 12 + 1;
  final year = e ~/ 1461 - 4716 + (14 - month) ~/ 12;
  return (year: year, month: month, day: day);
}

/// Julian Day Number of the Julian date [year]-[month]-[day].
///
/// Same shape as the Gregorian form minus the century terms; the constant
/// differs (32083 vs 32045) to absorb them.
int _jdnFromCivilJulian(int year, int month, int day) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;
  // [y] goes negative before ~4800 BCE, so its division must floor.
  return day + (153 * m + 2) ~/ 5 + 365 * y + _floorDiv(y, 4) - 32083;
}

/// [ut] advanced by [months] calendar months, preserving the time of day.
///
/// The day of month is clamped to the target month's length, so 31 Jan plus
/// one month is 28 (or 29) Feb. [months] may be negative, which steps
/// backward.
///
/// Clamping is a deliberate choice, not swetest's rule: measured against
/// swetest 2.10.03, `-s1mo` from 31.1.2000 gives 02.03.2000, because it lets
/// "31 February" roll over rather than clamping it. Ours is the tidier
/// calendar behaviour and the goal is the general capability, not swetest's
/// exact output. Do not "fix" this toward 2 March without deciding that
/// deliberately.
///
/// [calendar] decides which calendar the source [ut] is read in and which the
/// resulting civil date is written back on. Under [Calendar.auto] these can
/// differ within one step — a step landing on/after 15 Oct 1582 writes back
/// Gregorian even if it started Julian — which is how a monthly series crosses
/// the reform gap the way swetest does.
double addCalendarMonths(
  double ut,
  int months, [
  Calendar calendar = Calendar.gregorian,
]) {
  if (months == 0) return ut;

  // Julian Days start at noon, so the civil day containing [ut] starts at
  // jdn - 0.5. Splitting there keeps the time of day exact.
  final jdn = (ut + 0.5).floor();
  final dayFraction = ut + 0.5 - jdn;

  final civil = _civilFromJdn(jdn, gregorian: calendar.isGregorianForJd(ut));

  final totalMonths = civil.year * 12 + (civil.month - 1) + months;
  final year = _floorDiv(totalMonths, 12);
  final month = totalMonths - year * 12 + 1;
  final targetGregorian = calendar.isGregorianForCivil(year, month, civil.day);
  final day = civil.day.clamp(
    1,
    daysInMonth(year, month, gregorian: targetGregorian),
  );

  return _jdnFromCivil(year, month, day, gregorian: targetGregorian) -
      0.5 +
      dayFraction;
}
