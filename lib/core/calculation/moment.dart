// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../ephemeris/ephemeris.dart';

/// A single instant, in both time scales the engine takes.
///
/// UT is canonical — the Context Moment is a Julian Day in UT, and civil
/// date/time is a derived view of it. ET is needed by `getOrbitalElements`,
/// `orbitMaxMinTrueDistance` and `calcPctr`, and is reported by the Dates tab.
///
/// ET is derived through the engine's ΔT on first access, so a calculation
/// that never leaves UT — most of them — pays nothing for it. That matters in
/// a series, where one Moment is built per step.
class Moment {
  /// ΔT given explicitly, for callers that already hold one and for tests that
  /// want a fixed ET without an engine. This is the precision-preserving form:
  /// ΔT is carried at its own magnitude and never round-tripped through a
  /// Julian-Day-scale subtraction.
  Moment({required this.ut, required double deltaT}) : _deltaT = (() => deltaT);

  /// ET given instead of ΔT. **Lossy**: `et - ut` at Julian Day magnitudes
  /// drops the low bits of a ~0.0008-day ΔT (an exact 0.0008 comes back as
  /// 0.000800000037997961). Use the default constructor unless ET really is
  /// the only quantity you hold.
  Moment.fromUtAndEt({required double ut, required double et})
    : ut = ut,
      _deltaT = (() => et - ut);

  /// ΔT taken from the engine on first access.
  Moment.fromUt(double ut, Ephemeris eph)
    : ut = ut,
      _deltaT = (() => eph.deltat(ut));

  /// Julian Day, Universal Time.
  final double ut;

  final double Function() _deltaT;

  /// ΔT in days. Stored rather than derived from [et]: at Julian Day
  /// magnitudes, `et - ut` loses the low bits of a ~0.0008-day quantity.
  late final double deltaT = _deltaT();

  /// Julian Day, Ephemeris Time.
  double get et => ut + deltaT;

  @override
  String toString() => 'Moment(ut: $ut)';
}
