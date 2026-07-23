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
  gregorian('Gregorian'),
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
}

/// Whether civil date [y]-[m]-[d] falls on or after 15 Oct 1582 (the first
/// Gregorian date). Gap dates (5–14 Oct 1582) compare as *before* the reform,
/// so [Calendar.auto] reads them as Julian — matching swetest.
bool _atOrAfterReform(int y, int m, int d) {
  if (y != 1582) return y > 1582;
  if (m != 10) return m > 10;
  return d >= 15;
}
