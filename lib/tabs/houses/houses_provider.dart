// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/ephemeris/trace_model.dart';
import '../../core/export_service.dart';
import '../../core/persistence.dart';
import '../../core/swe_service.dart';

/// Display format for Houses tab (promoted from local state).
final housesFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Result of a house calculation.
class HousesCalcResult {
  const HousesCalcResult({
    required this.cusps,
    required this.ascmc,
    required this.hsys,
    required this.hsysName,
    required this.returnFlag,
  });

  final List<double> cusps;

  /// [0] Asc, [1] MC, [2] ARMC, [3] Vertex, [4] Eq Asc, [5..7] co-asc/polar
  final List<double> ascmc;
  final int hsys;
  final String hsysName;
  final int returnFlag;

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

/// Pure compute step: one `houses` call, plus the house-system display name.
HousesCalcResult computeHouses(
  Ephemeris eph, {
  required double jdUt,
  required double lat,
  required double lon,
  required int hsys,
  required String hsysName,
}) {
  final r = eph.houses(jdUt, lat, lon, hsys);
  return HousesCalcResult(
    cusps: r.cusps,
    ascmc: r.ascmc,
    hsys: hsys,
    hsysName: hsysName,
    returnFlag: r.returnFlag,
  );
}

/// Runs the kernel once per recompute; results + trace derive from this.
final _housesCalcProvider =
    Provider<({CalcOutcome<HousesCalcResult> outcome, CallTrace trace})>((ref) {
      final ctx = ref.watch(contextBarProvider);
      final swe = ref.read(sweProvider);
      final hsys = ref.watch(selectedHouseSystemProvider);

      return runTabCalc(
        ref,
        tabTag: 'houses',
        compute: (eph) => computeHouses(
          eph,
          jdUt: ctx.jdUt,
          lat: ctx.latitude,
          lon: ctx.longitude,
          hsys: hsys,
          hsysName: swe.houseName(hsys),
        ),
      );
    });

/// Houses calculation result.
final housesResultProvider = Provider<CalcOutcome<HousesCalcResult>>((ref) {
  return ref.watch(_housesCalcProvider.select((c) => c.outcome));
});

/// Call Trace produced by the most recent houses calculation.
final housesTraceProvider = Provider<CallTrace>((ref) {
  return ref.watch(_housesCalcProvider.select((c) => c.trace));
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
  return rows;
}
