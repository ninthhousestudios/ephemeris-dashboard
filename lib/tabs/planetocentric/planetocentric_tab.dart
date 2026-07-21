// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/swe_service.dart';
import '../../core/swe_utils.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'planetocentric_provider.dart';

class PlanetoCentricTab extends ConsumerStatefulWidget {
  const PlanetoCentricTab({super.key});

  @override
  ConsumerState<PlanetoCentricTab> createState() => _PlanetoCentricTabState();
}

class _PlanetoCentricTabState extends ConsumerState<PlanetoCentricTab> {
  bool _showExtraBodies = false;

  void _toggleBody(int body) {
    final current = ref.read(planetocentricBodiesProvider);
    final updated = current.contains(body)
        ? current.where((b) => b != body).toList()
        : [...current, body];
    ref.read(planetocentricBodiesProvider.notifier).state = updated;
  }

  @override
  Widget build(BuildContext context) {
    final selectedBodies = ref.watch(planetocentricBodiesProvider);
    final center = ref.watch(planetocentricCenterProvider);
    final swe = ref.read(sweProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Row 1: Center body selector ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Center:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                ...centerBodies.map((body) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(_bodyLabel(swe, body)),
                      selected: center == body,
                      onSelected: (_) =>
                          ref
                                  .read(planetocentricCenterProvider.notifier)
                                  .state =
                              body,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        // ── Row 2: Target body chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Targets:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                ...defaultTargetBodies.map((body) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(_bodyLabel(swe, body)),
                      selected: selectedBodies.contains(body),
                      onSelected: (_) => _toggleBody(body),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        // ── Row 3: Extra bodies (progressive disclosure) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _showExtraBodies = !_showExtraBodies),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showExtraBodies ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'More targets',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showExtraBodies) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: extraTargetBodies.map((body) {
                    return FilterChip(
                      label: Text(_bodyLabel(swe, body)),
                      selected: selectedBodies.contains(body),
                      onSelected: (_) => _toggleBody(body),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
        // ── Results ──
        _buildResults(),
      ],
    );
  }

  Widget _buildResults() {
    final format = ref.watch(planetocentricFormatProvider);
    final outcome = ref.watch(planetocentricResultsProvider);

    return switch (outcome) {
      CalcSweError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final results) =>
        results.isEmpty
            ? const Center(child: Text('No target bodies selected'))
            : _buildResultCards(format, results),
    };
  }

  Widget _buildResultCards(
    DisplayFormat format,
    List<PlanetoCentricResult> results,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: results.map((r) {
              return SizedBox(
                width: cardWidth,
                child: Stack(
                  children: [
                    ResultCard(
                      title: r.bodyName,
                      subtitle: 'calcPctr(${r.body}, ${r.centerBody})',
                      flagHex:
                          '0x${r.returnFlag.toRadixString(16).toUpperCase()}',
                      fields: [
                        ResultField(
                          label: 'Longitude',
                          value: formatAngle(r.longitude, format),
                          rawValue: r.longitude,
                        ),
                        ResultField(
                          label: 'Latitude',
                          value: formatAngle(r.latitude, format),
                          rawValue: r.latitude,
                        ),
                        ResultField(
                          label: 'Distance',
                          value: formatDistance(r.distance, format),
                          rawValue: r.distance,
                        ),
                        ResultField(
                          label: 'Spd Lon',
                          value: formatSpeed(r.speedLon, format),
                          rawValue: r.speedLon,
                        ),
                        ResultField(
                          label: 'Spd Lat',
                          value: formatSpeed(r.speedLat, format),
                          rawValue: r.speedLat,
                        ),
                        ResultField(
                          label: 'Spd Dist',
                          value: formatSpeed(r.speedDist, format),
                          rawValue: r.speedDist,
                        ),
                      ],
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Remove ${r.bodyName}',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _toggleBody(r.body),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

String _bodyLabel(SweUtils swe, int body) {
  try {
    return swe.getPlanetName(body);
  } catch (_) {
    return 'Body $body';
  }
}

class PlanetoCentricFormatTrailing extends ConsumerWidget {
  const PlanetoCentricFormatTrailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelSmall),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    );
    final format = ref.watch(planetocentricFormatProvider);
    final outcome = ref.watch(planetocentricResultsProvider);
    final results = switch (outcome) {
      CalcOk(value: final v) => v,
      CalcSweError() => const <PlanetoCentricResult>[],
    };
    final jd = ref.watch(contextBarProvider).jdUt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<DisplayFormat>(
          segments: DisplayFormat.values
              .map((f) => ButtonSegment(value: f, label: Text(f.label)))
              .toList(),
          selected: {format},
          onSelectionChanged: (s) =>
              ref.read(planetocentricFormatProvider.notifier).state = s.first,
          style: formatStyle,
        ),
        const SizedBox(width: 8),
        ExportButton(
          hasResults: results.isNotEmpty,
          getRows: () => planetocentricToExportRows(results, format),
          filenameStem: 'swe_planetocentric_${jd.toStringAsFixed(4)}',
        ),
      ],
    );
  }
}
