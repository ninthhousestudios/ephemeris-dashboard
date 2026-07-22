// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calculation/moment.dart';
import '../core/calculation/series_settings_provider.dart';
import '../core/calculation/series_table.dart';
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
  });

  /// `TabDescriptor.id` — the key the settings are stored under.
  final String tabId;

  final List<SeriesStep> steps;
  final String Function(Moment) momentLabel;
  final String momentColumnTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(seriesSettingsProvider(tabId));
    final notifier = ref.read(seriesSettingsProvider(tabId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuantityPicker(
          labels: seriesFieldLabels(steps),
          hiddenLabels: settings.hiddenLabels,
          onVisibilityChanged: notifier.setLabelVisible,
        ),
        Expanded(
          child: SeriesGrid(
            table: buildSeriesTable(steps, hiddenLabels: settings.hiddenLabels),
            momentLabel: momentLabel,
            momentColumnTitle: momentColumnTitle,
          ),
        ),
      ],
    );
  }
}
