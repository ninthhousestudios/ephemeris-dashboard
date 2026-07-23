// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Which calendar a civil date is read in when it maps to (or from) a Julian
/// Day.
///
/// A view-layer concern only: the Moment stays a Julian Day, and the calendar
/// decides how a typed civil value maps to that JD (and how a JD renders back
/// as a civil date). Nothing downstream of the Moment carries a calendar.
///
/// [auto] reproduces swetest's default: a date is Julian before the Gregorian
/// reform (last Julian day 4 Oct 1582, first Gregorian day 15 Oct 1582) and
/// Gregorian on or after it. The ten "missing" days (5–14 Oct 1582) do not
/// exist on either calendar; typed as an [auto] civil date they read as Julian,
/// which is what swetest does — it converts them rather than rejecting them.
enum Calendar {
  auto('Auto (1582)'),
  gregorian('Proleptic Gregorian'),
  julian('Julian');

  const Calendar(this.label);

  final String label;

  /// Julian Day at which the Gregorian reform takes effect: midnight beginning
  /// 15 Oct 1582 Gregorian, which is the same instant as 5 Oct 1582 Julian.
  static const double reformJd = 2299160.5;

  /// Whether the civil date [year]-[month]-[day] is read on the Gregorian
  /// calendar under this mode. Drives the civil → JD direction.
  bool isGregorianForCivil(int year, int month, int day) => switch (this) {
    Calendar.gregorian => true,
    Calendar.julian => false,
    Calendar.auto => _atOrAfterReform(year, month, day),
  };

  /// Whether the day containing Julian Day [jd] renders on the Gregorian
  /// calendar under this mode. Drives the JD → civil direction.
  bool isGregorianForJd(double jd) => switch (this) {
    Calendar.gregorian => true,
    Calendar.julian => false,
    Calendar.auto => jd >= reformJd,
  };

  /// Whether [year]-[month]-[day] is a real civil date *on the calendar this
  /// mode reads it in*. The February leap rule differs between calendars (1900
  /// is a Julian leap year but not a Gregorian one), so this is calendar-aware,
  /// unlike a Dart [DateTime] check which is always proleptic Gregorian.
  ///
  /// The ten reform-gap dates (5–14 Oct 1582) are *not* rejected: under [auto]
  /// they read as Julian (matching swetest, which converts rather than rejects),
  /// and month length is the same on both calendars there anyway.
  bool isValidCivil(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return false;
    return day <=
        daysInMonth(
          year,
          month,
          gregorian: isGregorianForCivil(year, month, day),
        );
  }
}

bool _isLeapYear(int year, {required bool gregorian}) => gregorian
    ? year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    : year % 4 == 0;

const _monthLengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

/// Days in [month] of [year], on the calendar [gregorian] selects (the leap
/// rule differs for February).
int daysInMonth(int year, int month, {bool gregorian = true}) =>
    month == 2 && _isLeapYear(year, gregorian: gregorian)
    ? 29
    : _monthLengths[month - 1];

/// Whether civil date [y]-[m]-[d] falls on or after 15 Oct 1582 (the first
/// Gregorian date). Gap dates (5–14 Oct 1582) compare as *before* the reform,
/// so [Calendar.auto] reads them as Julian — matching swetest.
bool _atOrAfterReform(int y, int m, int d) {
  if (y != 1582) return y > 1582;
  if (m != 10) return m > 10;
  return d >= 15;
}
