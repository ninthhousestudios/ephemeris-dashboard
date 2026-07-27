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
import '../../core/ephe/catalog.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_utils_provider.dart';
import '../../core/swe_utils.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../../widgets/result_card_grid.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import 'planetocentric_provider.dart';

class PlanetoCentricTab extends ConsumerStatefulWidget {
  const PlanetoCentricTab({super.key});

  @override
  ConsumerState<PlanetoCentricTab> createState() => _PlanetoCentricTabState();
}

class _PlanetoCentricTabState extends ConsumerState<PlanetoCentricTab> {
  static const _center = BodySelection.planetocentricCenter;
  static const _targets = BodySelection.planetocentricBodies;

  /// Bodies that can be the observer. The Moon is absent — `calcPctr` wants a
  /// planetary center.
  static const _centerBodies = <int>[
    seSun,
    seMercury,
    seVenus,
    seEarth,
    seMars,
    seJupiter,
    seSaturn,
    ...BodyCatalog.outers,
  ];

  static const _defaultTargets = <int>[
    ...BodyCatalog.classical,
    ...BodyCatalog.outers,
  ];

  /// Only real physical bodies — mathematical points (nodes, apogees) have no
  /// heliocentric position and cannot be used with `calcPctr`.
  static const _extraTargets = <int>[
    seEarth,
    ...BodyCatalog.centaursAndMinors,
    ...BodyCatalog.uranian,
  ];

  bool _showExtraBodies = false;
  final _asteroidController = TextEditingController();

  @override
  void dispose() {
    _asteroidController.dispose();
    super.dispose();
  }

  void _addAsteroid(int mpcNumber) {
    ref
        .read(bodySelectionProvider(_targets).notifier)
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

  @override
  Widget build(BuildContext context) {
    final center = ref.watch(singleBodyProvider(_center));
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
                ..._centerBodies.map((body) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(_bodyLabel(swe, body)),
                      selected: center == body,
                      onSelected: (_) => ref
                          .read(bodySelectionProvider(_center).notifier)
                          .setSingle(body),
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
                ..._defaultTargets.map(
                  (body) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: BodyChip(
                      selection: _targets,
                      body: body,
                      label: _bodyLabel(swe, body),
                    ),
                  ),
                ),
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
                BodyChipWrap(
                  selection: _targets,
                  bodies: _extraTargets,
                  labels: {
                    for (final b in _extraTargets) b: _bodyLabel(swe, b),
                  },
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Asteroids',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  BodyChipWrap(
                    selection: _targets,
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
                  Text(
                    'Planetary Moons',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final group in planetaryMoonGroups) ...[
                    Text(
                      group.parent,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    BodyChipWrap(
                      selection: _targets,
                      bodies: [for (final m in group.moons) m.bodyId],
                      labels: {for (final m in group.moons) m.bodyId: m.name},
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        SeriesBar(tabId: AppTab.planetocentric.name),
        const Divider(height: 1),
        // ── Results ──
        if (ref.watch(
          seriesSettingsProvider(
            AppTab.planetocentric.name,
          ).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          _buildResults(),
      ],
    );
  }

  Widget _buildSeries() {
    final format = ref.watch(planetocentricFormatProvider);
    final flags = ref.watch(flagBarProvider);
    final steps = ref.watch(planetocentricSeriesProvider);

    List<ExportRow> rows(List<PlanetoCentricResult> results) =>
        planetocentricToExportRows(
          results,
          format,
          isXyz: flags.isXyz,
          coordValue: flags.coordValue,
        );

    return SeriesView(
      tabId: AppTab.planetocentric.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
    );
  }

  Widget _buildResults() {
    final format = ref.watch(planetocentricFormatProvider);
    final outcome = ref.watch(planetocentricResultsProvider);

    final results = switch (outcome) {
      CalcOk(:final value) => value,
      CalcError() => const <PlanetoCentricResult>[],
    };

    return ResultCardGrid<PlanetoCentricResult>.outcome(
      outcome: outcome,
      emptyMessage: 'No target bodies selected',
      cardOverlay: (i) => IconButton(
        icon: const Icon(Icons.close, size: 16),
        tooltip: 'Remove ${results[i].bodyName}',
        visualDensity: VisualDensity.compact,
        onPressed: () => ref
            .read(bodySelectionProvider(_targets).notifier)
            .remove(results[i].body),
      ),
      cardBuilder: (r) => _buildCard(r, format),
    );
  }

  Widget _buildCard(PlanetoCentricResult r, DisplayFormat format) {
    final flags = ref.watch(flagBarProvider);
    final isXyz = flags.isXyz;
    final lbl = coordLabels(flags.coordValue);

    return ResultCard(
      title: r.bodyName,
      subtitle: 'calcPctr(${r.body}, ${r.centerBody})',
      flagHex: '0x${r.returnFlag.toRadixString(16).toUpperCase()}',
      fields: [
        ResultField(
          label: lbl.c1,
          value: isXyz
              ? formatAu(r.longitude, format)
              : formatAngle(r.longitude, format),
          rawValue: r.longitude,
        ),
        ResultField(
          label: lbl.c2,
          value: isXyz
              ? formatAu(r.latitude, format)
              : formatAngle(r.latitude, format),
          rawValue: r.latitude,
        ),
        ResultField(
          label: lbl.c3,
          value: isXyz
              ? formatAu(r.distance, format)
              : formatDistance(r.distance, format),
          rawValue: r.distance,
        ),
        if (isXyz)
          ResultField(
            label: 'Distance',
            value: formatEuclidean(r.longitude, r.latitude, r.distance, format),
            rawValue: euclideanDistance(r.longitude, r.latitude, r.distance),
          ),
        ResultField(
          label: lbl.sc1,
          value: isXyz
              ? formatAuSpeed(r.speedLon, format)
              : formatSpeed(r.speedLon, format),
          rawValue: r.speedLon,
        ),
        ResultField(
          label: lbl.sc2,
          value: isXyz
              ? formatAuSpeed(r.speedLat, format)
              : formatSpeed(r.speedLat, format),
          rawValue: r.speedLat,
        ),
        ResultField(
          label: lbl.sc3,
          value: isXyz
              ? formatAuSpeed(r.speedDist, format)
              : formatSpeed(r.speedDist, format),
          rawValue: r.speedDist,
        ),
      ],
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
      CalcError() => const <PlanetoCentricResult>[],
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
          getRows: () {
            final f = ref.read(flagBarProvider);
            return planetocentricToExportRows(
              results,
              format,
              isXyz: f.isXyz,
              coordValue: f.coordValue,
            );
          },
          filenameStem: 'swe_planetocentric_${jd.toStringAsFixed(4)}',
        ),
      ],
    );
  }
}
