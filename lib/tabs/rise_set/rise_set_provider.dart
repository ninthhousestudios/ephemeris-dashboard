import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/ephemeris/trace_model.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_service.dart';

// ── rsmi type flags ───────────────────────────────────────────────────────────

const int rsCalcRise = 1;
const int rsCalcSet = 2;
const int rsCalcMtransit = 4;
const int rsCalcItransit = 8;

// ── rsmi modifier bits ────────────────────────────────────────────────────────

const int rsBitDiscCenter = 256;
const int rsBitDiscBottom = 512;
const int rsBitNoRefraction = 1024;
const int rsBitCivilTwilight = 2048;
const int rsBitNauticTwilight = 4096;
const int rsBitAstroTwilight = 8192;
const int rsBitFixedDiscSize = 16384;
const int rsBitHinduRising = 32768;

// ── State providers ───────────────────────────────────────────────────────────

/// Selected body for rise/set calculation.
final riseSetBodyProvider = StateProvider<int>((ref) => seSun);

/// Atmospheric pressure (hPa).
final riseSetAtpressProvider = StateProvider<double>((ref) => 1013.25);

/// Atmospheric temperature (°C).
final riseSetAttempProvider = StateProvider<double>((ref) => 15.0);

/// Bitmask of active modifier flags (rsm* constants above, OR'd together).
/// Does NOT include the event-type bits (rise/set/transit) — those are fixed.
final riseSetModifiersProvider = StateProvider<int>((ref) => 0);

// ── Result model ──────────────────────────────────────────────────────────────

/// Readable date/time broken out from a JD by revjul().
class RiseSetDateTime {
  const RiseSetDateTime({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
  });

  final int year;
  final int month;
  final int day;
  final double hour;

  String formatted() {
    final h = hour.floor();
    final mFrac = (hour - h) * 60;
    final m = mFrac.floor();
    final s = ((mFrac - m) * 60).round();
    return '$year-${_pad(month)}-${_pad(day)} ${_pad(h)}:${_pad(m)}:${_pad(s)} UT';
  }

