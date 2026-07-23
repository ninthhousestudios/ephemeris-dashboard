// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Which clock event times and Moments are rendered in.
///
/// Mutually exclusive output-time rendering: the canonical Moment stays a UT
/// Julian Day, and the clock only shifts how that instant is *displayed*.
///   * [ut]        — Universal Time (no shift).
///   * [utcOffset] — civil time at the Context's UTC offset.
///   * [lmt]       — Local Mean Time (swetest -lmt): UT + longitude/15h.
///   * [lat]       — Local Apparent Time (swetest -lat): LMT + equation of time.
/// View-layer only, like the Calendar toggle.
enum OutputClock {
  ut('UT'),
  utcOffset('UTC offset'),
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
class ClockView {
  const ClockView({
    required this.clock,
    required this.longitude,
    required this.utcOffset,
  });

  final OutputClock clock;
  final double longitude;
  final double utcOffset;

  /// Neutral default: render in UT. Used where no Context is in scope.
  static const ut = ClockView(
    clock: OutputClock.ut,
    longitude: 0.0,
    utcOffset: 0.0,
  );
}
