// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/persistence.dart';
import '../../core/swe_constants.dart';
import '../../core/swe_service.dart';
import '../../layout/tab_definitions.dart';

/// Display format for Houses tab (promoted from local state).
final housesFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// The house a body falls in, from `swe_house_pos` (swetest `-fGgj`).
class BodyHousePos {
  const BodyHousePos({
    required this.bodyId,
    required this.name,
    required this.longitude,
    required this.latitude,
    required this.housePos,
    this.errorMessage,
  });

  final int bodyId;
  final String name;

  /// Tropical ecliptic longitude/latitude fed to `swe_house_pos`.
  final double longitude;
  final double latitude;

  /// Raw `swe_house_pos` value (swetest `j`): 1.0–12.999999 (1.0–36.99 for
  /// Gauquelin), integer part = house number, fraction = position within it.
  final double housePos;

  final String? errorMessage;

  /// House the body falls in (swetest `j` floored): 1–12 (1–36 Gauquelin).
  int get houseNumber => housePos.floor();

  /// Position in degrees (swetest `g`/`G`), houses treated as 30° each.
  double get positionDegrees => (housePos - 1) * 30;
}

/// Bodies the Houses tab reports house positions for — the classical set,
/// matching swetest's `-p0123456789`. A fixed set rather than a per-tab picker:
/// this is a completeness surface, not a selection workflow.
const houseBodies = <int>[
  seSun,
  seMoon,
  seMercury,
  seVenus,
  seMars,
  seJupiter,
  seSaturn,
  seUranus,
  seNeptune,
  sePluto,
];

/// Result of a house calculation.
class HousesCalcResult {
  const HousesCalcResult({
    required this.cusps,
    required this.ascmc,
    required this.hsys,
    required this.hsysName,
    required this.returnFlag,
    this.bodyPositions = const [],
  });

  final List<double> cusps;

  /// [0] Asc, [1] MC, [2] ARMC, [3] Vertex, [4] Eq Asc, [5..7] co-asc/polar
  final List<double> ascmc;
  final int hsys;
  final String hsysName;
  final int returnFlag;

  /// House position per body under [hsys] (empty if none requested).
  final List<BodyHousePos> bodyPositions;

  double get asc => ascmc[0];
  double get mc => ascmc[1];
  double get armc => ascmc[2];
  double get vertex => ascmc[3];
  double get equatorialAsc => ascmc[4];
}

/// Known house system codes and names.
class HouseSystemDef {
  const HouseSystemDef(this.code, this.label);
  final int code; // ASCII char code
  final String label;

  String get char => String.fromCharCode(code);
}

final houseSystems = <HouseSystemDef>[
  HouseSystemDef(0x50, 'Placidus'), // P
  HouseSystemDef(0x4B, 'Koch'), // K
  HouseSystemDef(0x4F, 'Porphyry'), // O
  HouseSystemDef(0x52, 'Regiomontanus'), // R
  HouseSystemDef(0x43, 'Campanus'), // C
  HouseSystemDef(0x45, 'Equal (Asc)'), // E
  HouseSystemDef(0x57, 'Whole Sign'), // W
  HouseSystemDef(0x41, 'Equal (MC)'), // A
  HouseSystemDef(0x42, 'Alcabitius'), // B
  HouseSystemDef(0x4D, 'Morinus'), // M
  HouseSystemDef(0x55, 'Krusinski'), // U
  HouseSystemDef(0x48, 'Azimuthal/Horizontal'), // H
  HouseSystemDef(0x56, 'Vehlow Equal'), // V
  HouseSystemDef(0x58, 'Meridian (Axial)'), // X
  HouseSystemDef(0x47, 'Gauquelin (36)'), // G
  HouseSystemDef(0x54, 'Polich/Page'), // T
  HouseSystemDef(0x44, 'Equal (MC, desc)'), // D
  HouseSystemDef(0x4E, 'Equal/1=Aries'), // N
  HouseSystemDef(0x59, 'APC Houses'), // Y
  HouseSystemDef(0x46, 'Carter Poli-Equatorial'), // F
  HouseSystemDef(0x49, 'Sunshine (Treindl)'), // I
  HouseSystemDef(0x69, 'Sunshine (Makransky)'), // i
  HouseSystemDef(0x4C, 'Pullen SD'), // L
  HouseSystemDef(0x51, 'Pullen SR'), // Q
];

/// Selected house system (persisted).
final selectedHouseSystemProvider = StateProvider<int>((ref) {
  return ref.read(persistenceProvider).loadHouseSystem();
});

