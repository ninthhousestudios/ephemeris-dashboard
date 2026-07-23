// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'calendar.dart';
import 'time_scale.dart';

/// Which companion clock is shown *alongside* UT when rendering event times and
/// Moments. UT is always the base; this picks the second clock in parentheses.
/// The canonical Moment stays a UT Julian Day — the clock only shifts display.
///   * [standard] — civil time at the Context's UTC offset (offset 0 = just UT).
///   * [lmt]      — Local Mean Time (swetest -lmt): UT + longitude/15h.
///   * [lat]      — Local Apparent Time (swetest -lat): LMT + equation of time.
/// View-layer only, like the Calendar toggle.
enum OutputClock {
  standard('Standard'),
  lmt('LMT'),
  lat('LAT');

  const OutputClock(this.label);
  final String label;
}

/// The output-clock render inputs, gathered from the Context + clock choice.
///
/// [longitude] (east-positive degrees) drives LMT/LAT; [utcOffset] (hours)
/// drives the civil offset clock. Both are ignored for the clocks that do not
/// need them, so [ut] carries neutral values.
///
/// [calendar] and [scale] are the Context's view-layer choices for the *base*
/// render (the canonical Moment as a civil date-time): the calendar the date is
/// shown on and the time scale (UT1/TT/UTC) it is expressed in. They are carried
/// here so every Moment render — including per-row series labels — shifts with
/// the Context's Calendar and Scale, not just with the clock.
class ClockView {
  const ClockView({
    required this.clock,
    required this.longitude,
    required this.utcOffset,
    this.calendar = Calendar.gregorian,
    this.scale = TimeScale.ut1,
  });

  final OutputClock clock;
  final double longitude;
  final double utcOffset;
  final Calendar calendar;
  final TimeScale scale;

  /// Neutral default: Standard clock at zero offset, i.e. plain UT1/Gregorian.
  /// Used where no Context is in scope (e.g. export paths).
  static const ut = ClockView(
    clock: OutputClock.standard,
    longitude: 0.0,
    utcOffset: 0.0,
  );
}
