// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// The time scale a civil date/time field is entered in and displayed on.
///
/// A view-layer concern only, exactly like [Calendar]: the canonical Moment is
/// always a UT1 Julian Day, and the scale is just an input transform on the way
/// in and a display label on the way out. Nothing downstream of the Moment
/// carries a scale — it never enters a compute signature.
///
/// Maps to swetest's `-ut` / `-t` / `-utc`:
/// - [ut1]: the civil value *is* UT1 (today's behaviour). `julday → ut`.
/// - [tt]: the civil value is Terrestrial/Ephemeris Time. `julday` yields a JD
///   on the ET scale; `ut = et − ΔT`, one ΔT step (no iteration), as swetest
///   does. ΔT comes from the engine, so switching ephemeris source nudges it.
/// - [utc]: the civil value is UTC (leap seconds). The engine's `utc_to_jd`
///   returns UT1 and TT directly, so leap seconds are handled correctly.
enum TimeScale {
  ut1('UT1'),
  tt('TT'),
  utc('UTC');

  const TimeScale(this.label);

  final String label;
}
