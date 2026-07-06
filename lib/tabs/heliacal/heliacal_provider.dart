import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/trace_model.dart';
import '../../core/export_service.dart';
import '../../core/jd_utils.dart';

// ── Input providers ──────────────────────────────────────────────────────────

/// The star or planet name to search for (e.g. 'Venus', 'Sirius').
final heliacalStarProvider = StateProvider<String>((ref) => 'Venus');

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

/// Runs the kernel once per recompute; result + trace derive from this.
/// The compute lambda catches per-call failures and folds them into
/// `HeliacalCalcResult.error`, so the outcome is (almost) always `CalcOk`;
/// the kernel's `SweException` catch is only a backstop.
final _heliacalCalcProvider =
    Provider<({CalcOutcome<HeliacalCalcResult> outcome, CallTrace trace})>((
      ref,
    ) {
      final ctx = ref.watch(contextBarProvider);
      final objectName = ref.watch(heliacalStarProvider).trim();
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
      );
      final name = objectName.isEmpty ? 'Venus' : objectName;

      return runTabCalc(
        ref,
        tabTag: 'heliacal',
        compute: (eph) {
          try {
            final r = eph.heliacalUt(
              ctx.jdUt,
              geolon: ctx.longitude,
              geolat: ctx.latitude,
              geoalt: ctx.altitude,
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
        },
      );
    });

/// Heliacal calculation result.
final heliacalResultProvider = Provider<CalcOutcome<HeliacalCalcResult>>(
  (ref) => ref.watch(_heliacalCalcProvider.select((c) => c.outcome)),
);

/// Call Trace produced by the most recent heliacal calculation.
final heliacalTraceProvider = Provider<CallTrace>(
  (ref) => ref.watch(_heliacalCalcProvider.select((c) => c.trace)),
);

// ── Export ───────────────────────────────────────────────────────────────────

List<ExportRow> heliacalToExportRows(HeliacalCalcResult r, SwissEph swe) {
  if (r.hasError) {
    return [
      ExportRow(
        header:
            '${r.objectName} — ${HeliacalCalcResult.eventLabel(r.eventType)}',
        fields: [('Error', r.error!)],
      ),
    ];
  }

  String jdToDateStr(double jd) => formatJdDateTime(
    swe,
    jd,
    seconds: false,
    utLabel: false,
    fallbackDigits: 4,
  );

  return [
    ExportRow(
      header: '${r.objectName} — ${HeliacalCalcResult.eventLabel(r.eventType)}',
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
}
