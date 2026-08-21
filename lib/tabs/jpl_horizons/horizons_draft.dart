// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

// The editable draft for the JPL Horizons tab. Flat mutable-by-copyWith UI
// state; `build()` assembles the immutable core `HorizonsRequest`. Keeping the
// draft separate from the request means field editing never has to reach into
// the sealed option variants (per ADR-0003, the draft is free-to-edit UI state,
// the request is the artifact only Run produces).

import '../../core/context_state.dart';
import '../../core/horizons/horizons_request.dart';
import '../../core/horizons/horizons_types.dart';

/// How the observing centre is chosen in the UI.
enum CenterMode { geocentric, heliocentric, ssb, topocentric, custom }

/// Whether the time domain is a uniform range or an explicit list.
enum TimeMode { range, list }

class HorizonsDraft {
  const HorizonsDraft({
    this.ephemType = EphemType.observer,
    this.target = '',
    this.centerMode = CenterMode.geocentric,
    this.customCenter = '',
    this.topoBodyId = '399',
    this.coordType = CoordType.geodetic,
    this.siteCoord = '',
    this.timeMode = TimeMode.range,
    this.startTime = '',
    this.stopTime = '',
    this.stepSize = '',
    this.tlistText = '',
    this.tlistType = TimeListType.calendar,
    this.timeScale = TimeScale.ut,
    this.calendarFormat = CalendarFormat.calendar,
    this.refSystem = RefSystem.icrf,
    this.quantities = const <int>{},
    this.extraQuantitiesText = '',
    this.angleFormat = AngleFormat.hoursMinutesSeconds,
    this.apparent = ApparentType.airless,
    this.rangeUnits = RangeUnits.au,
    this.suppressRangeRate = false,
    this.skipDaylight = false,
    this.vectorTable = VectorTable.table3,
    this.vectorCorrection = VectorCorrection.none,
    this.vectorOutUnits = OutUnits.kmSeconds,
    this.vectorRefPlane = RefPlane.ecliptic,
    this.elementOutUnits = OutUnits.auDays,
    this.elementRefPlane = RefPlane.ecliptic,
    this.csvFormat = true,
    this.objData = true,
    this.extraPrecision = false,
    this.rawOverridesText = '',
  });

  final EphemType ephemType;
  final String target;

  final CenterMode centerMode;
  final String customCenter;
  final String topoBodyId;
  final CoordType coordType;
  final String siteCoord;

  final TimeMode timeMode;
  final String startTime;
  final String stopTime;
  final String stepSize;
  final String tlistText;
  final TimeListType tlistType;
  final TimeScale timeScale;
  final CalendarFormat calendarFormat;
  final RefSystem refSystem;

  // OBSERVER
  /// Catalogued QUANTITIES codes, driven by the checkbox grid
  /// ([observerQuantities]).
  final Set<int> quantities;

  /// Free-text escape hatch for codes not in the catalogue: comma/space
  /// separated integers, merged with [quantities] when the request is built.
  final String extraQuantitiesText;
  final AngleFormat angleFormat;
  final ApparentType apparent;
  final RangeUnits rangeUnits;
  final bool suppressRangeRate;
  final bool skipDaylight;

  // VECTORS
  final VectorTable vectorTable;
  final VectorCorrection vectorCorrection;
  final OutUnits vectorOutUnits;
  final RefPlane vectorRefPlane;

  // ELEMENTS
  final OutUnits elementOutUnits;
  final RefPlane elementRefPlane;

  // Output
  final bool csvFormat;
  final bool objData;
  final bool extraPrecision;

  /// Raw `KEY=VALUE` overrides, one per line, merged over the built params.
  final String rawOverridesText;

  HorizonsDraft copyWith({
    EphemType? ephemType,
    String? target,
    CenterMode? centerMode,
    String? customCenter,
    String? topoBodyId,
    CoordType? coordType,
    String? siteCoord,
    TimeMode? timeMode,
    String? startTime,
    String? stopTime,
    String? stepSize,
    String? tlistText,
    TimeListType? tlistType,
    TimeScale? timeScale,
    CalendarFormat? calendarFormat,
    RefSystem? refSystem,
    Set<int>? quantities,
    String? extraQuantitiesText,
    AngleFormat? angleFormat,
    ApparentType? apparent,
    RangeUnits? rangeUnits,
    bool? suppressRangeRate,
    bool? skipDaylight,
    VectorTable? vectorTable,
    VectorCorrection? vectorCorrection,
    OutUnits? vectorOutUnits,
    RefPlane? vectorRefPlane,
    OutUnits? elementOutUnits,
    RefPlane? elementRefPlane,
    bool? csvFormat,
    bool? objData,
    bool? extraPrecision,
    String? rawOverridesText,
  }) {
    return HorizonsDraft(
      ephemType: ephemType ?? this.ephemType,
      target: target ?? this.target,
      centerMode: centerMode ?? this.centerMode,
      customCenter: customCenter ?? this.customCenter,
      topoBodyId: topoBodyId ?? this.topoBodyId,
      coordType: coordType ?? this.coordType,
      siteCoord: siteCoord ?? this.siteCoord,
      timeMode: timeMode ?? this.timeMode,
      startTime: startTime ?? this.startTime,
      stopTime: stopTime ?? this.stopTime,
      stepSize: stepSize ?? this.stepSize,
      tlistText: tlistText ?? this.tlistText,
      tlistType: tlistType ?? this.tlistType,
      timeScale: timeScale ?? this.timeScale,
      calendarFormat: calendarFormat ?? this.calendarFormat,
      refSystem: refSystem ?? this.refSystem,
      quantities: quantities ?? this.quantities,
      extraQuantitiesText: extraQuantitiesText ?? this.extraQuantitiesText,
      angleFormat: angleFormat ?? this.angleFormat,
      apparent: apparent ?? this.apparent,
      rangeUnits: rangeUnits ?? this.rangeUnits,
      suppressRangeRate: suppressRangeRate ?? this.suppressRangeRate,
      skipDaylight: skipDaylight ?? this.skipDaylight,
      vectorTable: vectorTable ?? this.vectorTable,
      vectorCorrection: vectorCorrection ?? this.vectorCorrection,
      vectorOutUnits: vectorOutUnits ?? this.vectorOutUnits,
      vectorRefPlane: vectorRefPlane ?? this.vectorRefPlane,
      elementOutUnits: elementOutUnits ?? this.elementOutUnits,
      elementRefPlane: elementRefPlane ?? this.elementRefPlane,
      csvFormat: csvFormat ?? this.csvFormat,
      objData: objData ?? this.objData,
      extraPrecision: extraPrecision ?? this.extraPrecision,
      rawOverridesText: rawOverridesText ?? this.rawOverridesText,
    );
  }

