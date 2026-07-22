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
library;

/// Floor division. Dart's `~/` truncates toward zero, which is wrong for the
/// negative operands the conversions below see before ~4800 BCE — the era
/// boundary is well inside the ephemeris range, so this is not a theoretical
/// concern. Dart's `%` already floors for a positive divisor, so only the
/// quotient needs correcting.
int _floorDiv(int a, int b) {
  final q = a ~/ b;
  return a - q * b < 0 ? q - 1 : q;
}

/// Civil date of the Gregorian day containing Julian Day Number [jdn].
({int year, int month, int day}) _civilFromJdn(int jdn) {
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
int _jdnFromCivil(int year, int month, int day) {
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

bool _isLeapYear(int year) =>
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

const _monthLengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

/// Days in [month] of [year], Gregorian.
int daysInMonth(int year, int month) =>
    month == 2 && _isLeapYear(year) ? 29 : _monthLengths[month - 1];

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
double addCalendarMonths(double ut, int months) {
  if (months == 0) return ut;

  // Julian Days start at noon, so the civil day containing [ut] starts at
  // jdn - 0.5. Splitting there keeps the time of day exact.
  final jdn = (ut + 0.5).floor();
  final dayFraction = ut + 0.5 - jdn;

  final civil = _civilFromJdn(jdn);

  final totalMonths = civil.year * 12 + (civil.month - 1) + months;
  final year = _floorDiv(totalMonths, 12);
  final month = totalMonths - year * 12 + 1;
  final day = civil.day.clamp(1, daysInMonth(year, month));

  return _jdnFromCivil(year, month, day) - 0.5 + dayFraction;
}
