// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';
import '../../core/body_catalog.dart';
import '../../core/body_selection.dart';
import '../../widgets/body_chips.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card_grid.dart';
import '../../widgets/result_section.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import 'phenomena_provider.dart';

class PhenomenaTab extends ConsumerStatefulWidget {
  const PhenomenaTab({super.key});

  @override
  ConsumerState<PhenomenaTab> createState() => _PhenomenaTabState();
}

class _PhenomenaTabState extends ConsumerState<PhenomenaTab> {
  static const _selection = BodySelection.phenomenaBodies;

  /// Outer planets plus the centaurs and minors — the second-row chips.
  static const _outerBodies = <int>[
    ...BodyCatalog.outers,
    ...BodyCatalog.centaursAndMinors,
  ];

  bool _showExtra = false;
  final _asteroidController = TextEditingController();
  final _cometController = TextEditingController();

  @override
  void dispose() {
    _asteroidController.dispose();
    _cometController.dispose();
    super.dispose();
  }

  void _addAsteroid(int mpcNumber) {
    ref
        .read(bodySelectionProvider(_selection).notifier)
        .add(seAstOffset + mpcNumber);
  }

  void _addCustomAsteroid() {
    final text = _asteroidController.text.trim();
    final num = int.tryParse(text);
    if (num != null && num > 0) {
      _addAsteroid(num);
      _asteroidController.clear();
    }
  }

  void _addCustomComet() {
    final text = _cometController.text.trim();
    final num = int.tryParse(text);
    if (num != null && num > 0) {
      _addAsteroid(num);
      _cometController.clear();
    }
  }

  Widget _buildSeries() {
    final format = ref.watch(phenomenaFormatProvider);
    final steps = ref.watch(phenomenaSeriesProvider);

    List<ExportRow> rows(List<PhenomenaResult> results) =>
        phenomenaToExportRows(results, format);

    return SeriesView(
      tabId: AppTab.phenomena.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(phenomenaFormatProvider);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Body chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Bodies ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ...bodyChipRow(_selection, BodyCatalog.classical),
              ],
            ),
          ),
        ),
        // ── Progressive disclosure: more bodies ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _showExtra = !_showExtra),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showExtra ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text('More bodies', style: labelStyle),
                  ],
                ),
              ),
              if (_showExtra) ...[
                const SizedBox(height: 4),
                // Outer planets + minor planets
                const BodyChipWrap(selection: _selection, bodies: _outerBodies),
                const SizedBox(height: 8),
                // Uranian hypothetical points
                Text('Uranian', style: labelStyle),
                const SizedBox(height: 4),
                const BodyChipWrap(
                  selection: _selection,
                  bodies: BodyCatalog.uranian,
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 8),
                  // Asteroids
                  Text('Asteroids', style: labelStyle),
                  const SizedBox(height: 4),
                  BodyChipWrap(
                    selection: _selection,
                    bodies: [
                      for (final mpc in BodyCatalog.namedAsteroids.keys)
                        seAstOffset + mpc,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width:
                            (140 * MediaQuery.textScalerOf(context).scale(1.0))
                                .floorToDouble(),
                        child: TextField(
                          controller: _asteroidController,
                          decoration: const InputDecoration(
                            hintText: 'MPC #',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onSubmitted: (_) => _addCustomAsteroid(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: 'Add asteroid by MPC number',
                        onPressed: _addCustomAsteroid,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Comets
                  Text('Comets', style: labelStyle),
                  const SizedBox(height: 4),
                  BodyChipWrap(
                    selection: _selection,
                    bodies: [
                      for (final mpc in BodyCatalog.namedComets.keys)
                        seAstOffset + mpc,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width:
                            (140 * MediaQuery.textScalerOf(context).scale(1.0))
                                .floorToDouble(),
                        child: TextField(
                          controller: _cometController,
                          decoration: const InputDecoration(
                            hintText: 'Pseudo-MPC #',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onSubmitted: (_) => _addCustomComet(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: 'Add comet by pseudo-MPC number',
                        onPressed: _addCustomComet,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        // ── Format + export ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SegmentedButton<DisplayFormat>(
                  segments: DisplayFormat.values
                      .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                      .toList(),
                  selected: {fmt},
                  onSelectionChanged: (s) =>
                      ref.read(phenomenaFormatProvider.notifier).state =
                          s.first,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final outcome = ref.watch(phenomenaResultsProvider);
                    final format = ref.watch(phenomenaFormatProvider);
                    final jd = ref.watch(contextBarProvider).jdUt;
                    return ExportButton(
                      hasResults:
                          outcome is CalcOk<List<PhenomenaResult>> &&
                          outcome.value.isNotEmpty,
                      getRows: () => switch (outcome) {
                        CalcOk(value: final results) => phenomenaToExportRows(
                          results,
                          format,
                        ),
                        CalcError() => [],
                      },
                      filenameStem: 'swe_phenomena_${jd.toStringAsFixed(4)}',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SeriesBar(tabId: AppTab.phenomena.name),
        const Divider(height: 1),
        // ── Results ──
        if (ref.watch(
          seriesSettingsProvider(
            AppTab.phenomena.name,
          ).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          const _ResultsView(),
      ],
    );
  }
}

class _ResultsView extends ConsumerWidget {
  const _ResultsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(phenomenaFormatProvider);
    final outcome = ref.watch(phenomenaResultsProvider);

    final results = switch (outcome) {
      CalcOk(:final value) => value,
      CalcError() => const <PhenomenaResult>[],
    };
    // One label/value source for cards and export alike — see
    // phenomenaSections. Zipped 1:1 with results (same order, same length) so
    // the close button can still key off body id.
    return ResultCardGrid<ResultSection>.outcome(
      outcome: outcome.map((rows) => phenomenaSections(rows, format)),
      emptyMessage: 'No bodies selected',
      cardOverlay: (i) => IconButton(
        icon: const Icon(Icons.close, size: 16),
        tooltip: 'Remove ${results[i].bodyName}',
        visualDensity: VisualDensity.compact,
        onPressed: () => ref
            .read(bodySelectionProvider(BodySelection.phenomenaBodies).notifier)
            .remove(results[i].body),
      ),
      cardBuilder: (section) => section.toCard(),
    );
  }
}