  /// Format with local time appended, given a UTC offset in hours.
  String formattedWithLocal(double utcOffset) {
    final utStr = formatted();
    if (utcOffset == 0.0) return utStr;
    final utcDt = DateTime.utc(
      year,
      month,
      day,
      hour.floor(),
      ((hour - hour.floor()) * 60).floor(),
      (((hour - hour.floor()) * 60 - ((hour - hour.floor()) * 60).floor()) * 60)
          .round(),
    );
    final totalMinutes = (utcOffset * 60).round();
    final local = utcDt.add(Duration(minutes: totalMinutes));
    final sign = utcOffset >= 0 ? '+' : '';
    final offsetStr = utcOffset == utcOffset.roundToDouble()
        ? '$sign${utcOffset.round()}'
        : '$sign${utcOffset.toStringAsFixed(1)}';
    return '$utStr  (${_pad(local.hour)}:${_pad(local.minute)}:${_pad(local.second)} UTC$offsetStr)';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

/// Rise/set/transit results for one body.
class RiseSetResult {
  const RiseSetResult({
    this.riseJd,
    this.riseDateTime,
    this.riseFlag,
    this.setJd,
    this.setDateTime,
    this.setFlag,
    this.upperTransitJd,
    this.upperTransitDateTime,
    this.upperTransitFlag,
    this.lowerTransitJd,
    this.lowerTransitDateTime,
    this.lowerTransitFlag,
    this.riseError,
    this.setError,
    this.upperTransitError,
    this.lowerTransitError,
  });

  final double? riseJd;
  final RiseSetDateTime? riseDateTime;
  final int? riseFlag;

  final double? setJd;
  final RiseSetDateTime? setDateTime;
  final int? setFlag;

  final double? upperTransitJd;
  final RiseSetDateTime? upperTransitDateTime;
  final int? upperTransitFlag;

  final double? lowerTransitJd;
  final RiseSetDateTime? lowerTransitDateTime;
  final int? lowerTransitFlag;

  final String? riseError;
  final String? setError;
  final String? upperTransitError;
  final String? lowerTransitError;
}

// ── Computation ───────────────────────────────────────────────────────────────

RiseSetDateTime? _toDateTime(SwissEph swe, double jd) {
  try {
    final r = swe.revjul(jd);
    return RiseSetDateTime(
      year: r.year,
      month: r.month,
      day: r.day,
      hour: r.hour,
    );
  } catch (_) {
    return null;
  }
}

/// One rise/set/transit event: a single `riseTrans` call wrapped so a
/// per-event `SweException` becomes an error string instead of failing the
/// batch. Returns (jd, returnFlag, dateTime) on success; (error) otherwise.
({double? jd, int? flag, RiseSetDateTime? dt, String? error}) _event(
  Ephemeris eph,
  SwissEph swe, {
  required double jdUt,
  required int body,
  required int rsmi,
  required int epheflag,
  required double geolon,
  required double geolat,
  required double geoalt,
  required double atpress,
  required double attemp,
}) {
  try {
    final r = eph.riseTrans(
      jdUt,
      body,
      epheflag: epheflag,
      rsmi: rsmi,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atpress: atpress,
      attemp: attemp,
    );
    return (
      jd: r.transitTime,
      flag: r.returnFlag,
      dt: _toDateTime(swe, r.transitTime),
      error: null,
    );
  } catch (e) {
    return (jd: null, flag: null, dt: null, error: e.toString());
  }
}

final _riseSetCalcProvider =
    Provider<({CalcOutcome<RiseSetResult> outcome, CallTrace trace})>((ref) {
      final ctx = ref.watch(contextBarProvider);
      final flags = ref.watch(flagBarProvider);
      final swe = ref.read(sweProvider);
      final body = ref.watch(riseSetBodyProvider);
      final atpress = ref.watch(riseSetAtpressProvider);
      final attemp = ref.watch(riseSetAttempProvider);
      final modifiers = ref.watch(riseSetModifiersProvider);

      final jdUt = ctx.jdUt;
      final geolon = ctx.longitude;
      final geolat = ctx.latitude;
      final geoalt = ctx.altitude;
      // riseTrans uses the basic ephe flag (no speed, no extras needed).
      final epheflag = flags.iflag & 0xF; // low bits: ephe source

      return runTabCalc(
        ref,
        tabTag: 'riseSet',
        compute: (eph) {
          ({double? jd, int? flag, RiseSetDateTime? dt, String? error}) run(
            int rsmi,
          ) => _event(
            eph,
            swe,
            jdUt: jdUt,
            body: body,
            rsmi: rsmi | modifiers,
            epheflag: epheflag,
            geolon: geolon,
            geolat: geolat,
            geoalt: geoalt,
            atpress: atpress,
            attemp: attemp,
          );

          final rise = run(rsCalcRise);
          final set = run(rsCalcSet);
          final upper = run(rsCalcMtransit);
          final lower = run(rsCalcItransit);

          return RiseSetResult(
            riseJd: rise.jd,
            riseDateTime: rise.dt,
            riseFlag: rise.flag,
            riseError: rise.error,
            setJd: set.jd,
            setDateTime: set.dt,
            setFlag: set.flag,
            setError: set.error,
            upperTransitJd: upper.jd,
            upperTransitDateTime: upper.dt,
            upperTransitFlag: upper.flag,
            upperTransitError: upper.error,
            lowerTransitJd: lower.jd,
            lowerTransitDateTime: lower.dt,
            lowerTransitFlag: lower.flag,
            lowerTransitError: lower.error,
          );
        },
      );
    });

/// Rise/set/transit result provider.
final riseSetResultProvider = Provider<CalcOutcome<RiseSetResult>>((ref) {
  return ref.watch(_riseSetCalcProvider.select((c) => c.outcome));
});

/// Call Trace produced by the most recent rise/set calculation.
final riseSetTraceProvider = Provider<CallTrace>((ref) {
  return ref.watch(_riseSetCalcProvider.select((c) => c.trace));
});

// ── Export ────────────────────────────────────────────────────────────────────

String _jdStr(double? jd) => jd != null ? jd.toStringAsFixed(8) : '—';

String _dtStr(RiseSetDateTime? dt) => dt?.formatted() ?? '—';

List<ExportRow> riseSetToExportRows(RiseSetResult result) {
  return [
    ExportRow(
      header: 'Rise',
      fields: [
        ('JD', _jdStr(result.riseJd)),
        ('Date/Time', _dtStr(result.riseDateTime)),
        if (result.riseError != null) ('Error', result.riseError!),
      ],
    ),
    ExportRow(
      header: 'Set',
      fields: [
        ('JD', _jdStr(result.setJd)),
        ('Date/Time', _dtStr(result.setDateTime)),
        if (result.setError != null) ('Error', result.setError!),
      ],
    ),
    ExportRow(
      header: 'Upper Transit',
      fields: [
        ('JD', _jdStr(result.upperTransitJd)),
        ('Date/Time', _dtStr(result.upperTransitDateTime)),
        if (result.upperTransitError != null)
          ('Error', result.upperTransitError!),
      ],
    ),
    ExportRow(
      header: 'Lower Transit',
      fields: [
        ('JD', _jdStr(result.lowerTransitJd)),
        ('Date/Time', _dtStr(result.lowerTransitDateTime)),
        if (result.lowerTransitError != null)
          ('Error', result.lowerTransitError!),
      ],
    ),
  ];
}
