// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/ephemeris/trace_model.dart';
import '../../core/export_service.dart';

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

/// Runs the kernel once per recompute; results + trace derive from this.
/// Each mode reconfigures the engine with a per-mode sidMode override.
final _ayanamsaCalcProvider =
    Provider<
      ({CalcOutcome<List<AyanamsaCalcResult>> outcome, CallTrace trace})
    >((ref) {
      final ctx = ref.watch(contextBarProvider);
      final selected = ref.watch(selectedAyanamsasProvider);
      final compareMode = ref.watch(ayanamsaCompareModeProvider);

      // Compare-all drops user-defined unless params have been set.
      final hasUserParams = ctx.userAyanT0 != 0.0 || ctx.userAyanValue != 0.0;
      final modes = compareMode
          ? ayanamsaModesFor(includeUser: hasUserParams).keys.toList()
          : selected;

      final baseGlobals = ref.watch(appliedGlobalsProvider);
      return runTabCalcWithOverrides(
        ref,
        tabTag: 'ayanamsa',
        compute: (eph, reconfigure) {
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
              reconfigure(modeGlobals);
              final value = eph.getAyanamsaUt(ctx.jdUt);
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
        },
      );
    });

/// Ayanamsa calculation results.
final ayanamsaResultsProvider = Provider<CalcOutcome<List<AyanamsaCalcResult>>>(
  (ref) => ref.watch(_ayanamsaCalcProvider.select((c) => c.outcome)),
);

/// Call Trace produced by the most recent ayanamsa calculation.
final ayanamsaTraceProvider = Provider<CallTrace>(
  (ref) => ref.watch(_ayanamsaCalcProvider.select((c) => c.trace)),
);

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
