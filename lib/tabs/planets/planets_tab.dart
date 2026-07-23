// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_selection.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/house_pos.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../widgets/body_display_controls.dart';
import '../../widgets/horizontal_fields.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import 'planets_provider.dart';

class PlanetsTab extends ConsumerStatefulWidget {
  const PlanetsTab({super.key});

  @override
  ConsumerState<PlanetsTab> createState() => _PlanetsTabState();
}

class _PlanetsTabState extends ConsumerState<PlanetsTab> {
  bool _showExtraBodies = false;

  void _toggleBody(int body) {
    final current = ref.read(selectedBodiesProvider);
    final updated = current.contains(body)
        ? current.where((b) => b != body).toList()
        : [...current, body];
    ref.read(selectedBodiesProvider.notifier).state = updated;
  }

  void _applyPreset(BodyPreset preset) {
    ref.read(selectedBodiesProvider.notifier).state = List.of(preset.bodies);
  }

  @override
  Widget build(BuildContext context) {
    final selectedBodies = ref.watch(selectedBodiesProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Row 1: Presets | divider | default body chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...bodyPresets.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ActionChip(
                      label: Text(p.label),
                      onPressed: () => _applyPreset(p),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(width: 16, color: theme.dividerColor),
                ),
                ...defaultBodies.map((body) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(_bodyLabel(body)),
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
        // ── Row 2: More bodies (progressive disclosure) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
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
                      'More bodies',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showExtraBodies) ...[
                const SizedBox(height: 4),
                // Chiron, Pholus, main asteroids, Earth, interp. apogee/perigee
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: extraBodies.map((body) {
                    return FilterChip(
                      label: Text(_bodyLabel(body)),
                      selected: selectedBodies.contains(body),
                      onSelected: (_) => _toggleBody(body),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                // Uranian section
                Text(
                  'Uranian',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: uranianBodies.map((body) {
                    return FilterChip(
                      label: Text(_bodyLabel(body)),
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
        // ── Series mode (with the house-position controls inline) ──
        SeriesBar(
          tabId: AppTab.planets.name,
          trailing: BodyDisplayControls(
            tabId: AppTab.planets.name,
            housePosToggle: planetsShowHousePosProvider,
            horizontalToggle: planetsShowHorizontalProvider,
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        if (ref.watch(
          seriesSettingsProvider(AppTab.planets.name).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          _buildResults(),
      ],
    );
  }

  /// The same calculation as [_buildResults], at N Moments instead of one.
  ///
  /// Every part of this is shared: the series comes from the kernel, the rows
  /// from the tab's own `planetsToExportRows` — unchanged, the same function
  /// the CSV export uses — and the surface from [SeriesView]. There is no
  /// Planets-specific grid.
  Widget _buildSeries() {
    final format = ref.watch(planetsFormatProvider);
    final flags = ref.watch(flagBarProvider);
    final utcOffset = ref.watch(contextBarProvider).utcOffset;
    final swe = ref.read(sweProvider);
    final steps = ref.watch(planetsSeriesProvider);

    List<ExportRow> rows(List<PlanetResult> results) => planetsToExportRows(
      results,
      format,
      isXyz: flags.isXyz,
      coordValue: flags.coordValue,
    );

    return SeriesView(
      tabId: AppTab.planets.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
      // A step whose UT could not be computed is a NaN Moment; formatting
      // falls back to the raw Julian Day rather than throwing.
      momentLabel: (m) => formatJdDateTime(
        swe,
        m.ut,
        utLabel: false,
        utcOffset: utcOffset,
        fallbackDigits: 4,
      ),
      momentColumnTitle: 'Date/Time (UT)',
    );
  }

  Widget _buildResults() {
    final format = ref.watch(planetsFormatProvider);
    final outcome = ref.watch(planetsResultsProvider);

    return switch (outcome) {
      CalcError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final results) =>
        results.isEmpty
            ? const Center(child: Text('No bodies selected'))
            : _buildResultCards(results, format),
    };
  }

  Widget _buildResultCards(List<PlanetResult> results, DisplayFormat format) {
    final flags = ref.watch(flagBarProvider);
    final isXyz = flags.isXyz;
    final lbl = coordLabels(flags.coordValue);
    final showHorizontal = ref.watch(planetsShowHorizontalProvider);

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
                      subtitle: 'calcUt(${r.body})',
                      flagHex:
                          '0x${r.returnFlag.toRadixString(16).toUpperCase()}',
                      fields: r.errorMessage != null
                          ? [
                              ResultField(
                                label: 'Error',
                                value: r.errorMessage!,
                              ),
                            ]
                          : [
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
                                  value: formatEuclidean(
                                    r.longitude,
                                    r.latitude,
                                    r.distance,
                                    format,
                                  ),
                                  rawValue: euclideanDistance(
                                    r.longitude,
                                    r.latitude,
                                    r.distance,
                                  ),
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
                              if (showHorizontal)
                                ...horizontalResultFields(r.horizontal, format),
                              if (r.houseRequested) ...[
                                ResultField(
                                  label: 'House',
                                  value: r.housePos.isNaN
                                      ? '—'
                                      : '${houseNumberOf(r.housePos)}',
                                  rawValue: houseNumberOf(
                                    r.housePos,
                                  ).toDouble(),
                                ),
                                ResultField(
                                  label: 'House Pos',
                                  value: r.housePos.isNaN
                                      ? '—'
                                      : formatAngle(
                                          housePositionDegrees(r.housePos),
                                          format,
                                        ),
                                  rawValue: housePositionDegrees(r.housePos),
                                ),
                              ],
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

/// Short label for a body constant.
String _bodyLabel(int body) {
  const names = {
    seSun: 'Sun',
    seMoon: 'Moon',
    seMercury: 'Mercury',
    seVenus: 'Venus',
    seMars: 'Mars',
    seJupiter: 'Jupiter',
    seSaturn: 'Saturn',
    seUranus: 'Uranus',
    seNeptune: 'Neptune',
    sePluto: 'Pluto',
    seMeanNode: 'M.Node',
    seTrueNode: 'T.Node',
    seMeanApog: 'M.Lilith',
    seOscuApog: 'O.Lilith',
    seEarth: 'Earth',
    seChiron: 'Chiron',
    sePholus: 'Pholus',
    seCeres: 'Ceres',
    sePallas: 'Pallas',
    seJuno: 'Juno',
    seVesta: 'Vesta',
    seIntpApog: 'I.Apogee',
    seIntpPerg: 'I.Perigee',
    seCupido: 'Cupido',
    seHades: 'Hades',
    seZeus: 'Zeus',
    seKronos: 'Kronos',
    seApollon: 'Apollon',
    seAdmetos: 'Admetos',
    seVulkanus: 'Vulkanus',
    sePoseidon: 'Poseidon',
  };
  if (names.containsKey(body)) return names[body]!;
  // Asteroid by MPC number?
  if (body >= seAstOffset) return '#${body - seAstOffset}';
  return 'Body $body';
}

class PlanetsFormatTrailing extends ConsumerWidget {
  const PlanetsFormatTrailing({super.key});

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
    final format = ref.watch(planetsFormatProvider);
    final outcome = ref.watch(planetsResultsProvider);
    final results = switch (outcome) {
      CalcOk(value: final v) => v,
      CalcError() => const <PlanetResult>[],
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
              ref.read(planetsFormatProvider.notifier).state = s.first,
          style: formatStyle,
        ),
        const SizedBox(width: 8),
        ExportButton(
          hasResults: results.isNotEmpty,
          getRows: () {
            final f = ref.read(flagBarProvider);
            return planetsToExportRows(
              results,
              format,
              isXyz: f.isXyz,
              coordValue: f.coordValue,
            );
          },
          filenameStem: 'swe_planets_${jd.toStringAsFixed(4)}',
          disabledTooltip: outcome is CalcError
              ? 'Export disabled: calculation error'
              : null,
        ),
      ],
    );
  }
}
