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
import '../../core/flag_provider.dart';
import '../../core/sign_names.dart';
import '../../core/swe_utils_provider.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../../widgets/result_card_grid.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import 'nodes_apsides_provider.dart';

// Values are NodApsMethod bitflags (seNodBit*), passed untranslated through the
// Ephemeris seam — MEAN=1, OSCU=2, OSCU_BAR=4, not dense 0/1/2 indices. The
// engine treats method 0 (empty) as MEAN, so using 0 for "Mean" made it and
// "Osculating" (which was 1 == the MEAN bit) compute identical mean nodes.
const _methodOptions = <(int, String)>[
  (seNodBitMean, 'Mean'),
  (seNodBitOscu, 'Osculating'),
  (seNodBitOscuBar, 'Oscu Bary'),
];

class NodesApsidesTab extends ConsumerStatefulWidget {
  const NodesApsidesTab({super.key});

  @override
  ConsumerState<NodesApsidesTab> createState() => _NodesApsidesTabState();
}

class _NodesApsidesTabState extends ConsumerState<NodesApsidesTab> {
  static const _selection = BodySelection.nodesApsidesBody;

  /// Bodies with a meaningful node/apse. The lunar points are absent — the
  /// nodes of a node are not a quantity.
  static const _defaultBodies = <int>[
    ...BodyCatalog.classical,
    ...BodyCatalog.outers,
  ];

  static const _extraBodies = <int>[seEarth, ...BodyCatalog.centaursAndMinors];

  bool _showExtraBodies = false;
  final _asteroidController = TextEditingController();

  @override
  void dispose() {
    _asteroidController.dispose();
    super.dispose();
  }

  void _selectAsteroid(int mpcNumber) {
    ref
        .read(bodySelectionProvider(_selection).notifier)
        .setSingle(seAstOffset + mpcNumber);
  }

  void _selectCustomAsteroid() {
    final text = _asteroidController.text.trim();
    final num = int.tryParse(text);
    if (num != null && num > 0) {
      _selectAsteroid(num);
      _asteroidController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = ref.watch(nodesMethodProvider);
    final fmt = ref.watch(nodesFormatProvider);
    final jd = ref.watch(contextBarProvider).jdUt;
    final nodesOutcome = ref.watch(nodesApsResultsProvider);
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
                Text('Body ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ...bodyChoiceChipRow(_selection, _defaultBodies),
              ],
            ),
          ),
        ),
        // ── Progressive disclosure: extra bodies ──
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
                    Text('More bodies', style: labelStyle),
                  ],
                ),
              ),
              if (_showExtraBodies) ...[
                const SizedBox(height: 4),
                const BodyChoiceChipWrap(
                  selection: _selection,
                  bodies: _extraBodies,
                ),
                if (!kIsWeb) ...[
                  const SizedBox(height: 8),
                  Text('Asteroids', style: labelStyle),
                  const SizedBox(height: 4),
                  BodyChoiceChipWrap(
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
                          onSubmitted: (_) => _selectCustomAsteroid(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: 'Add asteroid by MPC number',
                        onPressed: _selectCustomAsteroid,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        // ── Method chips + format + export ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Method ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ..._methodOptions.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(m.$2),
                      selected: method == m.$1,
                      onSelected: (_) =>
                          ref.read(nodesMethodProvider.notifier).state = m.$1,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<DisplayFormat>(
                  segments: DisplayFormat.values
                      .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                      .toList(),
                  selected: {fmt},
                  onSelectionChanged: (s) =>
                      ref.read(nodesFormatProvider.notifier).state = s.first,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                ExportButton(
                  hasResults: nodesOutcome is CalcOk<NodesApsResult>,
                  getRows: () {
                    final f = ref.read(flagBarProvider);
                    final signs = ref.read(resolvedSignNamesProvider);
                    return switch (nodesOutcome) {
                      CalcOk(value: final result) => nodesApsToExportRows(
                        result,
                        ref.read(nodesFormatProvider),
                        ref.read(sweProvider),
                        ref.read(clockViewProvider).scale,
                        isXyz: f.isXyz,
                        coordValue: f.coordValue,
                        scheme: signs.scheme,
                        signSet: signs.set,
                        binning: signs.binning,
                      ),
                      CalcError() => [],
                    };
                  },
                  filenameStem: 'swe_nodes_apsides_${jd.toStringAsFixed(4)}',
                ),
              ],
            ),
          ),
        ),
        SeriesBar(tabId: AppTab.nodesApsides.name),
        const Divider(height: 1),
        // ── Results ──
        if (ref.watch(
          seriesSettingsProvider(
            AppTab.nodesApsides.name,
          ).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          const _NodesResults(),
      ],
    );
  }

  Widget _buildSeries() {
    final format = ref.watch(nodesFormatProvider);
    final flags = ref.watch(flagBarProvider);
    final steps = ref.watch(nodesApsSeriesProvider);

    final swe = ref.read(sweProvider);
    final scale = ref.watch(clockViewProvider).scale;
    final signs = ref.watch(resolvedSignNamesProvider);

    List<ExportRow> rows(NodesApsResult result) => nodesApsToExportRows(
      result,
      format,
      swe,
      scale,
      isXyz: flags.isXyz,
      coordValue: flags.coordValue,
      scheme: signs.scheme,
      signSet: signs.set,
      binning: signs.binning,
    );

    return SeriesView(
      tabId: AppTab.nodesApsides.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
    );
  }
}

