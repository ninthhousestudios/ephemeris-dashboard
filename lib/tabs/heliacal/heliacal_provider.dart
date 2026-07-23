// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_utils.dart';

// ── Input providers ──────────────────────────────────────────────────────────

/// Selected bodies/stars for heliacal calculation.
final heliacalTargetsProvider = StateProvider<List<String>>(
  (ref) => const ['Venus'],
);

/// Heliacal event type:
/// 1 = seHeliacalRising, 2 = seHeliacalSetting,
/// 3 = seEveningFirst,   4 = seMorningLast
final heliacalEventTypeProvider = StateProvider<int>((ref) => seHeliacalRising);

// ── Atmospheric condition providers ──────────────────────────────────────────

final heliacalPressureProvider = StateProvider<double>((ref) => 1013.25);

final heliacalTemperatureProvider = StateProvider<double>((ref) => 25.0);

final heliacalHumidityProvider = StateProvider<double>((ref) => 50.0);

/// Atmospheric extinction coefficient (typically 0.2 for clear sky).
final heliacalExtinctionProvider = StateProvider<double>((ref) => 0.2);

// ── Observer condition providers ─────────────────────────────────────────────

final heliacalObserverAgeProvider = StateProvider<double>((ref) => 36.0);

final heliacalSnellenRatioProvider = StateProvider<double>((ref) => 1.0);

// ── Optical-instrument providers (swetest -opt) ───────────────────────────────
// dobs[2..5]: 0=monocular/1=binocular, magnification, aperture (mm), transmission.
// Defaults are the naked-eye values, so results are unchanged unless edited.

/// 0 = monocular, 1 = binocular. Naked-eye default is binocular (both eyes).
final heliacalMonoNoBinoProvider = StateProvider<double>((ref) => 1.0);

/// Telescope magnification (0 = naked eye).
final heliacalMagnificationProvider = StateProvider<double>((ref) => 0.0);

/// Optical aperture in mm (0 = naked eye).
final heliacalApertureProvider = StateProvider<double>((ref) => 0.0);

/// Optical transmission (0 = naked eye).
final heliacalTransmissionProvider = StateProvider<double>((ref) => 0.0);

// ── Result class ─────────────────────────────────────────────────────────────

class HeliacalCalcResult {
  const HeliacalCalcResult({
    required this.objectName,
    required this.eventType,
    required this.startVisibleJd,
    required this.bestVisibleJd,
    required this.endVisibleJd,
    this.error,
  });

  final String objectName;
  final int eventType;
  final double startVisibleJd;
  final double bestVisibleJd;
  final double endVisibleJd;
  final String? error;

  bool get hasError => error != null;

  /// Human-readable event label.
  static String eventLabel(int typeEvent) {
    switch (typeEvent) {
      case seHeliacalRising:
        return 'Heliacal Rising';
      case seHeliacalSetting:
        return 'Heliacal Setting';
      case seEveningFirst:
        return 'Evening First';
      case seMorningLast:
        return 'Morning Last';
      default:
        return 'Event $typeEvent';
    }
  }
}

// ── Result provider ──────────────────────────────────────────────────────────

HeliacalCalcResult _computeOne(
  Ephemeris eph,
  double jdUt,
  double geolon,
  double geolat,
  double geoalt,
  AtmoConditions atmo,
  ObserverConditions observer,
  String name,
  int typeEvent,
) {
  try {
    final r = eph.heliacalUt(
      jdUt,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atmo: atmo,
      observer: observer,
      objectName: name,
      typeEvent: typeEvent,
    );
    return HeliacalCalcResult(
      objectName: name,
      eventType: typeEvent,
      startVisibleJd: r.startVisible,
      bestVisibleJd: r.bestVisible,
      endVisibleJd: r.endVisible,
    );
  } on SweException catch (e) {
    return HeliacalCalcResult(
      objectName: name,
      eventType: typeEvent,
      startVisibleJd: double.nan,
      bestVisibleJd: double.nan,
      endVisibleJd: double.nan,
      error: e.message,
    );
  } catch (e) {
    return HeliacalCalcResult(
      objectName: name,
      eventType: typeEvent,
      startVisibleJd: double.nan,
      bestVisibleJd: double.nan,
      endVisibleJd: double.nan,
      error: e.toString(),
    );
  }
}

/// Runs the kernel once per recompute; iterates over all selected targets.
final _heliacalCalcProvider = Provider<CalcOutcome<List<HeliacalCalcResult>>>((
  ref,
) {
  final ctx = ref.watch(contextBarProvider);
  final targets = ref.watch(heliacalTargetsProvider);
  final typeEvent = ref.watch(heliacalEventTypeProvider);

  final atmo = AtmoConditions(
    pressure: ref.watch(heliacalPressureProvider),
    temperature: ref.watch(heliacalTemperatureProvider),
    humidity: ref.watch(heliacalHumidityProvider),
    extinction: ref.watch(heliacalExtinctionProvider),
  );
  final observer = ObserverConditions(
    age: ref.watch(heliacalObserverAgeProvider),
    snellenRatio: ref.watch(heliacalSnellenRatioProvider),
    monoNoBino: ref.watch(heliacalMonoNoBinoProvider),
    telescopeMag: ref.watch(heliacalMagnificationProvider),
    telescopeDia: ref.watch(heliacalApertureProvider),
    transmission: ref.watch(heliacalTransmissionProvider),
  );

  return runTabCalc(
    ref,
    compute: (eph, moment) => targets
        .map(
          (name) => _computeOne(
            eph,
            moment.ut,
            ctx.longitude,
            ctx.latitude,
            ctx.altitude,
            atmo,
            observer,
            name,
            typeEvent,
          ),
        )
        .toList(),
  );
});

/// Heliacal calculation results (one per target).
final heliacalResultProvider = Provider<CalcOutcome<List<HeliacalCalcResult>>>(
  (ref) => ref.watch(_heliacalCalcProvider),
);

// ── Export ───────────────────────────────────────────────────────────────────

List<ExportRow> heliacalToExportRows(
  List<HeliacalCalcResult> results,
  SweUtils swe,
) {
  String jdToDateStr(double jd) => formatJdDateTime(
    swe,
    jd,
    seconds: false,
    utLabel: false,
    fallbackDigits: 4,
  );

  return results.expand((r) {
    if (r.hasError) {
      return [
        ExportRow(
          header:
              '${r.objectName} — ${HeliacalCalcResult.eventLabel(r.eventType)}',
          fields: [('Error', r.error!)],
        ),
      ];
    }
    return [
      ExportRow(
        header:
            '${r.objectName} — ${HeliacalCalcResult.eventLabel(r.eventType)}',
        fields: [
          ('Start Visible', jdToDateStr(r.startVisibleJd)),
          ('Start Visible (JD)', r.startVisibleJd.toStringAsFixed(6)),
          ('Best Visible', jdToDateStr(r.bestVisibleJd)),
          ('Best Visible (JD)', r.bestVisibleJd.toStringAsFixed(6)),
          ('End Visible', jdToDateStr(r.endVisibleJd)),
          ('End Visible (JD)', r.endVisibleJd.toStringAsFixed(6)),
        ],
      ),
    ];
  }).toList();
}
