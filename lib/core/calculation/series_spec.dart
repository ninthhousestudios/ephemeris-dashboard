// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'calendar_step.dart';
import 'moment.dart';

/// Step size unit for a time series.
///
/// Seconds through weeks are a fixed number of days and step by arithmetic on
/// the Julian Day. Months and years have no fixed length and step the civil
/// calendar instead, so a monthly series stays on its calendar date the way
/// `swetest -s1mo` does. Hours and weeks are extras beyond swetest.
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

  /// UT of step [index] of a series starting at [startUt] and stepping
  /// [stepValue] of this unit. A negative [stepValue] steps backward.
  ///
  /// [stepValue] is assumed to have passed [acceptsStepValue]; the rounding
  /// on the calendar branches is a total-function fallback, not a feature.
  double advanceFrom(double startUt, double stepValue, int index) =>
      switch (this) {
        StepUnit.seconds => startUt + index * stepValue / 86400.0,
        StepUnit.minutes => startUt + index * stepValue / 1440.0,
        StepUnit.hours => startUt + index * stepValue / 24.0,
        StepUnit.days => startUt + index * stepValue,
        StepUnit.weeks => startUt + index * stepValue * 7.0,
        StepUnit.months => addCalendarMonths(
          startUt,
          (index * stepValue).round(),
        ),
        StepUnit.years => addCalendarMonths(
          startUt,
          (index * stepValue * 12).round(),
        ),
      };
}

/// Row count above which the series is still computed but the user is warned.
const int seriesSoftRowCap = 500;

/// Row count the series will never exceed. Recompute is synchronous
/// (ADR-0001), so an unbounded series would freeze the UI.
const int seriesHardRowCap = 2000;

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
  });

  final Moment start;
  final double stepValue;
  final StepUnit stepUnit;

  /// Rows as requested by the user, before the caps are applied.
  final int rowCount;

  /// Rows actually produced.
  int get effectiveRowCount => rowCount.clamp(1, seriesHardRowCap);

  bool get exceedsSoftCap => effectiveRowCount > seriesSoftRowCap;
  bool get exceedsHardCap => rowCount > seriesHardRowCap;

  /// User-visible warning about the row count, or null when it is unremarkable.
  String? get warning {
    if (exceedsHardCap) {
      return 'Row count capped at $seriesHardRowCap (requested $rowCount). '
          'The series is computed on the UI thread.';
    }
    if (exceedsSoftCap) {
      return '$effectiveRowCount rows is above the $seriesSoftRowCap-row '
          'comfort limit — recompute may be visibly slow.';
    }
    return null;
  }

  /// UT of step [index], counting from 0.
  double utAt(int index) => stepUnit.advanceFrom(start.ut, stepValue, index);
}
