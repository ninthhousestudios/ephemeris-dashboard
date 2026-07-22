// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'moment.dart';

/// Step size unit for a time series.
///
/// Months are an approximation today (30.4375 days), so a monthly series
/// drifts off the calendar date. Calendar-aware months and years, plus the
/// seconds unit, are swe-dashboard/49.
enum StepUnit {
  minutes('Minutes', 1.0 / 1440.0),
  hours('Hours', 1.0 / 24.0),
  days('Days', 1.0),
  weeks('Weeks', 7.0),
  months('Months', 30.4375);

  const StepUnit(this.label, this.jdFactor);
  final String label;
  final double jdFactor;
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
  double utAt(int index) => start.ut + index * stepValue * stepUnit.jdFactor;
}
