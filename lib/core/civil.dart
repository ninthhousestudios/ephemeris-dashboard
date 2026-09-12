// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// A civil date-time as raw integer fields.
///
/// Dart's [DateTime] is proleptic Gregorian and silently rolls a date it cannot
/// represent (e.g. `DateTime.utc(1900, 2, 29)` → 1 Mar 1900), so it is an
/// unsound carrier for a calendar-aware civil value: a Julian-only date such as
/// 29 Feb 1900 (a valid Julian leap day) would not survive a round-trip. These
/// fields do, because nothing normalises them behind the calendar's back.
///
/// Lives in its own leaf file (no core imports) so that pure consumers such as
/// `timezone_offset.dart` can carry a civil value without importing `jd_utils`,
/// which would drag them into the engine↔context import cycle.
typedef Civil = ({
  int year,
  int month,
  int day,
  int hour,
  int minute,
  int second,
});