/// Pure compute step: one `houses` call, the house-system display name, and —
/// for each of [bodies] — its house position via `swe_house_pos`.
///
/// House position needs the true obliquity ([seEclNut]) and tropical body
/// positions, so [iflag]'s sidereal bit is dropped for these calcs: the
/// handle-free `housePos` assumes the tropical frame that [armc]/eps share, and
/// swetest's `-fGgj` is tropical. A body whose calc throws is carried as an
/// error row, not a failure of the whole tab.
HousesCalcResult computeHouses(
  Ephemeris eph, {
  required double jdUt,
  required double lat,
  required double lon,
  required int hsys,
  required String hsysName,
  List<int> bodies = const [],
  int iflag = 0,
  String Function(int body)? getName,
}) {
  final r = eph.houses(jdUt, lat, lon, hsys);

  final bodyPositions = <BodyHousePos>[];
  if (bodies.isNotEmpty) {
    final calcFlag = iflag & ~seFlgSidereal;
    final armc = r.ascmc[2];
    final eps = eph.calcUt(jdUt, seEclNut, calcFlag).longitude;
    final name = getName ?? (body) => 'Body $body';
    for (final body in bodies) {
      try {
        final pos = eph.calcUt(jdUt, body, calcFlag);
        final hp = eph.housePos(
          armc,
          lat,
          eps,
          hsys,
          pos.longitude,
          pos.latitude,
        );
        bodyPositions.add(
          BodyHousePos(
            bodyId: body,
            name: name(body),
            longitude: pos.longitude,
            latitude: pos.latitude,
            housePos: hp,
          ),
        );
      } catch (e) {
        bodyPositions.add(
          BodyHousePos(
            bodyId: body,
            name: name(body),
            longitude: double.nan,
            latitude: double.nan,
            housePos: double.nan,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }

  return HousesCalcResult(
    cusps: r.cusps,
    ascmc: r.ascmc,
    hsys: hsys,
    hsysName: hsysName,
    returnFlag: r.returnFlag,
    bodyPositions: bodyPositions,
  );
}

HousesCalcResult Function(Ephemeris, Moment) _housesCompute(Ref ref) {
  final ctx = ref.watch(contextBarProvider);
  final swe = ref.read(sweProvider);
  final hsys = ref.watch(selectedHouseSystemProvider);
  final iflag = ref.watch(flagBarProvider).iflag;

  return (eph, moment) => computeHouses(
    eph,
    jdUt: moment.ut,
    lat: ctx.latitude,
    lon: ctx.longitude,
    hsys: hsys,
    hsysName: swe.houseName(hsys),
    bodies: houseBodies,
    iflag: iflag,
    getName: (body) => safeGetName(swe, body),
  );
}

final _housesCalcProvider = Provider<CalcOutcome<HousesCalcResult>>((ref) {
  return runTabCalc(ref, compute: _housesCompute(ref));
});

final housesResultProvider = Provider<CalcOutcome<HousesCalcResult>>((ref) {
  return ref.watch(_housesCalcProvider);
});

final housesSeriesProvider =
    Provider<List<(Moment, CalcOutcome<HousesCalcResult>)>>((ref) {
      ref.watch(
        seriesSettingsProvider(
          AppTab.houses.name,
        ).select((s) => (s.enabled, s.stepValue, s.stepUnit, s.rowCount)),
      );
      final settings = ref.read(seriesSettingsProvider(AppTab.houses.name));
      if (!settings.enabled) return const [];
      return runTabCalcSeries(
        ref,
        compute: _housesCompute(ref),
        settings: settings,
      );
    });

/// Convert house results to export rows.
List<ExportRow> housesToExportRows(HousesCalcResult result, DisplayFormat fmt) {
  final rows = <ExportRow>[];
  // Angles card first
  rows.add(
    ExportRow(
      header: 'Angles (${result.hsysName})',
      fields: [
        ('Asc', formatAngle(result.asc, fmt)),
        ('MC', formatAngle(result.mc, fmt)),
        ('ARMC', formatAngle(result.armc, fmt)),
        ('Vertex', formatAngle(result.vertex, fmt)),
        ('Eq Asc', formatAngle(result.equatorialAsc, fmt)),
      ],
    ),
  );
  // Cusp cards
  for (int i = 1; i < result.cusps.length; i++) {
    if (result.cusps[i] == 0.0 && i > 12) continue; // skip unused slots
    rows.add(
      ExportRow(
        header: 'Cusp $i',
        fields: [('Longitude', formatAngle(result.cusps[i], fmt))],
      ),
    );
  }
  // House position per body (swetest -fPGgj)
  for (final b in result.bodyPositions) {
    rows.add(
      ExportRow(
        header: b.name,
        fields: b.errorMessage != null
            ? [('House', '—'), ('House Pos', b.errorMessage!)]
            : [
                ('House', '${b.houseNumber}'),
                ('House Pos', formatAngle(b.positionDegrees, fmt)),
              ],
      ),
    );
  }
  return rows;
}
