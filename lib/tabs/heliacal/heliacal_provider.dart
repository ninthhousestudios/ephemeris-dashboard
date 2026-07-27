// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/flag_masks.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/flag_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/jd_utils.dart';
import '../../core/output_clock.dart';
import '../../core/swe_utils.dart';
import '../../widgets/result_card.dart';
import '../../widgets/result_section.dart';

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

/// Pure compute step: one heliacal search per selected target, capturing a
/// failing target's error as its own `error` instead of losing the batch.
///
/// [epheflag] is the Context's Ephemeris Source, reduced to the bare source
/// bits `swe_heliacal_ut` accepts — passing 0 would silently compute on Swiss
/// files whatever the Context asked for.
List<HeliacalCalcResult> computeHeliacal({
  required Ephemeris eph,
  required double jdUt,
  required List<String> targets,
  required int typeEvent,
  required double geolon,
  required double geolat,
  required double geoalt,
  required AtmoConditions atmo,
  required ObserverConditions observer,
  required int epheflag,
}) => targets
    .map(
      (name) => _computeOne(
        eph,
        jdUt,
        geolon,
        geolat,
        geoalt,
        atmo,
        observer,
        name,
        typeEvent,
        epheflag,
      ),
    )
    .toList();

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
  int epheflag,
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
      flags: epheflag,
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
  // swe_heliacal_ut takes a bare ephemeris flag; with none set it defaults to
  // Swiss files whatever the Context asked for. Watched, so switching the
  // Ephemeris Source recomputes this tab like it does its siblings.
  final epheflag = epheSourceFlag(ref.watch(flagBarProvider).iflag);

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
    compute: (eph, moment) => computeHeliacal(
      eph: eph,
      jdUt: moment.ut,
      targets: targets,
      typeEvent: typeEvent,
      geolon: ctx.longitude,
      geolat: ctx.latitude,
      geoalt: ctx.altitude,
      atmo: atmo,
      observer: observer,
      epheflag: epheflag,
    ),
  );
});

/// Heliacal calculation results (one per target).
final heliacalResultProvider = Provider<CalcOutcome<List<HeliacalCalcResult>>>(
  (ref) => ref.watch(_heliacalCalcProvider),
);

// ── Card sections (the single label/value source) ───────────────────────────

/// The civil-date render for one heliacal event JD, on the selected [view].
///
/// The single renderer for both the on-screen card and the export, so the two
/// cannot drift apart again (swe-dashboard/91). Previously the export path
/// rendered on a hard-coded neutral UT view regardless of the Context's
/// Scale/Calendar/companion-clock choice, so an export silently disagreed with
/// what was on screen under a non-default view (compare swe-dashboard/82).
String _fmtHeliacalJd(SweUtils swe, double jd, ClockView view) =>
    formatJdDateTime(
      swe,
      jd,
      seconds: false,
      view: view,
      emptyPlaceholder: '—',
      fallbackDigits: 4,
    );

/// One [HeliacalCalcResult] as card sections — the one encoding of this tab's
/// labels and formatters. The cards render these; [heliacalToExportRows]
/// projects the same list. The object name is folded into each section title
/// (not just shown as an outer heading, as the card layout alone would invite)
/// because a [ResultSection.title] doubles as the export row header, and a
/// batch of several targets needs that header to disambiguate rows.
List<ResultSection> heliacalSections(
  HeliacalCalcResult r,
  SweUtils swe,
  ClockView view,
) {
  final eventLabel = HeliacalCalcResult.eventLabel(r.eventType);
  if (r.hasError) {
    return [
      ResultSection(
        title: '${r.objectName} — $eventLabel',
        fields: [
          ResultField(label: 'Error', value: r.error!, rawValue: double.nan),
        ],
      ),
    ];
  }

  String fmt(double jd) => _fmtHeliacalJd(swe, jd, view);

  // The Julian Day card shows the same instants as the card above it, so it
  // moves onto the Context's Scale with them — a JD sitting on UT1 beside a
  // date-time rendered in TT is two answers to one question. The label names
  // the scale rather than leaving the number to be read as whatever the bar
  // happens to say; see `jdScaleLabel` for why UTC reads as UT1.
  final jdUtils = JdUtils(swe);
  final jdLabel = jdScaleLabel(view.scale);
  double onScale(double jd) => jdUtils.jdOnScale(jd, view.scale);

  return [
    ResultSection(
      title: '${r.objectName} — $eventLabel',
      subtitle: 'heliacalUt("${r.objectName}")',
      fields: [
        ResultField(
          label: 'Start Visible',
          value: fmt(r.startVisibleJd),
          rawValue: r.startVisibleJd,
        ),
        ResultField(
          label: 'Best Visible',
          value: fmt(r.bestVisibleJd),
          rawValue: r.bestVisibleJd,
        ),
        ResultField(
          label: 'End Visible',
          value: fmt(r.endVisibleJd),
          rawValue: r.endVisibleJd,
        ),
      ],
    ),
    ResultSection(
      title: '${r.objectName} — Julian Days',
      subtitle: eventLabel,
      fields: [
        ResultField(
          label: 'Start Visible (JD $jdLabel)',
          value: onScale(r.startVisibleJd).toStringAsFixed(6),
          rawValue: onScale(r.startVisibleJd),
        ),
        ResultField(
          label: 'Best Visible (JD $jdLabel)',
          value: onScale(r.bestVisibleJd).toStringAsFixed(6),
          rawValue: onScale(r.bestVisibleJd),
        ),
        ResultField(
          label: 'End Visible (JD $jdLabel)',
          value: onScale(r.endVisibleJd).toStringAsFixed(6),
          rawValue: onScale(r.endVisibleJd),
        ),
      ],
    ),
  ];
}

// ── Export ───────────────────────────────────────────────────────────────────

List<ExportRow> heliacalToExportRows(
  List<HeliacalCalcResult> results,
  SweUtils swe,
  ClockView view,
) => sectionsToExportRows([
  for (final r in results) ...heliacalSections(r, swe, view),
]);
