import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/emitter_provider.dart';
import '../../core/ephemeris/runner.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/code_modal.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'nodes_apsides_provider.dart';

const _defaultBodies = <(int, String)>[
  (seSun, 'Sun'),
  (seMoon, 'Moon'),
  (seMercury, 'Mercury'),
  (seVenus, 'Venus'),
  (seMars, 'Mars'),
  (seJupiter, 'Jupiter'),
  (seSaturn, 'Saturn'),
  (seUranus, 'Uranus'),
  (seNeptune, 'Neptune'),
  (sePluto, 'Pluto'),
];

const _extraBodies = <(int, String)>[
  (seMeanNode, 'M.Node'),
  (seTrueNode, 'T.Node'),
  (seMeanApog, 'M.Lilith'),
  (seOscuApog, 'O.Lilith'),
  (seEarth, 'Earth'),
  (seChiron, 'Chiron'),
  (sePholus, 'Pholus'),
  (seCeres, 'Ceres'),
  (sePallas, 'Pallas'),
  (seJuno, 'Juno'),
  (seVesta, 'Vesta'),
];

const _methodOptions = <(int, String)>[
  (0, 'Mean'),
  (1, 'Osculating'),
  (2, 'Oscu Bary'),
];

class NodesApsidesTab extends ConsumerStatefulWidget {
  const NodesApsidesTab({super.key});

  @override
  ConsumerState<NodesApsidesTab> createState() => _NodesApsidesTabState();
}

class _NodesApsidesTabState extends ConsumerState<NodesApsidesTab> {
  bool _showExtraBodies = false;

  @override
  Widget build(BuildContext context) {
    final body = ref.watch(nodesBodyProvider);
    final method = ref.watch(nodesMethodProvider);
    final fmt = ref.watch(nodesFormatProvider);
    final jd = ref.watch(contextBarProvider).jdUt;
    final nodesOutcome = ref.watch(nodesApsResultsProvider);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isMobile = ResponsiveLayout.of(context) == ScreenSize.mobile;

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
                ..._defaultBodies.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(b.$2),
                      selected: body == b.$1,
                      onSelected: (_) =>
                          ref.read(nodesBodyProvider.notifier).state = b.$1,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
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
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _extraBodies
                      .map(
                        (b) => ChoiceChip(
                          label: Text(b.$2),
                          selected: body == b.$1,
                          onSelected: (_) =>
                              ref.read(nodesBodyProvider.notifier).state = b.$1,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
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
                    return switch (nodesOutcome) {
                      CalcOk(value: final result) => nodesApsToExportRows(
                        result,
                        ref.read(nodesFormatProvider),
                      ),
                      CalcSweError() => [],
                    };
                  },
                  filenameStem: 'swe_nodes_apsides_${jd.toStringAsFixed(4)}',
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        if (isMobile)
          const _NodesResults()
        else
          Expanded(child: const _NodesResults()),
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
      CalcSweError(:final message) => Center(
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
    String deg(double v) => formatAngle(v, fmt);
    String raw(double v) => v.toStringAsFixed(8);

    List<ResultField> posFields(CalcResult pos) => [
      ResultField(
        label: 'Longitude',
        value: deg(pos.longitude),
        rawValue: pos.longitude,
      ),
      ResultField(
        label: 'Latitude',
        value: deg(pos.latitude),
        rawValue: pos.latitude,
      ),
      ResultField(
        label: 'Distance (AU)',
        value: raw(pos.distance),
        rawValue: pos.distance,
      ),
      ResultField(
        label: 'Speed Lon',
        value: deg(pos.longitudeSpeed),
        rawValue: pos.longitudeSpeed,
      ),
      ResultField(
        label: 'Speed Lat',
        value: deg(pos.latitudeSpeed),
        rawValue: pos.latitudeSpeed,
      ),
      ResultField(
        label: 'Speed Dist',
        value: raw(pos.distanceSpeed),
        rawValue: pos.distanceSpeed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;

        void onCode() {
          final trace = ref.read(callTraceProvider);
          if (trace == null) return;
          final slice = trace.sliceByTab('nodesApsides');
          if (slice.entries.isEmpty) return;
          final emitter = ref.read(selectedEmitterProvider);
          final code = slice.entries.map(emitter.emitSnippet).join('\n');
          showCodeModal(
            context,
            code: code,
            languageLabel: emitter.displayName,
          );
        }

        final cards = <Widget>[
          SizedBox(
            width: cardWidth,
            child: ResultCard(
              title: '${result.bodyName} — Ascending Node',
              flagHex:
                  '0x${result.ascending.returnFlag.toRadixString(16).toUpperCase()}',
              fields: posFields(result.ascending),
              onCode: onCode,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: ResultCard(
              title: '${result.bodyName} — Descending Node',
              flagHex:
                  '0x${result.descending.returnFlag.toRadixString(16).toUpperCase()}',
              fields: posFields(result.descending),
              onCode: onCode,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: ResultCard(
              title: '${result.bodyName} — Perihelion',
              flagHex:
                  '0x${result.perihelion.returnFlag.toRadixString(16).toUpperCase()}',
              fields: posFields(result.perihelion),
              onCode: onCode,
            ),
          ),
          SizedBox(
            width: cardWidth,
            child: ResultCard(
              title: '${result.bodyName} — Aphelion',
              flagHex:
                  '0x${result.aphelion.returnFlag.toRadixString(16).toUpperCase()}',
              fields: posFields(result.aphelion),
              onCode: onCode,
            ),
          ),
        ];

        final el = result.orbitalElements;
        if (el != null) {
          cards.add(
            SizedBox(
              width: cardWidth,
              child: ResultCard(
                title: '${result.bodyName} — Orbital Elements',
                onCode: onCode,
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
                  ResultField(
                    label: 'Perihelion Passage (JD)',
                    value: raw(el.perihelionPassage),
                    rawValue: el.perihelionPassage,
                  ),
                ],
              ),
            ),
          );
        }

        if (result.maxDist != null && result.minDist != null) {
          cards.add(
            SizedBox(
              width: cardWidth,
              child: ResultCard(
                title: '${result.bodyName} — Distance Extremes',
                onCode: onCode,
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
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 4, runSpacing: 4, children: cards),
        );
      },
    );
  }
}
