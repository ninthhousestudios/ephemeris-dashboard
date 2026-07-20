// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_selection.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephe/catalog.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'other_bodies_provider.dart';

class OtherBodiesTab extends ConsumerStatefulWidget {
  const OtherBodiesTab({super.key});

  @override
  ConsumerState<OtherBodiesTab> createState() => _OtherBodiesTabState();
}

class _OtherBodiesTabState extends ConsumerState<OtherBodiesTab> {
  bool _showMoons = false;
  bool _showAsteroids = false;
  bool _showComets = false;
  final _asteroidController = TextEditingController();
  final _cometController = TextEditingController();

  @override
  void dispose() {
    _asteroidController.dispose();
    _cometController.dispose();
    super.dispose();
  }

  void _toggleBody(int body) {
    final current = ref.read(otherBodiesSelectionProvider);
    final updated = current.contains(body)
        ? current.where((b) => b != body).toList()
        : [...current, body];
    ref.read(otherBodiesSelectionProvider.notifier).state = updated;
  }

  void _addAsteroid(int mpcNumber) {
    final bodyId = seAstOffset + mpcNumber;
    final current = ref.read(otherBodiesSelectionProvider);
    if (!current.contains(bodyId)) {
      ref.read(otherBodiesSelectionProvider.notifier).state = [
        ...current,
        bodyId,
      ];
    }
  }

  void _addComet(int pseudoMpc) {
    _addAsteroid(pseudoMpc);
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(otherBodiesSelectionProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                theme: theme,
                label: 'Planetary Moons',
                expanded: _showMoons,
                onToggle: () => setState(() => _showMoons = !_showMoons),
                child: _buildMoonSection(selected, theme),
              ),
              _buildSection(
                theme: theme,
                label: 'Asteroids',
                expanded: _showAsteroids,
                onToggle: () =>
                    setState(() => _showAsteroids = !_showAsteroids),
                child: _buildAsteroidSection(selected, theme),
              ),
              _buildSection(
                theme: theme,
                label: 'Comets',
                expanded: _showComets,
                onToggle: () => setState(() => _showComets = !_showComets),
                child: _buildCometSection(selected, theme),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
        _buildResults(),
      ],
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String label,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        InkWell(
          onTap: onToggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (expanded) ...[const SizedBox(height: 4), child],
      ],
    );
  }

  Widget _buildMoonSection(List<int> selected, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in planetaryMoonGroups) ...[
          Text(
            group.parent,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: group.moons.map((m) {
              return FilterChip(
                label: Text(m.name),
                selected: selected.contains(m.bodyId),
                onSelected: (_) => _toggleBody(m.bodyId),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildAsteroidSection(List<int> selected, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: otherBodiesNamedAsteroids.entries.map((e) {
            final bodyId = seAstOffset + e.key;
            return FilterChip(
              label: Text(e.value),
              selected: selected.contains(bodyId),
              onSelected: (_) {
                if (selected.contains(bodyId)) {
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
              width: (140 * MediaQuery.textScalerOf(context).scale(1.0))
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
      ],
    );
  }

  Widget _buildCometSection(List<int> selected, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: namedComets.entries.map((e) {
            final bodyId = seAstOffset + e.key;
            return FilterChip(
              label: Text(e.value),
              selected: selected.contains(bodyId),
              onSelected: (_) {
                if (selected.contains(bodyId)) {
                  _toggleBody(bodyId);
                } else {
                  _addComet(e.key);
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
              width: (140 * MediaQuery.textScalerOf(context).scale(1.0))
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
    );
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
      _addComet(num);
      _cometController.clear();
    }
  }

  Widget _buildResults() {
    final format = ref.watch(otherBodiesFormatProvider);
    final outcome = ref.watch(otherBodiesResultsProvider);

    return switch (outcome) {
      CalcSweError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final results) =>
        results.isEmpty
            ? const Center(child: Text('No bodies selected'))
            : _buildResultCards(results, format),
    };
  }

  Widget _buildResultCards(
    List<OtherBodyResult> results,
    DisplayFormat format,
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
                child: ResultCard(
                  title: r.bodyName,
                  subtitle: 'calcUt(${r.body})',
                  flagHex: '0x${r.returnFlag.toRadixString(16).toUpperCase()}',
                  fields: r.errorMessage != null
                      ? [ResultField(label: 'Error', value: r.errorMessage!)]
                      : [
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
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class OtherBodiesFormatTrailing extends ConsumerWidget {
  const OtherBodiesFormatTrailing({super.key});

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
    final format = ref.watch(otherBodiesFormatProvider);
    final outcome = ref.watch(otherBodiesResultsProvider);
    final results = switch (outcome) {
      CalcOk(value: final v) => v,
      CalcSweError() => const <OtherBodyResult>[],
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
              ref.read(otherBodiesFormatProvider.notifier).state = s.first,
          style: formatStyle,
        ),
        const SizedBox(width: 8),
        ExportButton(
          hasResults: results.isNotEmpty,
          getRows: () => otherBodiesToExportRows(results, format),
          filenameStem: 'swe_other_bodies_${jd.toStringAsFixed(4)}',
          disabledTooltip: outcome is CalcSweError
              ? 'Export disabled: calculation error'
              : null,
        ),
      ],
    );
  }
}
