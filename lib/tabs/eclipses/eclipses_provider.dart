// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/body_utils.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../core/swe_utils.dart';

// ── Eclipse search mode ──────────────────────────────────────────────────────

enum EclipseType { solar, lunar, occultation }

enum EclipseScope { global, local }

/// Whether the occultation target is a planet or a fixed star (mirrors
/// swetest's `-p` vs `-pf -xf<Star>`).
enum OccultTarget { planet, star }

/// Planets the Moon can occult — the Sun (a solar eclipse) and the Moon itself
/// are excluded.
const occultablePlanets = <int>[
  seMercury,
  seVenus,
  seMars,
  seJupiter,
  seSaturn,
  seUranus,
  seNeptune,
  sePluto,
];

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

/// Occultation target selection (only consulted when [eclipseTypeProvider] is
/// [EclipseType.occultation]).
final occultTargetKindProvider = StateProvider<OccultTarget>(
  (ref) => OccultTarget.planet,
);

final occultPlanetProvider = StateProvider<int>((ref) => seVenus);

final occultStarProvider = StateProvider<String>((ref) => 'Aldebaran');

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
    this.sunriseJd,
    this.sunsetJd,
    this.targetLabel,
    this.visibilityRemark,
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

  /// Sun rise/set bracketing local visibility (occultation & solar-local).
  final double? sunriseJd;
  final double? sunsetJd;

  /// Occulted body's display name (occultation mode only).
  final String? targetLabel;

  /// Observability note for a local occultation, derived from the return
  /// flags: "(daytime)" / "(sunrise)" / "(sunset)" and visibility.
  final String? visibilityRemark;

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

