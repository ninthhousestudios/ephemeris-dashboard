// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_utils_provider.dart';
import '../../layout/tab_definitions.dart';
import '../../tabs/other_bodies/other_bodies_provider.dart'
    show otherBodiesNamedAsteroids, namedComets;
import '../../widgets/export_button.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import 'phenomena_provider.dart';

const _standardBodies = [
  (seSun, 'Sun'),
  (seMoon, 'Moon'),
  (seMercury, 'Mercury'),
  (seVenus, 'Venus'),
  (seMars, 'Mars'),
  (seJupiter, 'Jupiter'),
  (seSaturn, 'Saturn'),
];

const _outerBodies = [
  (seUranus, 'Uranus'),
  (seNeptune, 'Neptune'),
  (sePluto, 'Pluto'),
  (seChiron, 'Chiron'),
  (sePholus, 'Pholus'),
  (seCeres, 'Ceres'),
  (sePallas, 'Pallas'),
  (seJuno, 'Juno'),
  (seVesta, 'Vesta'),
];

const _uranianBodies = [
  (seCupido, 'Cupido'),
  (seHades, 'Hades'),
  (seZeus, 'Zeus'),
  (seKronos, 'Kronos'),
  (seApollon, 'Apollon'),
  (seAdmetos, 'Admetos'),
  (seVulkanus, 'Vulkanus'),
  (sePoseidon, 'Poseidon'),
];

class PhenomenaTab extends ConsumerStatefulWidget {
  const PhenomenaTab({super.key});

  @override
  ConsumerState<PhenomenaTab> createState() => _PhenomenaTabState();
}

class _PhenomenaTabState extends ConsumerState<PhenomenaTab> {
  bool _showExtra = false;
  final _asteroidController = TextEditingController();
  final _cometController = TextEditingController();

  @override
  void dispose() {
    _asteroidController.dispose();
    _cometController.dispose();
    super.dispose();
  }

  void _toggleBody(int body) {
    final current = ref.read(phenomenaBodiesProvider);
    final updated = current.contains(body)
        ? current.where((b) => b != body).toList()
        : [...current, body];
    ref.read(phenomenaBodiesProvider.notifier).state = updated;
  }

  void _addAsteroid(int mpcNumber) {
    final bodyId = seAstOffset + mpcNumber;
    final current = ref.read(phenomenaBodiesProvider);
    if (!current.contains(bodyId)) {
      ref.read(phenomenaBodiesProvider.notifier).state = [...current, bodyId];
    }
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
    final clockView = ref.watch(clockViewProvider);
    final swe = ref.read(sweProvider);
    final steps = ref.watch(phenomenaSeriesProvider);

    List<ExportRow> rows(List<PhenomenaResult> results) =>
        phenomenaToExportRows(results, format);

    return SeriesView(
      tabId: AppTab.phenomena.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
      momentLabel: (m) => formatJdDateTime(
        swe,
        m.ut,
        showLabel: false,
        view: clockView,
        fallbackDigits: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBodies = ref.watch(phenomenaBodiesProvider);
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
                ..._standardBodies.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(b.$2),
                      selected: selectedBodies.contains(b.$1),
                      onSelected: (_) => _toggleBody(b.$1),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
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
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _outerBodies
                      .map(
                        (b) => FilterChip(
                          label: Text(b.$2),
                          selected: selectedBodies.contains(b.$1),
                          onSelected: (_) => _toggleBody(b.$1),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                // Uranian hypothetical points
                Text('Uranian', style: labelStyle),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _uranianBodies
                      .map(
                        (b) => FilterChip(
                          label: Text(b.$2),
                          selected: selectedBodies.contains(b.$1),
                          onSelected: (_) => _toggleBody(b.$1),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 8),
                  // Asteroids
                  Text('Asteroids', style: labelStyle),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: otherBodiesNamedAsteroids.entries.map((e) {
                      final bodyId = seAstOffset + e.key;
                      return FilterChip(
                        label: Text(e.value),
                        selected: selectedBodies.contains(bodyId),
                        onSelected: (_) {
                          if (selectedBodies.contains(bodyId)) {
                            _toggleBody(bodyId);
                          } else {
                            _addAsteroid(e.key);
                          }
                        },
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
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
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: namedComets.entries.map((e) {
                      final bodyId = seAstOffset + e.key;
                      return FilterChip(
                        label: Text(e.value),
                        selected: selectedBodies.contains(bodyId),
                        onSelected: (_) {
                          if (selectedBodies.contains(bodyId)) {
                            _toggleBody(bodyId);
                          } else {
                            _addAsteroid(e.key);
                          }
                        },
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
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

    return switch (outcome) {
      CalcError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final results) =>
        results.isEmpty
            ? const Center(child: Text('No bodies selected'))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 1200
                      ? 3
                      : constraints.maxWidth > 600
                      ? 2
                      : 1;
                  final cardWidth =
                      (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;
                  // One label/value source for cards and export alike — see
                  // phenomenaSections. Zipped 1:1 with results (same order,
                  // same length) so the close button can still key off body id.
                  final sections = phenomenaSections(results, format);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (var i = 0; i < results.length; i++)
                          SizedBox(
                            width: cardWidth,
                            child: Stack(
                              children: [
                                sections[i].toCard(),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    tooltip: 'Remove ${results[i].bodyName}',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      final current = ref.read(
                                        phenomenaBodiesProvider,
                                      );
                                      ref
                                          .read(
                                            phenomenaBodiesProvider.notifier,
                                          )
                                          .state = current
                                          .where((b) => b != results[i].body)
                                          .toList();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
    };
  }
}
