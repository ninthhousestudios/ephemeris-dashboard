// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_service.dart';
import '../../core/swe_utils.dart';

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

/// One rise/set/transit target: a body or a fixed star.
class RiseSetTarget {
  const RiseSetTarget.body(this.bodyId) : starName = null;
  const RiseSetTarget.star(this.starName) : bodyId = seSun;

  final int bodyId;
  final String? starName;

  bool get isStar => starName != null;

  String get label => isStar ? starName! : _bodyName(bodyId);

  @override
  bool operator ==(Object other) =>
      other is RiseSetTarget &&
      other.bodyId == bodyId &&
      other.starName == starName;

  @override
  int get hashCode => Object.hash(bodyId, starName);
}

const Map<int, String> _bodyNames = {
  seSun: 'Sun',
  seMoon: 'Moon',
  seMercury: 'Mercury',
  seVenus: 'Venus',
  seMars: 'Mars',
  seJupiter: 'Jupiter',
  seSaturn: 'Saturn',
  seUranus: 'Uranus',
  seNeptune: 'Neptune',
  sePluto: 'Pluto',
};

String _bodyName(int bodyId) => _bodyNames[bodyId] ?? 'Body $bodyId';

/// Active rise/set targets (bodies and/or stars), each computed and shown as
/// its own result group.
final riseSetTargetsProvider = StateProvider<List<RiseSetTarget>>(
  (ref) => [const RiseSetTarget.body(seSun)],
);

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

RiseSetDateTime? _toDateTime(SweUtils swe, double jd) {
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
  SweUtils swe, {
  required double jdUt,
  required int body,
  required int rsmi,
  required int epheflag,
  required double geolon,
  required double geolat,
  required double geoalt,
  required double atpress,
  required double attemp,
  String? starName,
}) {
  try {
    final r = eph.riseTrans(
      jdUt,
      body,
      starName: starName,
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

/// Rise/set/transit result for one target, paired with the target itself.
class RiseSetGroupResult {
  const RiseSetGroupResult({required this.target, required this.result});

  final RiseSetTarget target;
  final RiseSetResult result;
}

RiseSetResult _computeOne(
  Ephemeris eph,
  SweUtils swe, {
  required RiseSetTarget target,
  required double jdUt,
  required int modifiers,
  required int epheflag,
  required double geolon,
  required double geolat,
  required double geoalt,
  required double atpress,
  required double attemp,
}) {
  ({double? jd, int? flag, RiseSetDateTime? dt, String? error}) run(int rsmi) =>
      _event(
        eph,
        swe,
        jdUt: jdUt,
        body: target.bodyId,
        starName: target.starName,
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
}

final _riseSetCalcProvider = Provider<CalcOutcome<List<RiseSetGroupResult>>>((
  ref,
) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final targets = ref.watch(riseSetTargetsProvider);
  final atpress = ref.watch(riseSetAtpressProvider);
  final attemp = ref.watch(riseSetAttempProvider);
  final modifiers = ref.watch(riseSetModifiersProvider);

  // Start from midnight local time (in UT) so all four events
  // (rise, set, transits) land on the same local calendar day.
  final utcOffsetDays = ctx.utcOffset / 24.0;
  final jdUt =
      (ctx.jdUt + utcOffsetDays + 0.5).floorToDouble() - 0.5 - utcOffsetDays;
  final geolon = ctx.longitude;
  final geolat = ctx.latitude;
  final geoalt = ctx.altitude;
  // riseTrans uses the basic ephe flag (no speed, no extras needed).
  final epheflag = flags.iflag & 0xF; // low bits: ephe source

  return runTabCalc(
    ref,
    compute: (eph, _) {
      return [
        for (final target in targets)
          RiseSetGroupResult(
            target: target,
            result: _computeOne(
              eph,
              swe,
              target: target,
              jdUt: jdUt,
              modifiers: modifiers,
              epheflag: epheflag,
              geolon: geolon,
              geolat: geolat,
              geoalt: geoalt,
              atpress: atpress,
              attemp: attemp,
            ),
          ),
      ];
    },
  );
});

/// Rise/set/transit result provider.
final riseSetResultProvider = Provider<CalcOutcome<List<RiseSetGroupResult>>>((
  ref,
) {
  return ref.watch(_riseSetCalcProvider);
});

// ── Export ────────────────────────────────────────────────────────────────────

String _jdStr(double? jd) => jd != null ? jd.toStringAsFixed(8) : '—';

String _dtStr(RiseSetDateTime? dt) => dt?.formatted() ?? '—';

List<ExportRow> riseSetToExportRows(List<RiseSetGroupResult> groups) {
  return [
    for (final group in groups) ...[
      ExportRow(
        header: '${group.target.label} — Rise',
        fields: [
          ('JD', _jdStr(group.result.riseJd)),
          ('Date/Time', _dtStr(group.result.riseDateTime)),
          if (group.result.riseError != null)
            ('Error', group.result.riseError!),
        ],
      ),
      ExportRow(
        header: '${group.target.label} — Set',
        fields: [
          ('JD', _jdStr(group.result.setJd)),
          ('Date/Time', _dtStr(group.result.setDateTime)),
          if (group.result.setError != null) ('Error', group.result.setError!),
        ],
      ),
      ExportRow(
        header: '${group.target.label} — Upper Transit',
        fields: [
          ('JD', _jdStr(group.result.upperTransitJd)),
          ('Date/Time', _dtStr(group.result.upperTransitDateTime)),
          if (group.result.upperTransitError != null)
            ('Error', group.result.upperTransitError!),
        ],
      ),
      ExportRow(
        header: '${group.target.label} — Lower Transit',
        fields: [
          ('JD', _jdStr(group.result.lowerTransitJd)),
          ('Date/Time', _dtStr(group.result.lowerTransitDateTime)),
          if (group.result.lowerTransitError != null)
            ('Error', group.result.lowerTransitError!),
        ],
      ),
    ],
  ];
}
