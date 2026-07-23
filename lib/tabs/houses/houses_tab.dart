// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/export_service.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/jd_utils.dart';
import '../../core/persistence.dart';
import '../../core/swe_service.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import 'houses_provider.dart';

class HousesTab extends ConsumerStatefulWidget {
  const HousesTab({super.key});

  @override
  ConsumerState<HousesTab> createState() => _HousesTabState();
}

class _HousesTabState extends ConsumerState<HousesTab> {
  @override
  Widget build(BuildContext context) {
    final hsys = ref.watch(selectedHouseSystemProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // House system selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width - 24,
              ),
              child: Row(
                children: [
                  Text('House System:', style: theme.textTheme.labelMedium),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<int>(
                      initialValue: hsys,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: houseSystems
                          .map(
                            (h) => DropdownMenuItem(
                              value: h.code,
                              child: Text(
                                '${h.char} — ${h.label}',
                                style: theme.textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(selectedHouseSystemProvider.notifier).state =
                              v;
                          ref.read(persistenceProvider).saveHouseSystem(v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SeriesBar(tabId: AppTab.houses.name),
        const Divider(height: 1),
        // Results
        if (ref.watch(
          seriesSettingsProvider(AppTab.houses.name).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          _buildResults(),
      ],
    );
  }

  Widget _buildSeries() {
    final format = ref.watch(housesFormatProvider);
    final utcOffset = ref.watch(contextBarProvider).utcOffset;
    final swe = ref.read(sweProvider);
    final steps = ref.watch(housesSeriesProvider);

    List<ExportRow> rows(HousesCalcResult result) =>
        housesToExportRows(result, format);

    return SeriesView(
      tabId: AppTab.houses.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
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
    final format = ref.watch(housesFormatProvider);
    final outcome = ref.watch(housesResultProvider);

    return switch (outcome) {
      CalcError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final result) => _buildResultCards(result, format),
    };
  }

  Widget _buildResultCards(HousesCalcResult result, DisplayFormat format) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;
        final cuspCount = (result.hsys == 0x47 ? 36 : 12).clamp(
          0,
          result.cusps.length - 1,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (int i = 1; i <= cuspCount; i++)
                    SizedBox(
                      width: cardWidth,
                      child: ResultCard(
                        title: 'Cusp $i',
                        subtitle: result.hsysName,
                        flagHex: null,
                        fields: [
                          ResultField(
                            label: 'Longitude',
                            value: formatAngle(result.cusps[i], format),
                            rawValue: result.cusps[i],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              ResultCard(
                title: 'Angles',
                subtitle: result.hsysName,
                fields: [
                  ResultField(
                    label: 'Asc',
                    value: formatAngle(result.asc, format),
                    rawValue: result.asc,
                  ),
                  ResultField(
                    label: 'MC',
                    value: formatAngle(result.mc, format),
                    rawValue: result.mc,
                  ),
                  ResultField(
                    label: 'ARMC',
                    value: formatAngle(result.armc, format),
                    rawValue: result.armc,
                  ),
                  ResultField(
                    label: 'Vertex',
                    value: formatAngle(result.vertex, format),
                    rawValue: result.vertex,
                  ),
                  ResultField(
                    label: 'Eq Asc',
                    value: formatAngle(result.equatorialAsc, format),
                    rawValue: result.equatorialAsc,
                  ),
                ],
              ),
              if (result.bodyPositions.isNotEmpty) ...[
                const SizedBox(height: 4),
                ResultCard(
                  title: 'House Positions',
                  subtitle: result.hsysName,
                  fields: [
                    for (final b in result.bodyPositions)
                      ResultField(
                        label: b.name,
                        value: b.errorMessage != null
                            ? 'error'
                            : 'H${b.houseNumber}  '
                                  '${formatAngle(b.positionDegrees, format)}',
                        rawValue: b.errorMessage != null ? null : b.housePos,
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class HousesFormatTrailing extends ConsumerWidget {
  const HousesFormatTrailing({super.key});

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
    final format = ref.watch(housesFormatProvider);
    final outcome = ref.watch(housesResultProvider);
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
              ref.read(housesFormatProvider.notifier).state = s.first,
          style: formatStyle,
        ),
        const SizedBox(width: 8),
        ExportButton(
          hasResults: outcome is CalcOk<HousesCalcResult>,
          getRows: () => switch (outcome) {
            CalcOk(value: final r) => housesToExportRows(r, format),
            CalcError() => [],
          },
          filenameStem: 'swe_houses_${jd.toStringAsFixed(4)}',
        ),
      ],
    );
  }
}
