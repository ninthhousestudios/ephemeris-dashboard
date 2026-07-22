// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/export_service.dart';
import '../../layout/tab_definitions.dart';

/// Display format for Ayanamsa tab (promoted from local state).
final ayanamsaFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Result for a single ayanamsa calculation.
class AyanamsaCalcResult {
  const AyanamsaCalcResult({
    required this.sidMode,
    required this.name,
    required this.value,
  });

  final int sidMode;
  final String name;
  final double value;
}

/// Ayanamsa modes shown on this tab.
/// Canonical catalog from lib/core/ayanamsa_catalog.dart.
/// User-defined (255) is omitted unless the user has set t0/value.
Map<int, String> ayanamsaModesFor({bool includeUser = true}) {
  final map = <int, String>{};
  for (final e in ayanamsaCatalog) {
    if (!includeUser && e.id == ayanamsaUserId) continue;
    map[e.id] = e.name;
  }
  return map;
}

/// Selected ayanamsas for compare mode.
final selectedAyanamsasProvider = StateProvider<List<int>>(
  (ref) => [1],
); // Lahiri default

/// Compare mode toggle.
final ayanamsaCompareModeProvider = StateProvider<bool>((ref) => false);

List<AyanamsaCalcResult> Function(Ephemeris, Moment) _ayanamsaCompute(Ref ref) {
  final ctx = ref.watch(contextBarProvider);
  final selected = ref.watch(selectedAyanamsasProvider);
  final compareMode = ref.watch(ayanamsaCompareModeProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final baseGlobals = ref.watch(appliedGlobalsProvider);

  final hasUserParams = ctx.userAyanT0 != 0.0 || ctx.userAyanValue != 0.0;
  final modes = compareMode
      ? ayanamsaModesFor(includeUser: hasUserParams).keys.toList()
      : selected;

  return (eph, moment) {
    final results = <AyanamsaCalcResult>[];
    for (final sidMode in modes) {
      try {
        final modeGlobals = sidMode == ayanamsaUserId
            ? baseGlobals.withSidMode(
                sidMode,
                t0: ctx.userAyanT0,
                ayanT0: ctx.userAyanValue,
              )
            : baseGlobals.withSidMode(sidMode);
        runner.apply(modeGlobals);
        final value = eph.getAyanamsaUt(moment.ut);
        results.add(
          AyanamsaCalcResult(
            sidMode: sidMode,
            name: ayanamsaName(sidMode),
            value: value,
          ),
        );
      } on SweException {
        // Per-item failure: skip this mode, batch continues.
      }
    }
    return results;
  };
}

final _ayanamsaCalcProvider = Provider<CalcOutcome<List<AyanamsaCalcResult>>>((
  ref,
) {
  return runTabCalc(ref, compute: _ayanamsaCompute(ref));
});

final ayanamsaResultsProvider = Provider<CalcOutcome<List<AyanamsaCalcResult>>>(
  (ref) => ref.watch(_ayanamsaCalcProvider),
);

final ayanamsaSeriesProvider =
    Provider<List<(Moment, CalcOutcome<List<AyanamsaCalcResult>>)>>((ref) {
      final settings = ref.watch(seriesSettingsProvider(AppTab.ayanamsa.name));
      if (!settings.enabled) return const [];
      return runTabCalcSeries(
        ref,
        compute: _ayanamsaCompute(ref),
        settings: settings,
      );
    });

/// Convert ayanamsa results to export rows.
List<ExportRow> ayanamsaToExportRows(
  List<AyanamsaCalcResult> results,
  DisplayFormat fmt,
) {
  return results
      .map(
        (r) => ExportRow(
          header: r.name,
          fields: [('Value', formatAngle(r.value, fmt))],
        ),
      )
      .toList();
}
