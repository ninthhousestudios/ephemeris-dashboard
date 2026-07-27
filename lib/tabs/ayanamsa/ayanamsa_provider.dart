// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/applied_globals.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/swe_constants.dart' show SweException;
import '../../core/user_ayanamsa.dart';
import '../../layout/tab_definitions.dart';

/// Display format for Ayanamsa tab (promoted from local state).
final ayanamsaFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Result for a single ayanamsa calculation.
///
/// [userId] is set only for user-defined entries and identifies which
/// [UserAyanamsa] produced this row (built-in rows leave it null).
class AyanamsaCalcResult {
  const AyanamsaCalcResult({
    required this.sidMode,
    required this.name,
    required this.value,
    this.userId,
  });

  final int sidMode;
  final String name;
  final double value;
  final int? userId;
}

/// Built-in ayanamsa modes shown on this tab (User-defined excluded — it is an
/// add action, not a toggle). Canonical catalog from ayanamsa_catalog.dart.
Map<int, String> ayanamsaModesFor() {
  final map = <int, String>{};
  for (final e in ayanamsaCatalog) {
    if (e.id == ayanamsaUserId) continue;
    map[e.id] = e.name;
  }
  return map;
}

/// Selected built-in ayanamsas.
final selectedAyanamsasProvider = StateProvider<List<int>>(
  (ref) => [1],
); // Lahiri default

/// Compare mode toggle.
final ayanamsaCompareModeProvider = StateProvider<bool>((ref) => false);

/// Signature the tab's compute takes: it may reconfigure the engine per
/// ayanamsha, since each mode is a different sidereal configuration. This runs
/// through the [runTabCalcWithOverrides] seam rather than the runner directly.
typedef _AyanamsaCompute =
    List<AyanamsaCalcResult> Function(
      Ephemeris eph,
      Moment moment,
      AppliedGlobals baseGlobals,
      void Function(AppliedGlobals) reconfigure,
    );

_AyanamsaCompute _ayanamsaCompute(Ref ref) {
  final selected = ref.watch(selectedAyanamsasProvider);
  final compareMode = ref.watch(ayanamsaCompareModeProvider);
  final users = ref.watch(userAyanamsasProvider);

  final builtins = compareMode ? ayanamsaModesFor().keys.toList() : selected;

  return (eph, moment, baseGlobals, reconfigure) {
    final results = <AyanamsaCalcResult>[];
    for (final sidMode in builtins) {
      try {
        reconfigure(baseGlobals.withSidMode(sidMode));
        results.add(
          AyanamsaCalcResult(
            sidMode: sidMode,
            name: ayanamsaName(sidMode),
            value: eph.getAyanamsaUt(moment.ut),
          ),
        );
      } on SweException {
        // Per-item failure: skip this mode, batch continues.
      }
    }
    for (var i = 0; i < users.length; i++) {
      final u = users[i];
      try {
        reconfigure(
          baseGlobals.withSidMode(u.sidMode, t0: u.t0, ayanT0: u.value),
        );
        results.add(
          AyanamsaCalcResult(
            sidMode: ayanamsaUserId,
            userId: u.id,
            name: userAyanamsaLabel(u, i),
            value: eph.getAyanamsaUt(moment.ut),
          ),
        );
      } on SweException {
        // Per-item failure: skip this entry, batch continues.
      }
    }
    return results;
  };
}

final _ayanamsaCalcProvider = Provider<CalcOutcome<List<AyanamsaCalcResult>>>((
  ref,
) {
  return runTabCalcWithOverrides(ref, compute: _ayanamsaCompute(ref));
});

final ayanamsaResultsProvider = Provider<CalcOutcome<List<AyanamsaCalcResult>>>(
  (ref) => ref.watch(_ayanamsaCalcProvider),
);

final ayanamsaSeriesProvider =
    Provider<List<(Moment, CalcOutcome<List<AyanamsaCalcResult>>)>>((ref) {
      return seriesStepsWithOverrides(
        ref,
        AppTab.ayanamsa.name,
        compute: () => _ayanamsaCompute(ref),
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