class _NodesResults extends ConsumerWidget {
  const _NodesResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(nodesApsResultsProvider);
    final fmt = ref.watch(nodesFormatProvider);

    return switch (outcome) {
      CalcError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final result) => _buildResult(context, ref, result, fmt),
    };
  }

  Widget _buildResult(
    BuildContext context,
    WidgetRef ref,
    NodesApsResult result,
    DisplayFormat fmt,
  ) {
    final flags = ref.watch(flagBarProvider);
    final isXyz = flags.isXyz;
    final lbl = coordLabels(flags.coordValue);
    final signs = ref.watch(resolvedSignNamesProvider);

    String deg(double v) => formatAngle(v, fmt);
    String raw(double v) => v.toStringAsFixed(8);

    List<ResultField> posFields(CalcResult pos) => [
      ResultField(
        label: lbl.c1,
        value: isXyz ? formatAu(pos.longitude, fmt) : deg(pos.longitude),
        rawValue: pos.longitude,
      ),
      if (inSignField(
            pos.longitude,
            flags.coordValue,
            signs.scheme,
            signs.set,
            fmt,
            signs.binning,
          )
          case final sf?)
        ResultField(
          label: sf.$1,
          value: sf.$2,
          rawValue: inSignLongitudeFor(
            pos.longitude,
            signs.scheme,
            signs.binning,
          ),
        ),
      ResultField(
        label: lbl.c2,
        value: isXyz ? formatAu(pos.latitude, fmt) : deg(pos.latitude),
        rawValue: pos.latitude,
      ),
      ResultField(
        label: isXyz ? lbl.c3 : 'Distance (AU)',
        value: isXyz ? formatAu(pos.distance, fmt) : raw(pos.distance),
        rawValue: pos.distance,
      ),
      if (isXyz)
        ResultField(
          label: 'Distance',
          value: formatEuclidean(
            pos.longitude,
            pos.latitude,
            pos.distance,
            fmt,
          ),
          rawValue: euclideanDistance(
            pos.longitude,
            pos.latitude,
            pos.distance,
          ),
        ),
      ResultField(
        label: lbl.sc1,
        value: isXyz
            ? formatAuSpeed(pos.longitudeSpeed, fmt)
            : deg(pos.longitudeSpeed),
        rawValue: pos.longitudeSpeed,
      ),
      ResultField(
        label: lbl.sc2,
        value: isXyz
            ? formatAuSpeed(pos.latitudeSpeed, fmt)
            : deg(pos.latitudeSpeed),
        rawValue: pos.latitudeSpeed,
      ),
      ResultField(
        label: lbl.sc3,
        value: isXyz
            ? formatAuSpeed(pos.distanceSpeed, fmt)
            : raw(pos.distanceSpeed),
        rawValue: pos.distanceSpeed,
      ),
    ];

    final cards = <Widget>[
      ResultCard(
        title: '${result.bodyName} — Ascending Node',
        flagHex:
            '0x${result.ascending.returnFlag.toRadixString(16).toUpperCase()}',
        fields: posFields(result.ascending),
      ),
      ResultCard(
        title: '${result.bodyName} — Descending Node',
        flagHex:
            '0x${result.descending.returnFlag.toRadixString(16).toUpperCase()}',
        fields: posFields(result.descending),
      ),
      ResultCard(
        title: '${result.bodyName} — Perihelion',
        flagHex:
            '0x${result.perihelion.returnFlag.toRadixString(16).toUpperCase()}',
        fields: posFields(result.perihelion),
      ),
      ResultCard(
        title: '${result.bodyName} — Aphelion',
        flagHex:
            '0x${result.aphelion.returnFlag.toRadixString(16).toUpperCase()}',
        fields: posFields(result.aphelion),
      ),
    ];

    final el = result.orbitalElements;
    if (el != null) {
      cards.add(
        ResultCard(
          title: '${result.bodyName} — Orbital Elements',
          fields: [
            ResultField(
              label: 'Semi-major Axis (AU)',
              value: raw(el.semimajorAxis),
              rawValue: el.semimajorAxis,
            ),
            ResultField(
              label: 'Eccentricity',
              value: raw(el.eccentricity),
              rawValue: el.eccentricity,
            ),
            ResultField(
              label: 'Inclination',
              value: deg(el.inclination),
              rawValue: el.inclination,
            ),
            ResultField(
              label: 'Ascending Node',
              value: deg(el.ascendingNode),
              rawValue: el.ascendingNode,
            ),
            ResultField(
              label: 'Arg. Periapsis',
              value: deg(el.argPeriapsis),
              rawValue: el.argPeriapsis,
            ),
            ResultField(
              label: 'Lon. Periapsis',
              value: deg(el.lonPeriapsis),
              rawValue: el.lonPeriapsis,
            ),
            ResultField(
              label: 'Mean Anomaly (epoch)',
              value: deg(el.meanAnomalyEpoch),
              rawValue: el.meanAnomalyEpoch,
            ),
            ResultField(
              label: 'True Anomaly (epoch)',
              value: deg(el.trueAnomalyEpoch),
              rawValue: el.trueAnomalyEpoch,
            ),
            ResultField(
              label: 'Eccentric Anomaly',
              value: deg(el.eccentricAnomalyEpoch),
              rawValue: el.eccentricAnomalyEpoch,
            ),
            ResultField(
              label: 'Mean Longitude (epoch)',
              value: deg(el.meanLongitudeEpoch),
              rawValue: el.meanLongitudeEpoch,
            ),
            ResultField(
              label: 'Mean Daily Motion',
              value: deg(el.meanDailyMotion),
              rawValue: el.meanDailyMotion,
            ),
            ResultField(
              label: 'Perihelion Dist (AU)',
              value: raw(el.perihelionDistance),
              rawValue: el.perihelionDistance,
            ),
            ResultField(
              label: 'Aphelion Dist (AU)',
              value: raw(el.aphelionDistance),
              rawValue: el.aphelionDistance,
            ),
            ResultField(
              label: 'Sidereal Period (yr)',
              value: raw(el.siderealPeriodYears),
              rawValue: el.siderealPeriodYears,
            ),
            ResultField(
              label: 'Tropical Period (yr)',
              value: raw(el.tropicalPeriodYears),
              rawValue: el.tropicalPeriodYears,
            ),
            ResultField(
              label: 'Synodic Period (days)',
              value: raw(el.synodicPeriodDays),
              rawValue: el.synodicPeriodDays,
            ),
            () {
              // Label and value from the same helper the export calls, so the
              // card cannot name this scale differently from the file.
              final (label, value) = perihelionPassageField(
                el.perihelionPassage,
                ref.read(sweProvider),
                ref.watch(clockViewProvider).scale,
              );
              return ResultField(
                label: label,
                value: value,
                rawValue: double.parse(value),
              );
            }(),
          ],
        ),
      );
    }

    if (result.maxDist != null && result.minDist != null) {
      cards.add(
        ResultCard(
          title: '${result.bodyName} — Distance Extremes',
          fields: [
            ResultField(
              label: 'Max True Distance (AU)',
              value: raw(result.maxDist!),
              rawValue: result.maxDist!,
            ),
            ResultField(
              label: 'Min True Distance (AU)',
              value: raw(result.minDist!),
              rawValue: result.minDist!,
            ),
          ],
        ),
      );
    }

    return ResultCardGrid.cards(cards);
  }
}
