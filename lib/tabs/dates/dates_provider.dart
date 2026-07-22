// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/swe_service.dart';
import '../../core/swe_utils.dart';

/// Optional override JD — when non-null, use this instead of the context bar JD.
final datesOverrideJdProvider = StateProvider<double?>((ref) => null);

// ── Result ───────────────────────────────────────────────────────────────────

/// All date/time conversion results for the current context JD.
class DatesResult {
  const DatesResult({
    required this.jdUt,
    required this.revjulYear,
    required this.revjulMonth,
    required this.revjulDay,
    required this.revjulHour,
    required this.dayOfWeekIndex,
    required this.deltaT,
    required this.siderealTime,
    required this.equationOfTime,
    required this.lmtToLat,
    required this.latToLmt,
    this.revjulError,
    this.deltaTError,
    this.siderealTimeError,
    this.equationOfTimeError,
    this.lmtToLatError,
    this.latToLmtError,
  });

  final double jdUt;

  // Calendar (from revjul)
  final int revjulYear;
  final int revjulMonth;
  final int revjulDay;
  final double revjulHour;

  /// Day of week from swe.dayOfWeek: 0=Mon, 1=Tue, ..., 6=Sun.
  final int dayOfWeekIndex;

  /// Delta-T in seconds (swe.deltat returns days, we multiply by 86400).
  final double deltaT;

  /// Greenwich Mean Sidereal Time in hours (from swe.sidTime).
  final double siderealTime;

  /// Equation of time in days (from swe.timeEqu). Display as minutes.
  final double equationOfTime;

  /// LMT→LAT: JD result from swe.lmtToLat.
  final double lmtToLat;

  /// LAT→LMT: JD result from swe.latToLmt.
  final double latToLmt;

  // Per-field errors (null = success)
  final String? revjulError;
  final String? deltaTError;
  final String? siderealTimeError;
  final String? equationOfTimeError;
  final String? lmtToLatError;
  final String? latToLmtError;

  /// JD ET = JD UT + deltaT (in days).
  double get jdEt => jdUt + deltaT / 86400.0;

  /// Day of week name.
  String get dayOfWeekName {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    if (dayOfWeekIndex < 0 || dayOfWeekIndex > 6) return '?';
    return names[dayOfWeekIndex];
  }

  /// Equation of time in minutes (raw value is in days).
  double get equationOfTimeMinutes => equationOfTime * 1440.0;

