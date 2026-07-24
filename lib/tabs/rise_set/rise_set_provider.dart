// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/flag_masks.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_service.dart';
import '../../core/swe_utils.dart';
import '../../layout/tab_definitions.dart';

// ── rsmi type flags ───────────────────────────────────────────────────────────

const int rsCalcRise = 1;
const int rsCalcSet = 2;
const int rsCalcMtransit = 4;
const int rsCalcItransit = 8;

// ── Modifier model ────────────────────────────────────────────────────────────
//
// The rsmi bitmask is derived from an explicit, non-contradictory model rather
// than edited bit-by-bit. Several Swiss Ephemeris bits overlap in meaning —
// Hindu Rising is a composite that subsumes Disc Center + No Refraction — so a
// raw bitmask lets two chips light inconsistently or contradict each other
// (e.g. Disc Bottom + Hindu Rising, which forces Disc Center). Modelling the
// intent and computing the bits in one place makes those states unrepresentable.

/// Which point on the body's disc a rise/set is referenced to. Mutually
/// exclusive; [upperLimb] is the Swiss Ephemeris default (no bit set).
enum DiscReference { upperLimb, center, bottom }

/// Twilight reference for rise/set. Mutually exclusive. Applies to the Sun only;
/// Swiss Ephemeris ignores it for other bodies.
enum TwilightMode { none, civil, nautical, astronomical }

/// The rise/set modifier options. Immutable; the raw `rsmi` bitmask is a derived
/// view ([rsmi]), never stored.
class RiseSetModifiers {
  const RiseSetModifiers({
    this.disc = DiscReference.upperLimb,
    this.noRefraction = false,
    this.hinduRising = false,
    this.twilight = TwilightMode.none,
  });

  final DiscReference disc;
  final bool noRefraction;
  final bool hinduRising;
  final TwilightMode twilight;

  RiseSetModifiers copyWith({
    DiscReference? disc,
    bool? noRefraction,
    bool? hinduRising,
    TwilightMode? twilight,
  }) => RiseSetModifiers(
    disc: disc ?? this.disc,
    noRefraction: noRefraction ?? this.noRefraction,
    hinduRising: hinduRising ?? this.hinduRising,
    twilight: twilight ?? this.twilight,
  );

  /// The Swiss Ephemeris `rsmi` modifier bits (event-type bits excluded). Hindu
  /// Rising already OR's in Disc Center + No Refraction, so the union is exact.
  int get rsmi {
    var m = 0;
    switch (disc) {
      case DiscReference.center:
        m |= seBitDiscCenter;
      case DiscReference.bottom:
        m |= seBitDiscBottom;
      case DiscReference.upperLimb:
        break;
    }
    if (noRefraction) m |= seBitNoRefraction;
    if (hinduRising) m |= seBitHinduRising;
    switch (twilight) {
      case TwilightMode.civil:
        m |= seBitCivilTwilight;
      case TwilightMode.nautical:
        m |= seBitNauticTwilight;
      case TwilightMode.astronomical:
        m |= seBitAstroTwilight;
      case TwilightMode.none:
        break;
    }
    return m;
  }
}

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

/// Active rise/set modifier options (disc reference, refraction, Hindu Rising,
/// twilight). The `rsmi` bitmask is derived; event-type bits are added per call.
final riseSetModifiersProvider = StateProvider<RiseSetModifiers>(
  (ref) => const RiseSetModifiers(),
);

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

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

/// Rise/set/transit results for one body.
class RiseSetResult {
  const RiseSetResult({
    this.riseJd,
    this.riseDateTime,
    this.setJd,
    this.setDateTime,
    this.upperTransitJd,
    this.upperTransitDateTime,
    this.lowerTransitJd,
    this.lowerTransitDateTime,
    this.riseError,
    this.setError,
    this.upperTransitError,
    this.lowerTransitError,
  });

  final double? riseJd;
  final RiseSetDateTime? riseDateTime;

  final double? setJd;
  final RiseSetDateTime? setDateTime;

  final double? upperTransitJd;
  final RiseSetDateTime? upperTransitDateTime;

  final double? lowerTransitJd;
  final RiseSetDateTime? lowerTransitDateTime;

  final String? riseError;
  final String? setError;
  final String? upperTransitError;
  final String? lowerTransitError;
}

// ── Computation ───────────────────────────────────────────────────────────────

