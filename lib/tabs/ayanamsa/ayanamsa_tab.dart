// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'ayanamsa_provider.dart';

class AyanamsaTab extends ConsumerStatefulWidget {
  const AyanamsaTab({super.key});

  @override
  ConsumerState<AyanamsaTab> createState() => _AyanamsaTabState();
}

class _AyanamsaTabState extends ConsumerState<AyanamsaTab> {
  void _toggleAyanamsa(int sidMode) {
    final current = ref.read(selectedAyanamsasProvider);
    final updated = current.contains(sidMode)
        ? current.where((m) => m != sidMode).toList()
        : [...current, sidMode];
    ref.read(selectedAyanamsasProvider.notifier).state = updated;
  }

  @override
  Widget build(BuildContext context) {
    final compareMode = ref.watch(ayanamsaCompareModeProvider);
    final selected = ref.watch(selectedAyanamsasProvider);
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.of(context) == ScreenSize.mobile;

    return Column(
      children: [
        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text('Mode:', style: theme.textTheme.labelMedium),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Select')),
                        ButtonSegment(value: true, label: Text('Compare All')),
                      ],
                      selected: {compareMode},
                      onSelectionChanged: (s) =>
                          ref.read(ayanamsaCompareModeProvider.notifier).state =
                              s.first,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final fmt = ref.watch(ayanamsaFormatProvider);
                        return SegmentedButton<DisplayFormat>(
                          segments: DisplayFormat.values
                              .map(
                                (f) => ButtonSegment(
                                  value: f,
                                  label: Text(f.label),
                                ),
                              )
                              .toList(),
                          selected: {fmt},
                          onSelectionChanged: (s) =>
                              ref.read(ayanamsaFormatProvider.notifier).state =
                                  s.first,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final results = switch (ref.watch(
                          ayanamsaResultsProvider,
                        )) {
                          CalcOk(:final value) => value,
                          CalcSweError() => const <AyanamsaCalcResult>[],
                        };
                        final fmt = ref.watch(ayanamsaFormatProvider);
                        final jd = ref.watch(contextBarProvider).jdUt;
                        return ExportButton(
                          hasResults: results.isNotEmpty,
                          getRows: () => ayanamsaToExportRows(results, fmt),
                          filenameStem: 'swe_ayanamsa_${jd.toStringAsFixed(4)}',
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (!compareMode) ...[
                const SizedBox(height: 6),
                // Ayanamsa selector chips — scrollable with constrained height
                Consumer(
                  builder: (context, ref, _) {
                    final ctx = ref.watch(contextBarProvider);
                    final hasUserParams =
                        ctx.userAyanT0 != 0.0 || ctx.userAyanValue != 0.0;
                    final modes = ayanamsaModesFor(includeUser: hasUserParams);
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: modes.entries.map((e) {
                            return FilterChip(
                              label: Text(
                                e.value,
                                style: theme.textTheme.labelSmall,
                              ),
                              selected: selected.contains(e.key),
                              onSelected: (_) => _toggleAyanamsa(e.key),
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Results
        if (isMobile) _buildResults() else Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    final format = ref.watch(ayanamsaFormatProvider);
    final results = switch (ref.watch(ayanamsaResultsProvider)) {
      CalcOk(:final value) => value,
      CalcSweError() => const <AyanamsaCalcResult>[],
    };

    if (results.isEmpty) {
      return const Center(child: Text('No results'));
    }

    final compareMode = ref.watch(ayanamsaCompareModeProvider);

    // In compare mode, show a compact table instead of cards.
    if (compareMode) {
      return _buildCompareTable(results);
    }

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
                  title: r.name,
                  subtitle: 'SE_SIDM_${r.sidMode}',
                  fields: [
                    ResultField(
                      label: 'Value',
                      value: formatAngle(r.value, format),
                      rawValue: r.value,
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

  Widget _buildCompareTable(List<AyanamsaCalcResult> results) {
    final format = ref.watch(ayanamsaFormatProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 36,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Ayanamsa')),
          DataColumn(label: Text('Value'), numeric: true),
        ],
        rows: results.map((r) {
          return DataRow(
            cells: [
              DataCell(Text('${r.sidMode}', style: theme.textTheme.bodySmall)),
              DataCell(Text(r.name, style: theme.textTheme.bodySmall)),
              DataCell(
                SelectableText(
                  formatAngle(r.value, format),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
