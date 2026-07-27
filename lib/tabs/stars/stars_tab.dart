// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/house_pos.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/body_display_controls.dart';
import '../../widgets/export_button.dart';
import '../../widgets/horizontal_fields.dart';
import '../../widgets/result_card.dart';
import '../../widgets/result_card_grid.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import '../../widgets/star_search_field.dart';
import 'stars_provider.dart';

class StarsTab extends ConsumerStatefulWidget {
  const StarsTab({super.key});

  @override
  ConsumerState<StarsTab> createState() => _StarsTabState();
}

class _StarsTabState extends ConsumerState<StarsTab> {
  void _addStar(String name) {
    final current = ref.read(selectedStarsProvider);
    if (!current.contains(name)) {
      ref.read(selectedStarsProvider.notifier).state = [...current, name];
    }
    ref.read(starSearchProvider.notifier).state = '';
  }

  void _removeStar(String name) {
    final current = ref.read(selectedStarsProvider);
    ref.read(selectedStarsProvider.notifier).state = current
        .where((s) => s != name)
        .toList();
  }

  void _toggleStarPreset(String name) {
    final current = ref.read(selectedStarsProvider);
    if (current.contains(name)) {
      _removeStar(name);
    } else {
      ref.read(selectedStarsProvider.notifier).state = [...current, name];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = ref.watch(starsFormatProvider);
    final selectedStars = ref.watch(selectedStarsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Star name input row with suggestions ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text('Star ', style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              Expanded(child: StarSearchField(onSelect: _addStar)),
            ],
          ),
        ),
        // ── Format + export row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
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
                      ref.read(starsFormatProvider.notifier).state = s.first,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final outcome = ref.watch(starResultProvider);
                    final fmt2 = ref.watch(starsFormatProvider);
                    final results = switch (outcome) {
                      CalcOk(value: final r) => r,
                      CalcError() => const <StarResult>[],
                    };
                    return ExportButton(
                      hasResults: results.isNotEmpty,
                      getRows: () {
                        final f = ref.read(flagBarProvider);
                        return starToExportRows(
                          results,
                          fmt2,
                          isXyz: f.isXyz,
                          coordValue: f.coordValue,
                        );
                      },
                      filenameStem: 'swe_stars',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // ── Preset star chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: commonStars.map((name) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FilterChip(
                    label: Text(name),
                    selected: selectedStars.contains(name),
                    onSelected: (_) => _toggleStarPreset(name),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        SeriesBar(
          tabId: AppTab.stars.name,
          trailing: BodyDisplayControls(
            tabId: AppTab.stars.name,
            housePosToggle: starsShowHousePosProvider,
            horizontalToggle: starsShowHorizontalProvider,
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        if (ref.watch(
          seriesSettingsProvider(AppTab.stars.name).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          _buildResults(),
      ],
    );
  }

  Widget _buildSeries() {
    final fmt = ref.watch(starsFormatProvider);
    final flags = ref.watch(flagBarProvider);
    final steps = ref.watch(starsSeriesProvider);

    List<ExportRow> rows(List<StarResult> results) => starToExportRows(
      results,
      fmt,
      isXyz: flags.isXyz,
      coordValue: flags.coordValue,
    );

    return SeriesView(
      tabId: AppTab.stars.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
    );
  }

  Widget _buildResults() {
    final outcome = ref.watch(starResultProvider);
    final fmt = ref.watch(starsFormatProvider);
    final results = switch (outcome) {
      CalcOk(:final value) => value,
      CalcError() => const <StarResult>[],
    };

    return ResultCardGrid<StarResult>.outcome(
      outcome: outcome,
      emptyMessage: 'No stars selected',
      cardOverlay: (i) => IconButton(
        icon: const Icon(Icons.close, size: 16),
        tooltip: 'Remove ${results[i].resolvedName}',
        visualDensity: VisualDensity.compact,
        onPressed: () => _removeStar(results[i].searchTerm),
      ),
      cardBuilder: (r) => _buildCard(r, fmt),
    );
  }

  Widget _buildCard(StarResult r, DisplayFormat fmt) {
    final flags = ref.watch(flagBarProvider);
    final isXyz = flags.isXyz;
    final lbl = coordLabels(flags.coordValue);
    final showHorizontal = ref.watch(starsShowHorizontalProvider);

    return ResultCard(
      title: r.resolvedName,
      subtitle: 'fixstar2Ut("${r.searchTerm}")',
      flagHex: '0x${r.returnFlag.toRadixString(16).toUpperCase()}',
      fields: r.errorMessage != null
          ? [ResultField(label: 'Error', value: r.errorMessage!)]
          : [
              ResultField(
                label: lbl.c1,
                value: isXyz
                    ? formatAu(r.longitude, fmt)
                    : formatAngle(r.longitude, fmt),
                rawValue: r.longitude,
              ),
              ResultField(
                label: lbl.c2,
                value: isXyz
                    ? formatAu(r.latitude, fmt)
                    : formatAngle(r.latitude, fmt),
                rawValue: r.latitude,
              ),
              ResultField(
                label: lbl.c3,
                value: isXyz
                    ? formatAu(r.distance, fmt)
                    : formatDistance(r.distance, fmt),
                rawValue: r.distance,
              ),
              if (isXyz)
                ResultField(
                  label: 'Distance',
                  value: formatEuclidean(
                    r.longitude,
                    r.latitude,
                    r.distance,
                    fmt,
                    lightYears: true,
                  ),
                  rawValue: euclideanDistance(
                    r.longitude,
                    r.latitude,
                    r.distance,
                  ),
                ),
              ResultField(
                label: 'Magnitude',
                value: r.magnitude.isNaN ? '—' : r.magnitude.toStringAsFixed(2),
                rawValue: r.magnitude,
              ),
              ResultField(
                label: lbl.sc1,
                value: isXyz
                    ? formatAuSpeed(r.speedLon, fmt)
                    : formatSpeed(r.speedLon, fmt),
                rawValue: r.speedLon,
              ),
              ResultField(
                label: lbl.sc2,
                value: isXyz
                    ? formatAuSpeed(r.speedLat, fmt)
                    : formatSpeed(r.speedLat, fmt),
                rawValue: r.speedLat,
              ),
              ResultField(
                label: lbl.sc3,
                value: isXyz
                    ? formatAuSpeed(r.speedDist, fmt)
                    : formatSpeed(r.speedDist, fmt),
                rawValue: r.speedDist,
              ),
              if (showHorizontal) ...horizontalResultFields(r.horizontal, fmt),
              if (r.houseRequested) ...[
                ResultField(
                  label: 'House',
                  value: r.housePos.isNaN
                      ? '—'
                      : '${houseNumberOf(r.housePos)}',
                  rawValue: houseNumberOf(r.housePos).toDouble(),
                ),
                ResultField(
                  label: 'House Pos',
                  value: r.housePos.isNaN
                      ? '—'
                      : formatAngle(housePositionDegrees(r.housePos), fmt),
                  rawValue: housePositionDegrees(r.housePos),
                ),
              ],
            ],
    );
  }
}