final _eclipsesCalcProvider = Provider<CalcOutcome<List<EclipseEvent>>>((ref) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);
  final type = ref.watch(eclipseTypeProvider);
  final scope = ref.watch(eclipseScopeProvider);
  final eclFilter = ref.watch(eclipseFilterProvider);
  final count = ref.watch(eclipseCountProvider);

  // Occultation target: resolved to a body id / star name / display label here,
  // in the provider, so the pure compute never touches SweUtils or the Context.
  final targetKind = ref.watch(occultTargetKindProvider);
  final targetPlanet = ref.watch(occultPlanetProvider);
  final targetStar = ref.watch(occultStarProvider);
  final swe = ref.read(sweProvider);
  final isStarTarget = targetKind == OccultTarget.star;
  final targetBody = isStarTarget ? 0 : targetPlanet;
  final targetStarName = isStarTarget ? targetStar : null;
  final targetLabel = isStarTarget
      ? targetStar
      : safeGetName(swe, targetPlanet);

  final epheflag = flags.iflag & 0xF;

  return runTabCalc(
    ref,
    compute: (eph, moment) {
      final results = <EclipseEvent>[];
      var searchJd = moment.ut;

      for (var i = 0; i < count; i++) {
        try {
          final event = _findNextEclipse(
            swe: eph,
            jdStart: searchJd,
            epheflag: epheflag,
            type: type,
            scope: scope,
            eclFilter: eclFilter,
            index: i + 1,
            geolon: ctx.longitude,
            geolat: ctx.latitude,
            geoalt: ctx.altitude,
            targetBody: targetBody,
            targetStarName: targetStarName,
            targetLabel: targetLabel,
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
    },
  );
});

/// Eclipse search results.
final eclipseResultsProvider = Provider<CalcOutcome<List<EclipseEvent>>>((ref) {
  return ref.watch(_eclipsesCalcProvider);
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
  required int targetBody,
  required String? targetStarName,
  required String targetLabel,
}) {
  switch (type) {
    case EclipseType.solar:
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
    case EclipseType.lunar:
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
    case EclipseType.occultation:
      return _findOccultation(
        swe: swe,
        jdStart: jdStart,
        epheflag: epheflag,
        scope: scope,
        eclFilter: eclFilter,
        index: index,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        targetBody: targetBody,
        targetStarName: targetStarName,
        targetLabel: targetLabel,
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

EclipseEvent _findOccultation({
  required Ephemeris swe,
  required double jdStart,
  required int epheflag,
  required EclipseScope scope,
  required int eclFilter,
  required int index,
  required double geolon,
  required double geolat,
  required double geoalt,
  required int targetBody,
  required String? targetStarName,
  required String targetLabel,
}) {
  if (scope == EclipseScope.global) {
    final g = swe.lunOccultWhenGlob(
      jdStart,
      targetBody,
      epheflag,
      starName: targetStarName,
      eclType: eclFilter,
    );
    // Geographic position of maximum occultation.
    double? cLat, cLon;
    try {
      final w = swe.lunOccultWhere(
        g.maxEclipse,
        targetBody,
        epheflag,
        starName: targetStarName,
      );
      cLat = w.geolat;
      cLon = w.geolon;
    } catch (_) {}

    return EclipseEvent(
      index: index,
      type: EclipseType.occultation,
      scope: scope,
      returnFlag: g.returnFlag,
      maxEclipseJd: g.maxEclipse,
      localNoonJd: _nonZero(g.localNoon),
      beginJd: _nonZero(g.begin),
      endJd: _nonZero(g.end),
      totalityBeginJd: _nonZero(g.totalityBegin),
      totalityEndJd: _nonZero(g.totalityEnd),
      centerLineBeginJd: _nonZero(g.centerLineBegin),
      centerLineEndJd: _nonZero(g.centerLineEnd),
      centralLat: cLat,
      centralLon: cLon,
      targetLabel: targetLabel,
    );
  } else {
    final l = swe.lunOccultWhenLoc(
      jdStart,
      targetBody,
      epheflag,
      starName: targetStarName,
      geolon: geolon,
      geolat: geolat,
      geoalt: geoalt,
    );
    return EclipseEvent(
      index: index,
      type: EclipseType.occultation,
      scope: scope,
      returnFlag: l.returnFlag,
      maxEclipseJd: l.maxEclipse,
      firstContactJd: _nonZero(l.firstContact),
      secondContactJd: _nonZero(l.secondContact),
      thirdContactJd: _nonZero(l.thirdContact),
      fourthContactJd: _nonZero(l.fourthContact),
      sunriseJd: _nonZero(l.rise),
      sunsetJd: _nonZero(l.set),
      // Occultation magnitude is the diameter-ratio method only; no NASA
      // magnitude and no Saros series.
      magnitude: l.diameterRatio,
      diameterRatio: l.diameterRatio,
      obscuration: l.obscuration,
      targetLabel: targetLabel,
      visibilityRemark: _occultVisibility(l.returnFlag),
    );
  }
}

/// Observability note for a local occultation, from the return flags. Mirrors
/// swetest's "(daytime)" / "(sunrise)" / "(sunset)" annotations.
String? _occultVisibility(int flag) {
  if (flag & seEclVisible == 0) return 'Not visible from this location';
  final notes = <String>[];
  if (flag & seEclOccBegDaylight != 0) notes.add('begins in daylight');
  if (flag & seEclOccEndDaylight != 0) notes.add('ends in daylight');
  return notes.isEmpty ? 'Visible' : 'Visible (${notes.join(', ')})';
}

double? _nonZero(double v) => v == 0.0 ? null : v;

// ── Export ────────────────────────────────────────────────────────────────────

String _typeShort(EclipseType t) => switch (t) {
  EclipseType.solar => 'Solar',
  EclipseType.lunar => 'Lunar',
  EclipseType.occultation => 'Occultation',
};

List<ExportRow> eclipsesToExportRows(List<EclipseEvent> events, SweUtils swe) {
  return events.map((e) {
    final fields = <(String, String)>[('Type', e.eclipseTypeLabel)];
    if (e.error != null) {
      fields.add(('Error', e.error!));
    } else {
      if (e.targetLabel != null) fields.add(('Target', e.targetLabel!));
      if (e.maxEclipseJd != null) {
        fields.add(('Max Eclipse', formatJdDateTime(swe, e.maxEclipseJd!)));
        fields.add(('Max JD', e.maxEclipseJd!.toStringAsFixed(8)));
      }
      if (e.beginJd != null) {
        fields.add(('Begin', formatJdDateTime(swe, e.beginJd!)));
      }
      if (e.endJd != null) {
        fields.add(('End', formatJdDateTime(swe, e.endJd!)));
      }
      if (e.totalityBeginJd != null) {
        fields.add((
          'Totality Begin',
          formatJdDateTime(swe, e.totalityBeginJd!),
        ));
      }
      if (e.totalityEndJd != null) {
        fields.add(('Totality End', formatJdDateTime(swe, e.totalityEndJd!)));
      }
      void addContact(String label, double? jd) {
        if (jd != null) fields.add((label, formatJdDateTime(swe, jd)));
      }

      addContact('1st Contact', e.firstContactJd);
      addContact('2nd Contact', e.secondContactJd);
      addContact('3rd Contact', e.thirdContactJd);
      addContact('4th Contact', e.fourthContactJd);
      addContact('Sunrise', e.sunriseJd);
      addContact('Sunset', e.sunsetJd);
      if (e.magnitude != null) {
        fields.add(('Magnitude', e.magnitude!.toStringAsFixed(4)));
      }
      if (e.obscuration != null) {
        fields.add((
          'Obscuration',
          '${(e.obscuration! * 100).toStringAsFixed(2)}%',
        ));
      }
      if (e.centralLat != null && e.centralLon != null) {
        fields.add(('Central Lat', e.centralLat!.toStringAsFixed(4)));
        fields.add(('Central Lon', e.centralLon!.toStringAsFixed(4)));
      }
      if (e.visibilityRemark != null) {
        fields.add(('Visibility', e.visibilityRemark!));
      }
      if (e.sarosSeries != null) {
        fields.add((
          'Saros',
          '${e.sarosSeries!.round()}/${e.sarosMember?.round() ?? "?"}',
        ));
      }
    }
    return ExportRow(
      header: '#${e.index} ${_typeShort(e.type)}',
      fields: fields,
    );
  }).toList();
}
