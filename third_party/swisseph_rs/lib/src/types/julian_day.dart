// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Counterpart: swisseph::types::CalendarType
enum CalendarType {
  /// Counterpart: swisseph::types::CalendarType::Julian
  julian(0),

  /// Counterpart: swisseph::types::CalendarType::Gregorian
  gregorian(1);

  final int value;
  const CalendarType(this.value);
}

/// Counterpart: swisseph::types::JdUt1
extension type const JdUt1(double value) {
  JdUt1 operator +(double days) => JdUt1(value + days);
  JdUt1 operator -(double days) => JdUt1(value - days);

  /// Counterpart: swisseph::JdUt1 (Sub, Output = f64)
  double difference(JdUt1 other) => value - other.value;

  /// Counterpart: (systematic divergence: additive DateTime helper)
  DateTime toDateTime() {
    final z = (value + 0.5).floor();
    final f = value + 0.5 - z;

    // Proleptic Gregorian — matches DateTime.toJdUt1() which is always Gregorian.
    final alpha = ((z - 1867216.25) / 36524.25).floor();
    final a = z + 1 + alpha - (alpha ~/ 4);

    final b = a + 1524;
    final c = ((b - 122.1) / 365.25).floor();
    final d = (365.25 * c).floor();
    final e = ((b - d) / 30.6001).floor();

    final dayFrac = b - d - (30.6001 * e).floor() + f;
    final day = dayFrac.floor();
    final month = e < 14 ? e - 1 : e - 13;
    final year = month > 2 ? c - 4716 : c - 4715;

    final hourFrac = (dayFrac - day) * 24;
    final hour = hourFrac.floor();
    final minuteFrac = (hourFrac - hour) * 60;
    final minute = minuteFrac.floor();
    final secondFrac = (minuteFrac - minute) * 60;
    final second = secondFrac.floor();
    final millisecond = ((secondFrac - second) * 1000).round();

    return DateTime.utc(year, month, day, hour, minute, second, millisecond);
  }
}

/// Counterpart: swisseph::types::JdTt
extension type const JdTt(double value) {
  JdTt operator +(double days) => JdTt(value + days);
  JdTt operator -(double days) => JdTt(value - days);

  /// Counterpart: swisseph::JdTt (Sub, Output = f64)
  double difference(JdTt other) => value - other.value;
}

/// Additive DateTime ↔ JdUt1 helpers (systematic divergence: DateTime helpers).
extension DateTimeToJd on DateTime {
  /// Convert a [DateTime] to [JdUt1] (Gregorian calendar, treats UTC as UT1).
  JdUt1 toJdUt1() {
    var y = year;
    var m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = y ~/ 100;
    final b = 2 - a + (a ~/ 4);
    final dayFrac =
        day + (hour + (minute + (second + millisecond / 1000) / 60) / 60) / 24;
    final jd =
        (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        dayFrac +
        b -
        1524.5;
    return JdUt1(jd);
  }
}
