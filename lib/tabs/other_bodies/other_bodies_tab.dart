// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_catalog.dart';
import '../../core/body_selection.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/house_pos.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephe/catalog.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/body_chips.dart';
import '../../widgets/body_display_controls.dart';
import '../../widgets/export_button.dart';
import '../../widgets/horizontal_fields.dart';
import '../../widgets/result_card.dart';
import '../../widgets/result_card_grid.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import 'other_bodies_provider.dart';

class OtherBodiesTab extends ConsumerStatefulWidget {
  const OtherBodiesTab({super.key});

  @override
  ConsumerState<OtherBodiesTab> createState() => _OtherBodiesTabState();
}

class _OtherBodiesTabState extends ConsumerState<OtherBodiesTab> {
  static const _selection = BodySelection.otherBodies;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              'Asteroids, comets, and planetary moons require ephemeris '
              'files which are only available on desktop.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Planetary Moons', theme),
              const SizedBox(height: 4),
              _buildMoonSection(theme),
              _sectionHeader('Asteroids', theme),
              const SizedBox(height: 4),
              _buildAsteroidSection(theme),
              _sectionHeader('Comets', theme),
              const SizedBox(height: 4),
              _buildCometSection(theme),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SeriesBar(
          tabId: AppTab.otherBodies.name,
          trailing: BodyDisplayControls(
            tabId: AppTab.otherBodies.name,
            housePosToggle: otherBodiesShowHousePosProvider,
            horizontalToggle: otherBodiesShowHorizontalProvider,
          ),
        ),
        const Divider(height: 1),
        if (ref.watch(
          seriesSettingsProvider(
            AppTab.otherBodies.name,
          ).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          _buildResults(),
      ],
    );
  }

  Widget _sectionHeader(String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMoonSection(ThemeData theme) {
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
          BodyChipWrap(
            selection: _selection,
            bodies: [for (final m in group.moons) m.bodyId],
            labels: {for (final m in group.moons) m.bodyId: m.name},
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildAsteroidSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  Widget _buildCometSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BodyChipWrap(
          selection: _selection,
          bodies: [
            for (final mpc in BodyCatalog.namedComets.keys) seAstOffset + mpc,
          ],
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
      _addAsteroid(num);
      _cometController.clear();
    }
  }

  Widget _buildSeries() {
    final format = ref.watch(otherBodiesFormatProvider);
    final flags = ref.watch(flagBarProvider);
    final steps = ref.watch(otherBodiesSeriesProvider);

    List<ExportRow> rows(List<OtherBodyResult> results) =>
        otherBodiesToExportRows(
          results,
          format,
          isXyz: flags.isXyz,
          coordValue: flags.coordValue,
        );

    return SeriesView(
      tabId: AppTab.otherBodies.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
    );
  }

  Widget _buildResults() {
    final format = ref.watch(otherBodiesFormatProvider);
    final outcome = ref.watch(otherBodiesResultsProvider);
    final results = switch (outcome) {
      CalcOk(:final value) => value,
      CalcError() => const <OtherBodyResult>[],
    };

    return ResultCardGrid<OtherBodyResult>.outcome(
      outcome: outcome,
      emptyMessage: 'No bodies selected',
      cardOverlay: (i) => IconButton(
        icon: const Icon(Icons.close, size: 16),
        tooltip: 'Remove ${results[i].bodyName}',
        visualDensity: VisualDensity.compact,
        onPressed: () => ref
            .read(bodySelectionProvider(_selection).notifier)
            .remove(results[i].body),
      ),
      cardBuilder: (r) => _buildCard(r, format),
    );
  }

  Widget _buildCard(OtherBodyResult r, DisplayFormat format) {
    final flags = ref.watch(flagBarProvider);
    final isXyz = flags.isXyz;
    final lbl = coordLabels(flags.coordValue);
    final showHorizontal = ref.watch(otherBodiesShowHorizontalProvider);

    return ResultCard(
      title: r.bodyName,
      subtitle: 'calcUt(${r.body})',
      flagHex: '0x${r.returnFlag.toRadixString(16).toUpperCase()}',
      fields: r.errorMessage != null
          ? [ResultField(label: 'Error', value: r.errorMessage!)]
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
                  rawValue: houseNumberOf(r.housePos).toDouble(),
                ),
                ResultField(
                  label: 'House Pos',
                  value: r.housePos.isNaN
                      ? '—'
                      : formatAngle(housePositionDegrees(r.housePos), format),
                  rawValue: housePositionDegrees(r.housePos),
                ),
              ],
            ],
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
      CalcError() => const <OtherBodyResult>[],
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
          getRows: () {
            final f = ref.read(flagBarProvider);
            return otherBodiesToExportRows(
              results,
              format,
              isXyz: f.isXyz,
              coordValue: f.coordValue,
            );
          },
          filenameStem: 'swe_other_bodies_${jd.toStringAsFixed(4)}',
          disabledTooltip: outcome is CalcError
              ? 'Export disabled: calculation error'
              : null,
        ),
      ],
    );
  }
}
