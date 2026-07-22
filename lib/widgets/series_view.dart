// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calculation/moment.dart';
import '../core/calculation/series_export.dart';
import '../core/calculation/series_settings_provider.dart';
import '../core/calculation/series_table.dart';
import 'export_button.dart';
import 'quantity_picker.dart';
import 'series_grid.dart';

/// The body of a tab in series mode: quantity picker over series grid.
///
/// A tab hands over its own steps — its existing typed result run through its
/// existing `*ToExportRows` — and gets the whole surface. That is the point of
/// the design: rolling a tab into series mode is wiring, not new UI.
class SeriesView extends ConsumerWidget {
  const SeriesView({
    super.key,
    required this.tabId,
    required this.steps,
    required this.momentLabel,
    this.momentColumnTitle = 'Moment',
    this.filenameStem,
  });

  /// `TabDescriptor.id` — the key the settings are stored under.
  final String tabId;

  final List<SeriesStep> steps;
  final String Function(Moment) momentLabel;
  final String momentColumnTitle;

  /// Defaults to [seriesFilenameStem].
  final String? filenameStem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(seriesSettingsProvider(tabId));
    final notifier = ref.read(seriesSettingsProvider(tabId).notifier);
    final table = buildSeriesTable(steps, hiddenLabels: settings.hiddenLabels);

    return Column(
      // Shrink-wraps. The app shell scrolls the whole page (`AppShell.body` is
      // a `SingleChildScrollView`), so tab content is laid out under unbounded
      // height and a flex child here would throw.
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: QuantityPicker(
                labels: seriesFieldLabels(steps),
                hiddenLabels: settings.hiddenLabels,
                onVisibilityChanged: notifier.setLabelVisible,
              ),
            ),
            ExportButton.variants(
              hasResults: !table.isEmpty,
              variants: [
                for (final layout in SeriesLayout.values)
                  ExportVariant(
                    layout.label,
                    () => seriesToExportRows(
                      table,
                      layout,
                      momentLabel: momentLabel,
                    ),
                  ),
              ],
              selected: settings.exportLayout.index,
              onSelected: (index) =>
                  notifier.setExportLayout(SeriesLayout.values[index]),
              filenameStem: filenameStem ?? seriesFilenameStem(tabId, steps),
              disabledTooltip: 'Export disabled: no series rows',
            ),
          ],
        ),
        SeriesGrid(
          table: table,
          momentLabel: momentLabel,
          momentColumnTitle: momentColumnTitle,
        ),
      ],
    );
  }
}
