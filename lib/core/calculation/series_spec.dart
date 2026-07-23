// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../calendar.dart';
import 'calendar_step.dart';
import 'moment.dart';

/// Step size unit for a time series.
///
/// Seconds through weeks are a fixed number of days and step by arithmetic on
/// the Julian Day. Months and years have no fixed length and step the civil
/// calendar instead, so a monthly series stays on its calendar date rather
/// than drifting off it. Hours and weeks are extras beyond swetest's
/// `s/m/d/mo/y`; the day-of-month rule differs from swetest's too, see
/// [addCalendarMonths].
enum StepUnit {
  seconds('Seconds'),
  minutes('Minutes'),
  hours('Hours'),
  days('Days'),
  weeks('Weeks'),
  months('Months'),
  years('Years');

  const StepUnit(this.label);

  final String label;

  /// Whether the unit steps the civil calendar rather than a fixed span.
  bool get isCalendar => this == StepUnit.months || this == StepUnit.years;

  /// Whether [stepValue] describes a usable series in this unit.
  ///
  /// Zero repeats one Moment for every row and a non-finite value has no
  /// Moment at all. A calendar unit additionally rejects a fractional value:
  /// a quarter of a month is not a calendar quantity, and rounding one
  /// silently yields a series with repeated dates and jumps.
  ///
  /// This is the one gate — every step-value input must ask it, since
  /// [advanceFrom] has to stay a total function and cannot refuse.
  bool acceptsStepValue(double stepValue) =>
      stepValue.isFinite &&
      stepValue != 0 &&
      (!isCalendar || stepValue == stepValue.roundToDouble());

  /// The nearest value this unit accepts, for carrying a step value across a
  /// unit switch: 2.5 Days is meaningful, 2.5 Months is not.
  ///
  /// Rounding first preserves the user's magnitude and sign where it can; the
  /// ±1 fallback is for values no rounding rescues (0, NaN, infinity).
  double snapStepValue(double current) {
    if (acceptsStepValue(current)) return current;
    final rounded = current.roundToDouble();
    if (acceptsStepValue(rounded)) return rounded;
    return current.isNegative ? -1.0 : 1.0;
  }

  /// UT of step [index] of a series starting at [startUt] and stepping
  /// [stepValue] of this unit. A negative [stepValue] steps backward.
  ///
  /// [stepValue] is assumed to have passed [acceptsStepValue]; the rounding
  /// on the calendar branches is a total-function fallback, not a feature.
  ///
  /// [calendar] only reaches the month/year branches — the fixed-span units are
  /// pure Julian Day arithmetic and read no calendar.
  double advanceFrom(
    double startUt,
    double stepValue,
    int index, [
    Calendar calendar = Calendar.gregorian,
  ]) => switch (this) {
    StepUnit.seconds => startUt + index * stepValue / 86400.0,
    StepUnit.minutes => startUt + index * stepValue / 1440.0,
    StepUnit.hours => startUt + index * stepValue / 24.0,
    StepUnit.days => startUt + index * stepValue,
    StepUnit.weeks => startUt + index * stepValue * 7.0,
    StepUnit.months => addCalendarMonths(
      startUt,
      (index * stepValue).round(),
      calendar,
    ),
    StepUnit.years => addCalendarMonths(
      startUt,
      (index * stepValue * 12).round(),
      calendar,
    ),
  };
}

/// Row count above which the series is still computed but the user is warned.
const int seriesSoftRowCap = 500;

/// Row count the series will never exceed. Recompute is synchronous
/// (ADR-0001), so an unbounded series would freeze the UI.
const int seriesHardRowCap = 2000;

/// User-visible warning about a requested row count, or null when it is
/// unremarkable.
///
/// Free of [SeriesSpec] so the series bar can warn about a row count as it is
/// typed, before there is a Moment to start from.
String? rowCountWarning(int rowCount) {
  if (rowCount > seriesHardRowCap) {
    return 'Row count capped at $seriesHardRowCap (requested $rowCount). '
        'The series is computed on the UI thread.';
  }
  if (rowCount > seriesSoftRowCap) {
    return '$rowCount rows is above the $seriesSoftRowCap-row comfort limit — '
        'recompute may be visibly slow.';
  }
  return null;
}

/// Everything needed to turn one Moment into N: where to start, how far to
/// step, and how many rows to produce.
///
/// The start is the Context Moment; a negative [stepValue] runs the series
/// backward.
class SeriesSpec {
  const SeriesSpec({
    required this.start,
    required this.stepValue,
    required this.stepUnit,
    required this.rowCount,
    this.calendar = Calendar.gregorian,
  });

  final Moment start;
  final double stepValue;
  final StepUnit stepUnit;

  /// Which calendar the month/year steps walk. Context-owned, threaded in from
  /// the Context bar. Irrelevant to the fixed-span units.
  final Calendar calendar;

  /// Rows as requested by the user, before the caps are applied.
  final int rowCount;

  /// Rows actually produced.
  int get effectiveRowCount => rowCount.clamp(1, seriesHardRowCap);

  bool get exceedsSoftCap => effectiveRowCount > seriesSoftRowCap;
  bool get exceedsHardCap => rowCount > seriesHardRowCap;

  /// User-visible warning about the row count, or null when it is unremarkable.
  String? get warning => rowCountWarning(rowCount);

  /// UT of step [index], counting from 0.
  double utAt(int index) =>
      stepUnit.advanceFrom(start.ut, stepValue, index, calendar);
}
