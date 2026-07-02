import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/ephemeris/runner.dart';
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

final heliacalResultProvider = Provider<HeliacalCalcResult?>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('heliacal')) return null;

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  runner.setTabTag('heliacal');

  final objectName = ref.watch(heliacalStarProvider).trim();
  final typeEvent = ref.watch(heliacalEventTypeProvider);

  final pressure = ref.watch(heliacalPressureProvider);
  final temperature = ref.watch(heliacalTemperatureProvider);
  final humidity = ref.watch(heliacalHumidityProvider);
  final extinction = ref.watch(heliacalExtinctionProvider);

  final age = ref.watch(heliacalObserverAgeProvider);
  final snellen = ref.watch(heliacalSnellenRatioProvider);

  final atmo = AtmoConditions(
    pressure: pressure,
    temperature: temperature,
    humidity: humidity,
    extinction: extinction,
  );
  final observer = ObserverConditions(age: age, snellenRatio: snellen);

  try {
    final result = runner.run(
      globals,
      (eph) => eph.heliacalUt(
        ectx.jdUt,
        geolon: ectx.longitude,
        geolat: ectx.latitude,
        geoalt: ectx.altitude,
        atmo: atmo,
        observer: observer,
        objectName: objectName.isEmpty ? 'Venus' : objectName,
        typeEvent: typeEvent,
      ),
    );
    return HeliacalCalcResult(
      objectName: objectName.isEmpty ? 'Venus' : objectName,
      eventType: typeEvent,
      startVisibleJd: result.startVisible,
      bestVisibleJd: result.bestVisible,
      endVisibleJd: result.endVisible,
    );
  } on SweException catch (e) {
    return HeliacalCalcResult(
      objectName: objectName,
      eventType: typeEvent,
      startVisibleJd: double.nan,
      bestVisibleJd: double.nan,
      endVisibleJd: double.nan,
      error: e.message,
    );
  } catch (e) {
    return HeliacalCalcResult(
      objectName: objectName,
      eventType: typeEvent,
      startVisibleJd: double.nan,
      bestVisibleJd: double.nan,
      endVisibleJd: double.nan,
      error: e.toString(),
    );
  }
});

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
