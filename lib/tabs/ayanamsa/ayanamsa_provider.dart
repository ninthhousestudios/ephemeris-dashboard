// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/applied_globals.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/swe_constants.dart' show SweException;
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

/// One user-defined ayanamsha (SE_SIDM_USER, 255) on the Ayanamsa tab.
///
/// The tab supports an arbitrary number of these, each independently editable
/// and removable — distinct from the single context-bar user-defined ayanamsha
/// that drives chart calculations on every other tab.
class UserAyanamsa {
  const UserAyanamsa({
    required this.id,
    this.t0 = 2451545.0, // J2000
    this.value = 0.0,
    this.t0IsUt = false,
  });

  final int id;
  final double t0; // reference Julian Day
  final double value; // ayanamsha at t0, degrees
  final bool t0IsUt; // SE_SIDBIT_USER_UT (jdisut)

  UserAyanamsa copyWith({double? t0, double? value, bool? t0IsUt}) =>
      UserAyanamsa(
        id: id,
        t0: t0 ?? this.t0,
        value: value ?? this.value,
        t0IsUt: t0IsUt ?? this.t0IsUt,
      );
}

class UserAyanamsaNotifier extends StateNotifier<List<UserAyanamsa>> {
  UserAyanamsaNotifier() : super(const []);

  int _nextId = 0;

  void add() {
    state = [...state, UserAyanamsa(id: _nextId++)];
  }

  void removeById(int id) {
    state = state.where((u) => u.id != id).toList();
  }

  void update(int id, {double? t0, double? value, bool? t0IsUt}) {
    state = [
      for (final u in state)
        if (u.id == id) u.copyWith(t0: t0, value: value, t0IsUt: t0IsUt) else u,
    ];
  }
}

/// User-defined ayanamsha entries shown on the Ayanamsa tab.
final userAyanamsasProvider =
    StateNotifierProvider<UserAyanamsaNotifier, List<UserAyanamsa>>(
      (ref) => UserAyanamsaNotifier(),
    );

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
        final mode = u.t0IsUt
            ? (ayanamsaUserId | userAyanUtBit)
            : ayanamsaUserId;
        reconfigure(baseGlobals.withSidMode(mode, t0: u.t0, ayanT0: u.value));
        results.add(
          AyanamsaCalcResult(
            sidMode: ayanamsaUserId,
            userId: u.id,
            name: 'User-defined ${i + 1}',
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
      ref.watch(
        seriesSettingsProvider(
          AppTab.ayanamsa.name,
        ).select((s) => (s.enabled, s.stepValue, s.stepUnit, s.rowCount)),
      );
      final settings = ref.read(seriesSettingsProvider(AppTab.ayanamsa.name));
      if (!settings.enabled) return const [];
      return runTabCalcSeriesWithOverrides(
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
