import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/export_service.dart';

// ── Eclipse search mode ──────────────────────────────────────────────────────

enum EclipseType { solar, lunar }

enum EclipseScope { global, local }

// ── Eclipse type filter (eclType param) ──────────────────────────────────────

const eclipseFilters = <(String, int)>[
  ('Any', 0),
  ('Total', seEclTotal),
  ('Annular', seEclAnnular),
  ('Partial', seEclPartial),
  ('Hybrid', seEclHybrid),
  ('Penumbral', seEclPenumbral), // lunar only
];

// ── State providers ──────────────────────────────────────────────────────────

final eclipseTypeProvider = StateProvider<EclipseType>(
  (ref) => EclipseType.solar,
);

final eclipseScopeProvider = StateProvider<EclipseScope>(
  (ref) => EclipseScope.global,
);

final eclipseFilterProvider = StateProvider<int>((ref) => 0);

/// How many eclipses to search for in a single Calculate press.
final eclipseCountProvider = StateProvider<int>((ref) => 5);

// ── Result models ────────────────────────────────────────────────────────────

class EclipseEvent {
  const EclipseEvent({
    required this.index,
    required this.type,
    required this.scope,
    required this.returnFlag,
    this.maxEclipseJd,
    this.beginJd,
    this.endJd,
    this.totalityBeginJd,
    this.totalityEndJd,
    this.penumbralBeginJd,
    this.penumbralEndJd,
    this.centerLineBeginJd,
    this.centerLineEndJd,
    this.localNoonJd,
    this.firstContactJd,
    this.secondContactJd,
    this.thirdContactJd,
    this.fourthContactJd,
    this.magnitude,
    this.obscuration,
    this.diameterRatio,
    this.coreShadowKm,
    this.sarosSeries,
    this.sarosMember,
    this.centralLat,
    this.centralLon,
    this.error,
  });

  final int index;
  final EclipseType type;
  final EclipseScope scope;
  final int returnFlag;

  final double? maxEclipseJd;
  final double? beginJd;
  final double? endJd;
  final double? totalityBeginJd;
  final double? totalityEndJd;
  final double? penumbralBeginJd;
  final double? penumbralEndJd;
  final double? centerLineBeginJd;
  final double? centerLineEndJd;
  final double? localNoonJd;
  final double? firstContactJd;
  final double? secondContactJd;
  final double? thirdContactJd;
  final double? fourthContactJd;

  final double? magnitude;
  final double? obscuration;
  final double? diameterRatio;
  final double? coreShadowKm;
  final double? sarosSeries;
  final double? sarosMember;

  final double? centralLat;
  final double? centralLon;

  final String? error;

  String get eclipseTypeLabel {
    final f = returnFlag;
    final parts = <String>[];
    if (f & seEclTotal != 0) parts.add('Total');
    if (f & seEclAnnular != 0) parts.add('Annular');
    if (f & seEclPartial != 0) parts.add('Partial');
    if (f & seEclHybrid != 0) parts.add('Hybrid');
    if (f & seEclPenumbral != 0) parts.add('Penumbral');
    if (f & seEclCentral != 0) parts.add('Central');
    if (f & seEclNonCentral != 0) parts.add('Non-central');
    return parts.isEmpty ? 'Unknown' : parts.join(', ');
  }
}

// ── Computation ──────────────────────────────────────────────────────────────

String _jdToDateStr(SwissEph swe, double jd) {
  try {
    final r = swe.revjul(jd);
    final h = r.hour.floor();
    final mFrac = (r.hour - h) * 60;
    final m = mFrac.floor();
    final s = ((mFrac - m) * 60).round();
    return '${r.year}-${_p(r.month)}-${_p(r.day)} ${_p(h)}:${_p(m)}:${_p(s)} UT';
  } catch (_) {
    return jd.toStringAsFixed(6);
  }
}

String _p(int n) => n.toString().padLeft(2, '0');

