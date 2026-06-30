import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/export_service.dart';
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

/// Rise/set/transit result provider.
final riseSetResultProvider = Provider<RiseSetResult?>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('riseSet')) return null;

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final swe = ref.read(sweProvider);
  runner.setTabTag('riseSet');
  final body = ref.watch(riseSetBodyProvider);
  final atpress = ref.watch(riseSetAtpressProvider);
  final attemp = ref.watch(riseSetAttempProvider);
  final modifiers = ref.watch(riseSetModifiersProvider);

  final jdUt = ectx.jdUt;
  final geolon = ectx.longitude;
  final geolat = ectx.latitude;
  final geoalt = ectx.altitude;
  // riseTrans uses the basic ephe flag (no speed, no extras needed).
  final epheflag = ectx.iflag & 0xF; // low bits: ephe source

  double? riseJd;
  RiseSetDateTime? riseDateTime;
  int? riseFlag;
  String? riseError;

  double? setJd;
  RiseSetDateTime? setDateTime;
  int? setFlag;
  String? setError;

  double? upperTransitJd;
  RiseSetDateTime? upperTransitDateTime;
  int? upperTransitFlag;
  String? upperTransitError;

  double? lowerTransitJd;
  RiseSetDateTime? lowerTransitDateTime;
  int? lowerTransitFlag;
  String? lowerTransitError;

  // Rise
  try {
    final r = runner.run(
      globals,
      (eph) => eph.riseTrans(
        jdUt,
        body,
        epheflag: epheflag,
        rsmi: rsCalcRise | modifiers,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
      ),
    );
    riseJd = r.transitTime;
    riseFlag = r.returnFlag;
    riseDateTime = _toDateTime(swe, r.transitTime);
  } catch (e) {
    riseError = e.toString();
  }

  // Set
  try {
    final r = runner.run(
      globals,
      (eph) => eph.riseTrans(
        jdUt,
        body,
        epheflag: epheflag,
        rsmi: rsCalcSet | modifiers,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
      ),
    );
    setJd = r.transitTime;
    setFlag = r.returnFlag;
    setDateTime = _toDateTime(swe, r.transitTime);
  } catch (e) {
    setError = e.toString();
  }

  // Upper meridian transit
  try {
    final r = runner.run(
      globals,
      (eph) => eph.riseTrans(
        jdUt,
        body,
        epheflag: epheflag,
        rsmi: rsCalcMtransit | modifiers,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
      ),
    );
    upperTransitJd = r.transitTime;
    upperTransitFlag = r.returnFlag;
    upperTransitDateTime = _toDateTime(swe, r.transitTime);
  } catch (e) {
    upperTransitError = e.toString();
  }

  // Lower meridian transit
  try {
    final r = runner.run(
      globals,
      (eph) => eph.riseTrans(
        jdUt,
        body,
        epheflag: epheflag,
        rsmi: rsCalcItransit | modifiers,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
      ),
    );
    lowerTransitJd = r.transitTime;
    lowerTransitFlag = r.returnFlag;
    lowerTransitDateTime = _toDateTime(swe, r.transitTime);
  } catch (e) {
    lowerTransitError = e.toString();
  }

  return RiseSetResult(
    riseJd: riseJd,
    riseDateTime: riseDateTime,
    riseFlag: riseFlag,
    setJd: setJd,
    setDateTime: setDateTime,
    setFlag: setFlag,
    upperTransitJd: upperTransitJd,
    upperTransitDateTime: upperTransitDateTime,
    upperTransitFlag: upperTransitFlag,
    lowerTransitJd: lowerTransitJd,
    lowerTransitDateTime: lowerTransitDateTime,
    lowerTransitFlag: lowerTransitFlag,
    riseError: riseError,
    setError: setError,
    upperTransitError: upperTransitError,
    lowerTransitError: lowerTransitError,
  );
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