  /// Pre-fill the query from the app Context: the Moment (JD, canonical UT1) as
  /// a single-epoch TLIST, the observer location as an Earth site (SITE_COORD is
  /// East-longitude, latitude in degrees, altitude in km — the Swiss/Horizons
  /// convention the Context already stores), and the center *mirrors the Context
  /// Origin* — geocentric stays geocentric, only a topocentric Context becomes a
  /// topocentric site. The site fields are filled regardless so switching to
  /// topocentric afterwards keeps them. Target is left untouched — mapping a
  /// BodySelection to a Horizons COMMAND id is a later slice.
  HorizonsDraft loadedFrom(ContextBarState ctx) {
    final altKm = ctx.altitude / 1000.0;
    final centerMode = switch (ctx.origin) {
      Origin.geocentric => CenterMode.geocentric,
      Origin.topocentric => CenterMode.topocentric,
      Origin.heliocentric => CenterMode.heliocentric,
      Origin.barycentric => CenterMode.ssb,
    };
    return copyWith(
      timeMode: TimeMode.list,
      // Bare JD number + TLIST_TYPE=JD; Horizons rejects a 'JD' prefix in TLIST.
      tlistText: '${ctx.jdUt}',
      tlistType: TimeListType.jd,
      timeScale: TimeScale.ut,
      centerMode: centerMode,
      coordType: CoordType.geodetic,
      topoBodyId: '399',
      siteCoord: '${ctx.longitude},${ctx.latitude},$altKm',
    );
  }

  /// Assemble the immutable request. Called by Run.
  HorizonsRequest build() {
    return HorizonsRequest(
      target: HorizonsTarget(target.trim()),
      center: _buildCenter(),
      time: _buildTime(),
      options: _buildOptions(),
      timeScale: timeScale,
      calendarFormat: calendarFormat,
      refSystem: refSystem,
      output: CommonOutput(
        csvFormat: csvFormat,
        objData: objData,
        extraPrecision: extraPrecision,
      ),
      rawOverrides: _parseOverrides(),
    );
  }

  ObserverCenter _buildCenter() => switch (centerMode) {
    CenterMode.geocentric => const CoordinateCenter('500@399'),
    CenterMode.heliocentric => const CoordinateCenter('500@10'),
    CenterMode.ssb => const CoordinateCenter('@0'),
    CenterMode.custom => CoordinateCenter(customCenter.trim()),
    CenterMode.topocentric => TopocentricCenter(
      bodyId: topoBodyId.trim().isEmpty ? '399' : topoBodyId.trim(),
      coordType: coordType,
      siteCoord: siteCoord.trim(),
    ),
  };

  HorizonsTimeSpec _buildTime() => switch (timeMode) {
    TimeMode.range => TimeRange(
      start: startTime.trim(),
      stop: stopTime.trim(),
      step: stepSize.trim(),
    ),
    TimeMode.list => TimeList(_splitLines(tlistText), type: tlistType),
  };

  EphemOptions _buildOptions() => switch (ephemType) {
    EphemType.observer => ObserverOptions(
      quantities: {...quantities, ..._parseQuantities(extraQuantitiesText)},
      angleFormat: angleFormat,
      apparent: apparent,
      rangeUnits: rangeUnits,
      suppressRangeRate: suppressRangeRate,
      skipDaylight: skipDaylight,
    ),
    EphemType.vectors => VectorOptions(
      table: vectorTable,
      correction: vectorCorrection,
      outUnits: vectorOutUnits,
      refPlane: vectorRefPlane,
    ),
    EphemType.elements => ElementOptions(
      outUnits: elementOutUnits,
      refPlane: elementRefPlane,
    ),
    EphemType.spk => const SpkOptions(),
    EphemType.approach => const ApproachOptions(),
  };

  Set<int> _parseQuantities(String text) {
    final codes = <int>{};
    for (final token in text.split(RegExp(r'[,\s]+'))) {
      final n = int.tryParse(token.trim());
      if (n != null) codes.add(n);
    }
    return codes;
  }

  List<String> _splitLines(String text) => text
      .split(RegExp(r'[\n,]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Map<String, String> _parseOverrides() {
    final map = <String, String>{};
    for (final line in rawOverridesText.split('\n')) {
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim();
      final value = line.substring(eq + 1).trim();
      if (key.isNotEmpty) map[key] = value;
    }
    return map;
  }
}