final eclipseResultsProvider = Provider<List<EclipseEvent>>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('eclipses')) return [];

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  runner.setTabTag('eclipses');
  final type = ref.watch(eclipseTypeProvider);
  final scope = ref.watch(eclipseScopeProvider);
  final eclFilter = ref.watch(eclipseFilterProvider);
  final count = ref.watch(eclipseCountProvider);

  final epheflag = ectx.iflag & 0xF;
  final results = <EclipseEvent>[];
  var searchJd = ectx.jdUt;

  for (var i = 0; i < count; i++) {
    try {
      final event = runner.run(
        globals,
        (eph) => _findNextEclipse(
          swe: eph,
          jdStart: searchJd,
          epheflag: epheflag,
          type: type,
          scope: scope,
          eclFilter: eclFilter,
          index: i + 1,
          geolon: ectx.longitude,
          geolat: ectx.latitude,
          geoalt: ectx.altitude,
        ),
      );
      results.add(event);
      if (event.maxEclipseJd != null) {
        searchJd = event.maxEclipseJd! + 1.0;
      } else {
        break;
      }
    } catch (e) {
      results.add(
        EclipseEvent(
          index: i + 1,
          type: type,
          scope: scope,
          returnFlag: 0,
          error: e.toString(),
        ),
      );
      break;
    }
  }

  return results;
});

EclipseEvent _findNextEclipse({
  required Ephemeris swe,
  required double jdStart,
  required int epheflag,
  required EclipseType type,
  required EclipseScope scope,
  required int eclFilter,
  required int index,
  required double geolon,
  required double geolat,
  required double geoalt,
}) {
  if (type == EclipseType.solar) {
    return _findSolarEclipse(
      swe: swe,
      jdStart: jdStart,
      epheflag: epheflag,
      scope: scope,
      eclFilter: eclFilter,
      index: index,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
    );
  } else {
    return _findLunarEclipse(
      swe: swe,
      jdStart: jdStart,
      epheflag: epheflag,
      scope: scope,
      eclFilter: eclFilter,
      index: index,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
    );
  }
}

EclipseEvent _findSolarEclipse({
  required Ephemeris swe,
  required double jdStart,
  required int epheflag,
  required EclipseScope scope,
  required int eclFilter,
  required int index,
  required double geolon,
  required double geolat,
  required double geoalt,
}) {
  if (scope == EclipseScope.global) {
    final g = swe.solEclipseWhenGlob(jdStart, epheflag, eclType: eclFilter);
    // Also get the central location at max eclipse.
    double? cLat, cLon;
    try {
      final w = swe.solEclipseWhere(g.maxEclipse, epheflag);
      cLat = w.geolat;
      cLon = w.geolon;
    } catch (_) {}

    return EclipseEvent(
      index: index,
      type: EclipseType.solar,
      scope: scope,
      returnFlag: g.returnFlag,
      maxEclipseJd: g.maxEclipse,
      localNoonJd: g.localNoon,
      beginJd: g.begin,
      endJd: g.end,
      totalityBeginJd: _nonZero(g.totalityBegin),
      totalityEndJd: _nonZero(g.totalityEnd),
      centerLineBeginJd: _nonZero(g.centerLineBegin),
      centerLineEndJd: _nonZero(g.centerLineEnd),
      centralLat: cLat,
      centralLon: cLon,
    );
  } else {
    final l = swe.solEclipseWhenLoc(
      jdStart,
      epheflag,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
    );
    return EclipseEvent(
      index: index,
      type: EclipseType.solar,
      scope: scope,
      returnFlag: l.returnFlag,
      maxEclipseJd: l.maxEclipse,
      firstContactJd: _nonZero(l.firstContact),
      secondContactJd: _nonZero(l.secondContact),
      thirdContactJd: _nonZero(l.thirdContact),
      fourthContactJd: _nonZero(l.fourthContact),
      magnitude: l.magnitude,
      obscuration: l.obscuration,
      diameterRatio: l.diameterRatio,
      coreShadowKm: l.coreShadowKm,
      sarosSeries: l.sarosSeries,
      sarosMember: l.sarosMember,
    );
  }
}