  /// The hour component split into hours, minutes, seconds.
  ({int h, int m, double s}) get revjulTime {
    final hr = revjulHour.abs();
    final hours = hr.truncate();
    final mf = (hr - hours) * 60;
    final mins = mf.truncate();
    final secs = (mf - mins) * 60;
    return (h: hours, m: mins, s: secs);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

/// Pure compute step: all date/time conversions for one JD. `revjul` and
/// `dayOfWeek` are untraced calendar utilities (called on [swe]); the rest go
/// through the traced [eph]. Every call is wrapped so a per-field failure
/// becomes an error string in the result rather than aborting the batch.
DatesResult computeDates(
  Ephemeris eph,
  SweUtils swe, {
  required double jdUt,
  required double geolon,
}) {
  int revYear = 0, revMonth = 0, revDay = 0;
  double revHour = 0;
  String? revjulError;
  try {
    final r = swe.revjul(jdUt);
    revYear = r.year;
    revMonth = r.month;
    revDay = r.day;
    revHour = r.hour;
  } on SweException catch (e) {
    revjulError = e.message;
  } catch (e) {
    revjulError = e.toString();
  }

  int dayOfWeekIndex = 0;
  try {
    dayOfWeekIndex = swe.dayOfWeek(jdUt);
  } catch (_) {}

  double deltaT = 0;
  String? deltaTError;
  try {
    deltaT = eph.deltat(jdUt) * 86400.0;
  } catch (e) {
    deltaTError = e.toString();
  }

  double siderealTime = 0;
  String? siderealTimeError;
  try {
    siderealTime = eph.sidTime(jdUt);
  } catch (e) {
    siderealTimeError = e.toString();
  }

  double equationOfTime = 0;
  String? equationOfTimeError;
  try {
    equationOfTime = eph.timeEqu(jdUt);
  } catch (e) {
    equationOfTimeError = e.toString();
  }

  double lmtToLatVal = 0;
  String? lmtToLatError;
  double latToLmtVal = 0;
  String? latToLmtError;
  try {
    lmtToLatVal = eph.lmtToLat(jdUt, geolon);
  } catch (e) {
    lmtToLatError = e.toString();
  }
  try {
    latToLmtVal = eph.latToLmt(jdUt, geolon);
  } catch (e) {
    latToLmtError = e.toString();
  }

  return DatesResult(
    jdUt: jdUt,
    revjulYear: revYear,
    revjulMonth: revMonth,
    revjulDay: revDay,
    revjulHour: revHour,
    dayOfWeekIndex: dayOfWeekIndex,
    deltaT: deltaT,
    siderealTime: siderealTime,
    equationOfTime: equationOfTime,
    lmtToLat: lmtToLatVal,
    latToLmt: latToLmtVal,
    revjulError: revjulError,
    deltaTError: deltaTError,
    siderealTimeError: siderealTimeError,
    equationOfTimeError: equationOfTimeError,
    lmtToLatError: lmtToLatError,
    latToLmtError: latToLmtError,
  );
}

/// Computes all date/time conversions using swisseph native functions.
/// Reactive to the context JD, a per-tab override JD, and longitude.
final _datesCalcProvider = Provider<CalcOutcome<DatesResult>>((ref) {
  final ctx = ref.watch(contextBarProvider);
  final swe = ref.read(sweProvider);
  final overrideJd = ref.watch(datesOverrideJdProvider);
  final geolon = ctx.longitude;

  return runTabCalc(
    ref,
    compute: (eph, moment) =>
        computeDates(eph, swe, jdUt: overrideJd ?? moment.ut, geolon: geolon),
  );
});

/// Date/time conversion results.
final datesResultProvider = Provider<CalcOutcome<DatesResult>>((ref) {
  return ref.watch(_datesCalcProvider);
});

// ── Export ───────────────────────────────────────────────────────────────────

/// Convert a DatesResult to exportable rows, one per card section.
List<ExportRow> datesToExportRows(DatesResult r) {
  final t = r.revjulTime;
  final timeStr =
      '${t.h.toString().padLeft(2, '0')}:'
      '${t.m.toString().padLeft(2, '0')}:'
      '${t.s.toStringAsFixed(2).padLeft(5, '0')}';

  return [
    ExportRow(
      header: 'Calendar',
      fields: [
        ('Year', r.revjulYear.toString()),
        ('Month', r.revjulMonth.toString()),
        ('Day', r.revjulDay.toString()),
        ('Time (UT)', timeStr),
        ('Day of Week', r.dayOfWeekName),
      ],
    ),
    ExportRow(
      header: 'Julian Day',
      fields: [
        ('JD UT', r.jdUt.toStringAsFixed(8)),
        ('JD ET', r.jdEt.toStringAsFixed(8)),
      ],
    ),
    ExportRow(
      header: 'Time',
      fields: [
        ('Delta-T (s)', r.deltaT.toStringAsFixed(3)),
        ('Sidereal Time (h)', r.siderealTime.toStringAsFixed(8)),
        ('Equation of Time (min)', r.equationOfTimeMinutes.toStringAsFixed(4)),
      ],
    ),
    ExportRow(
      header: 'Local Time',
      fields: [
        ('LMT→LAT (JD)', r.lmtToLat.toStringAsFixed(8)),
        ('LAT→LMT (JD)', r.latToLmt.toStringAsFixed(8)),
      ],
    ),
  ];
}
