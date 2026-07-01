import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/emitter_provider.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/code_modal.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
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
  (seCeres, 'Ceres'),
];

class PhenomenaTab extends ConsumerStatefulWidget {
  const PhenomenaTab({super.key});

  @override
  ConsumerState<PhenomenaTab> createState() => _PhenomenaTabState();
}

class _PhenomenaTabState extends ConsumerState<PhenomenaTab> {
  bool _showExtra = false;

  void _toggleBody(int body) {
    final current = ref.read(phenomenaBodiesProvider);
    final updated = current.contains(body)
        ? current.where((b) => b != body).toList()
        : [...current, body];
    ref.read(phenomenaBodiesProvider.notifier).state = updated;
  }

  @override
  Widget build(BuildContext context) {
    final selectedBodies = ref.watch(phenomenaBodiesProvider);
    final fmt = ref.watch(phenomenaFormatProvider);
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
        // ── Progressive disclosure: outer bodies ──
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
                        CalcSweError() => [],
                      },
                      filenameStem: 'swe_phenomena_${jd.toStringAsFixed(4)}',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        if (isMobile)
          const _ResultsView()
        else
          Expanded(child: const _ResultsView()),
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
      CalcSweError(:final message) => Center(
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
                            subtitle: 'phenoUt(${r.body})',
                            fields: [
                              ResultField(
                                label: 'Phase Angle',
                                value: formatAngle(r.phaseAngle, format),
                                rawValue: r.phaseAngle,
                              ),
                              ResultField(
                                label: 'Elongation',
                                value: formatAngle(r.elongation, format),
                                rawValue: r.elongation,
                              ),
                              ResultField(
                                label: 'App. Diameter',
                                value: formatAngle(r.apparentDiameter, format),
                                rawValue: r.apparentDiameter,
                              ),
                              ResultField(
                                label: 'Phase (Illum.)',
                                value: r.phase.isNaN
                                    ? 'NaN'
                                    : r.phase.toStringAsFixed(6),
                                rawValue: r.phase,
                              ),
                              ResultField(
                                label: 'App. Magnitude',
                                value: r.apparentMagnitude.isNaN
                                    ? 'NaN'
                                    : r.apparentMagnitude.toStringAsFixed(4),
                                rawValue: r.apparentMagnitude,
                              ),
                            ],
                            onCode: () {
                              final trace = ref.read(phenomenaTraceProvider);
                              final slice = trace.sliceByTab('phenomena');
                              if (slice.entries.isEmpty) return;
                              final emitter = ref.read(selectedEmitterProvider);
                              final code = slice.entries
                                  .map(emitter.emitSnippet)
                                  .join('\n');
                              showCodeModal(
                                context,
                                code: code,
                                languageLabel: emitter.displayName,
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
    };
  }
}