EclipseEvent _findLunarEclipse({
  required Ephemeris swe,
  required double jdStart,
  required int epheflag,
  required EclipseScope scope,
  required int eclFilter,
  required int index,
  required double geolon,
  required double geolat,
  required double geoalt,
}) {
  if (scope == EclipseScope.global) {
    final g = swe.lunEclipseWhen(jdStart, epheflag, eclType: eclFilter);
    return EclipseEvent(
      index: index,
      type: EclipseType.lunar,
      scope: scope,
      returnFlag: g.returnFlag,
      maxEclipseJd: g.maxEclipse,
      beginJd: _nonZero(g.partialBegin),
      endJd: _nonZero(g.partialEnd),
      totalityBeginJd: _nonZero(g.totalityBegin),
      totalityEndJd: _nonZero(g.totalityEnd),
      penumbralBeginJd: _nonZero(g.penumbralBegin),
      penumbralEndJd: _nonZero(g.penumbralEnd),
    );
  } else {
    final l = swe.lunEclipseWhenLoc(
      jdStart,
      epheflag,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
    );
    return EclipseEvent(
      index: index,
      type: EclipseType.lunar,
      scope: scope,
      returnFlag: l.returnFlag,
      maxEclipseJd: l.maxEclipse,
      beginJd: _nonZero(l.partialBegin),
      endJd: _nonZero(l.partialEnd),
      totalityBeginJd: _nonZero(l.totalityBegin),
      totalityEndJd: _nonZero(l.totalityEnd),
      penumbralBeginJd: _nonZero(l.penumbralBegin),
      penumbralEndJd: _nonZero(l.penumbralEnd),
      magnitude: l.umbralMagnitude,
      sarosSeries: l.sarosSeries,
      sarosMember: l.sarosMember,
    );
  }
}

double? _nonZero(double v) => v == 0.0 ? null : v;

// ── Export ────────────────────────────────────────────────────────────────────

List<ExportRow> eclipsesToExportRows(List<EclipseEvent> events, SwissEph swe) {
  return events.map((e) {
    final fields = <(String, String)>[('Type', e.eclipseTypeLabel)];
    if (e.error != null) {
      fields.add(('Error', e.error!));
    } else {
      if (e.maxEclipseJd != null) {
        fields.add(('Max Eclipse', _jdToDateStr(swe, e.maxEclipseJd!)));
        fields.add(('Max JD', e.maxEclipseJd!.toStringAsFixed(8)));
      }
      if (e.beginJd != null) {
        fields.add(('Begin', _jdToDateStr(swe, e.beginJd!)));
      }
      if (e.endJd != null) {
        fields.add(('End', _jdToDateStr(swe, e.endJd!)));
      }
      if (e.totalityBeginJd != null) {
        fields.add(('Totality Begin', _jdToDateStr(swe, e.totalityBeginJd!)));
      }
      if (e.totalityEndJd != null) {
        fields.add(('Totality End', _jdToDateStr(swe, e.totalityEndJd!)));
      }
      if (e.magnitude != null) {
        fields.add(('Magnitude', e.magnitude!.toStringAsFixed(4)));
      }
      if (e.centralLat != null && e.centralLon != null) {
        fields.add(('Central Lat', e.centralLat!.toStringAsFixed(4)));
        fields.add(('Central Lon', e.centralLon!.toStringAsFixed(4)));
      }
      if (e.sarosSeries != null) {
        fields.add((
          'Saros',
          '${e.sarosSeries!.round()}/${e.sarosMember?.round() ?? "?"}',
        ));
      }
    }
    return ExportRow(
      header: '#${e.index} ${e.type == EclipseType.solar ? "Solar" : "Lunar"}',
      fields: fields,
    );
  }).toList();
}
