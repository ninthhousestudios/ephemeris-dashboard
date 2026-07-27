// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/house_systems.dart';
import '../../core/swe_utils_provider.dart';
import '../../layout/tab_definitions.dart';

// House-system state (HouseSystemDef, houseSystems, selectedHouseSystemProvider)
// is app-wide and lives in core so the body tabs can share it without importing
// this tab. Re-exported so existing Houses-tab consumers keep their import.
export '../../core/house_systems.dart';

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

HousesCalcResult Function(Ephemeris, Moment) _housesCompute(Ref ref) {
  final ctx = ref.watch(contextBarProvider);
  final swe = ref.read(sweProvider);
  final hsys = ref.watch(selectedHouseSystemProvider);

  return (eph, moment) => computeHouses(
    eph,
    jdUt: moment.ut,
    lat: ctx.latitude,
    lon: ctx.longitude,
    hsys: hsys,
    hsysName: swe.houseName(hsys),
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
      return seriesSteps(
        ref,
        AppTab.houses.name,
        compute: () => _housesCompute(ref),
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
  return rows;
}
