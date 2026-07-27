// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/obliquity.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/calendar.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_utils_provider.dart';
import '../../core/swe_utils.dart';
import '../../layout/tab_definitions.dart';

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
    required this.trueObliquity,
    required this.meanObliquity,
    required this.nutationLongitude,
    required this.nutationObliquity,
    this.revjulError,
    this.deltaTError,
    this.siderealTimeError,
    this.equationOfTimeError,
    this.lmtToLatError,
    this.latToLmtError,
    this.eclNutError,
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

  /// True obliquity of the ecliptic in degrees (SE_ECL_NUT xx[0]).
  final double trueObliquity;

  /// Mean obliquity of the ecliptic in degrees (SE_ECL_NUT xx[1]).
  final double meanObliquity;

  /// Nutation in longitude in degrees (SE_ECL_NUT xx[2]).
  final double nutationLongitude;

  /// Nutation in obliquity in degrees (SE_ECL_NUT xx[3]).
  final double nutationObliquity;

  // Per-field errors (null = success)
  final String? revjulError;
  final String? deltaTError;
  final String? siderealTimeError;
  final String? equationOfTimeError;
  final String? lmtToLatError;
  final String? latToLmtError;
  final String? eclNutError;

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
  required int iflag,
  required Calendar calendar,
}) {
  int revYear = 0, revMonth = 0, revDay = 0;
  double revHour = 0;
  String? revjulError;
  try {
    // On the Context's calendar, not revjul's Gregorian default. One Moment
    // must not read as two different civil dates depending on which surface is
    // showing it — this card sits under a context bar rendering the same JD.
    final r = swe.revjul(jdUt, gregorian: calendar.isGregorianForJd(jdUt));
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

  // Obliquity & nutation come from the SE_ECL_NUT pseudo-body (swetest -p o/n).
  double trueObliquity = 0, meanObliquity = 0;
  double nutationLongitude = 0, nutationObliquity = 0;
  String? eclNutError;
  try {
    final r = computeObliquityNutation(eph, jdUt, iflag);
    trueObliquity = r.trueObliquity;
    meanObliquity = r.meanObliquity;
    nutationLongitude = r.nutationLongitude;
    nutationObliquity = r.nutationObliquity;
  } catch (e) {
    eclNutError = e.toString();
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
    trueObliquity: trueObliquity,
    meanObliquity: meanObliquity,
    nutationLongitude: nutationLongitude,
    nutationObliquity: nutationObliquity,
    revjulError: revjulError,
    deltaTError: deltaTError,
    siderealTimeError: siderealTimeError,
    equationOfTimeError: equationOfTimeError,
    lmtToLatError: lmtToLatError,
    latToLmtError: latToLmtError,
    eclNutError: eclNutError,
  );
}

DatesResult Function(Ephemeris, Moment) _datesCompute(
  Ref ref, {
  double? overrideJd,
}) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  return (eph, moment) => computeDates(
    eph,
    swe,
    jdUt: overrideJd ?? moment.ut,
    geolon: ctx.longitude,
    iflag: flags.iflag,
    calendar: ctx.calendar,
  );
}

final _datesCalcProvider = Provider<CalcOutcome<DatesResult>>((ref) {
  final overrideJd = ref.watch(datesOverrideJdProvider);
  return runTabCalc(ref, compute: _datesCompute(ref, overrideJd: overrideJd));
});

final datesResultProvider = Provider<CalcOutcome<DatesResult>>((ref) {
  return ref.watch(_datesCalcProvider);
});

final datesSeriesProvider = Provider<List<(Moment, CalcOutcome<DatesResult>)>>((
  ref,
) {
  ref.watch(
    seriesSettingsProvider(
      AppTab.dates.name,
    ).select((s) => (s.enabled, s.stepValue, s.stepUnit, s.rowCount)),
  );
  final settings = ref.read(seriesSettingsProvider(AppTab.dates.name));
  if (!settings.enabled) return const [];
  return runTabCalcSeries(ref, compute: _datesCompute(ref), settings: settings);
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
    ExportRow(
      header: 'Obliquity & Nutation',
      fields: [
        ('True Obliquity (°)', r.trueObliquity.toStringAsFixed(8)),
        ('Mean Obliquity (°)', r.meanObliquity.toStringAsFixed(8)),
        ('Nutation in Longitude (°)', r.nutationLongitude.toStringAsFixed(8)),
        ('Nutation in Obliquity (°)', r.nutationObliquity.toStringAsFixed(8)),
      ],
    ),
  ];
}