/// The start-of-day JD (in UT) of the LOCAL calendar day that [jdUt] falls in,
/// given [utcOffsetHours]. Anchoring the search on local midnight keeps all four
/// events (rise, set, both transits) on the same local day. NOTE: [utcOffset] is
/// a *compute* input here, not just display — shifting it moves which day's
/// events are found (lesson 019f9071). The series steps this per Moment.
double localMidnightStart(double jdUt, double utcOffsetHours) {
  final offsetDays = utcOffsetHours / 24.0;
  return (jdUt + offsetDays + 0.5).floorToDouble() - 0.5 - offsetDays;
}

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
/// batch. Returns (jd, dateTime) on success; (error) otherwise.
({double? jd, RiseSetDateTime? dt, String? error}) _event(
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
      dt: _toDateTime(swe, r.transitTime),
      error: null,
    );
  } catch (e) {
    return (jd: null, dt: null, error: e.toString());
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
  ({double? jd, RiseSetDateTime? dt, String? error}) run(int rsmi) => _event(
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
    riseError: rise.error,
    setJd: set.jd,
    setDateTime: set.dt,
    setError: set.error,
    upperTransitJd: upper.jd,
    upperTransitDateTime: upper.dt,
    upperTransitError: upper.error,
    lowerTransitJd: lower.jd,
    lowerTransitDateTime: lower.dt,
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

  // Start from local midnight (in UT) so all four events land on the same
  // local calendar day.
  final jdUt = localMidnightStart(ctx.jdUt, ctx.utcOffset);
  final geolon = ctx.longitude;
  final geolat = ctx.latitude;
  final geoalt = ctx.altitude;
  // riseTrans uses the basic ephe flag (no speed, no extras needed).
  final epheflag = epheSourceFlag(flags.iflag);

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
              modifiers: modifiers.rsmi,
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

// ── Series ──────────────────────────────────────────────────────────────────

/// Per-step rise/set compute for series mode: single target (the first
/// selected), stepped over the series Moments. Every Context-derived input is
/// captured here, outside the closure; only the per-step [Moment] varies inside,
/// so the search window follows the step (not the Context) — the local-midnight
/// snap keys off `moment.ut`, honouring the "Moment comes from the series step"
/// invariant while still using the Context's UTC offset as a compute input.
RiseSetResult Function(Ephemeris, Moment) _riseSetSeriesCompute(Ref ref) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final targets = ref.watch(riseSetTargetsProvider);
  final atpress = ref.watch(riseSetAtpressProvider);
  final attemp = ref.watch(riseSetAttempProvider);
  final rsmi = ref.watch(riseSetModifiersProvider).rsmi;
  final utcOffset = ctx.utcOffset;
  final geolon = ctx.longitude;
  final geolat = ctx.latitude;
  final geoalt = ctx.altitude;
  final epheflag = epheSourceFlag(flags.iflag);
  final target = targets.isEmpty ? null : targets.first;

  return (eph, moment) {
    if (target == null) return const RiseSetResult();
    return _computeOne(
      eph,
      swe,
      target: target,
      jdUt: localMidnightStart(moment.ut, utcOffset),
      modifiers: rsmi,
      epheflag: epheflag,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
      atpress: atpress,
      attemp: attemp,
    );
  };
}

/// The single target series mode follows (the first selected), or null when
/// nothing is selected. Exposed so the tab can name it above the grid.
final riseSetSeriesTargetProvider = Provider<RiseSetTarget?>((ref) {
  final targets = ref.watch(riseSetTargetsProvider);
  return targets.isEmpty ? null : targets.first;
});

/// Rise/set series: one row per stepped day for the single series target.
final riseSetSeriesProvider =
    Provider<List<(Moment, CalcOutcome<RiseSetResult>)>>((ref) {
      ref.watch(
        seriesSettingsProvider(
          AppTab.riseSet.name,
        ).select((s) => (s.enabled, s.stepValue, s.stepUnit, s.rowCount)),
      );
      final settings = ref.read(seriesSettingsProvider(AppTab.riseSet.name));
      if (!settings.enabled) return const [];

      return runTabCalcSeries(
        ref,
        compute: _riseSetSeriesCompute(ref),
        settings: settings,
      );
    });

/// Series projection: one row, columns Rise/Set/Upper/Lower as civil times.
/// A per-event error (e.g. polar day/night) fills its own cell, leaving the
/// others intact.
List<ExportRow> riseSetSeriesToExportRows(
  RiseSetResult r,
  String Function(double? jd, String? error) cell,
) {
  return [
    ExportRow(
      header: '',
      fields: [
        ('Rise', cell(r.riseJd, r.riseError)),
        ('Set', cell(r.setJd, r.setError)),
        ('Upper Transit', cell(r.upperTransitJd, r.upperTransitError)),
        ('Lower Transit', cell(r.lowerTransitJd, r.lowerTransitError)),
      ],
    ),
  ];
}

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
