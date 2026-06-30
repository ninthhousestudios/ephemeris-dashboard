import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/runner.dart';
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

/// Ayanamsa calculation results.
final ayanamsaResultsProvider = Provider<List<AyanamsaCalcResult>>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('ayanamsa')) return const [];

  final ectx = ref.watch(effectiveContextProvider);
  final ctx = ref.watch(contextBarProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  runner.setTabTag('ayanamsa');
  final selected = ref.watch(selectedAyanamsasProvider);
  final compareMode = ref.watch(ayanamsaCompareModeProvider);

  // Compare-all drops user-defined unless params have been set.
  final hasUserParams = ctx.userAyanT0 != 0.0 || ctx.userAyanValue != 0.0;
  final modes = compareMode
      ? ayanamsaModesFor(includeUser: hasUserParams).keys.toList()
      : selected;

  final results = <AyanamsaCalcResult>[];
  for (final sidMode in modes) {
    try {
      final value = runner.runScoped((eph) {
        if (sidMode == ayanamsaUserId) {
          eph.setSidMode(
            sidMode,
            t0: ctx.userAyanT0,
            ayanT0: ctx.userAyanValue,
          );
        } else {
          eph.setSidMode(sidMode);
        }
      }, (eph) => eph.getAyanamsaUt(ectx.jdUt));
      final name = ayanamsaName(sidMode);
      results.add(
        AyanamsaCalcResult(sidMode: sidMode, name: name, value: value),
      );
    } on SweException {
      // Skip failed modes.
    }
  }

  return results;
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
