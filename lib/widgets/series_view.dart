// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calculation/moment.dart';
import '../core/calculation/series_export.dart';
import '../core/calculation/series_settings_provider.dart';
import '../core/calculation/series_table.dart';
import '../core/context_provider.dart';
import '../core/display_format.dart';
import '../core/jd_utils.dart';
import '../core/swe_utils_provider.dart';
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
    this.momentColumnTitle,
    this.filenameStem,
  });

  /// `TabDescriptor.id` — the key the settings are stored under.
  final String tabId;

  final List<SeriesStep> steps;

  /// Header for the sticky Moment column. Defaults to the Moment expressed on
  /// the Context's time Scale, e.g. `Date/Time (UT1)` / `(TT)` / `(UTC)`, so it
  /// stays honest when the rows shift with the Scale.
  final String? momentColumnTitle;

  /// Defaults to [seriesFilenameStem].
  final String? filenameStem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A run the user just triggered shows a placeholder for one frame before the
    // synchronous step loop starts (see [seriesCalculatingProvider]); the steps
    // are empty until then, so there is nothing else worth building.
    if (ref.watch(seriesCalculatingProvider(tabId))) {
      return _SeriesCalculating(tabId: tabId);
    }

    final settings = ref.watch(seriesSettingsProvider(tabId));
    final notifier = ref.read(seriesSettingsProvider(tabId).notifier);
    final table = buildSeriesTable(steps, hiddenLabels: settings.hiddenLabels);

    final scale = ref.watch(contextBarProvider.select((s) => s.timeScale));
    final columnTitle = momentColumnTitle ?? 'Date/Time (${scale.label})';

    // How a step's Moment reads is one app-wide policy, not a tab's choice:
    // the selected clock and the engine behind the formatter are providers,
    // so the view resolves them itself rather than taking a lambda from each
    // of eleven tabs. A step whose UT could not be computed is a NaN Moment;
    // formatting falls back to the raw Julian Day rather than throwing.
    final clockView = ref.watch(clockViewProvider);
    final swe = ref.read(sweProvider);
    String momentLabel(Moment m) => formatJdDateTime(
      swe,
      m.ut,
      showLabel: false,
      view: clockView,
      fallbackDigits: 4,
    );

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
              selected: settings.layout.index,
              onSelected: (index) =>
                  notifier.setLayout(SeriesLayout.values[index]),
              filenameStem: filenameStem ?? seriesFilenameStem(tabId, steps),
              disabledTooltip: 'Export disabled: no series rows',
            ),
          ],
        ),
        SeriesGrid(
          table: table,
          momentLabel: momentLabel,
          momentColumnTitle: columnTitle,
          layout: settings.layout,
        ),
      ],
    );
  }
}

/// The "Calculating…" placeholder shown for the one frame between a series run
/// being requested and its synchronous step loop starting.
///
/// Clearing [seriesCalculatingProvider] from a post-frame callback here — i.e.
/// only *after* this has painted — is what lets the message appear before the
/// isolate-blocking run rather than after it. A static label, not a spinner: the
/// run blocks the isolate, so an animation would sit frozen and imply progress
/// it is not making.
class _SeriesCalculating extends ConsumerStatefulWidget {
  const _SeriesCalculating({required this.tabId});

  final String tabId;

  @override
  ConsumerState<_SeriesCalculating> createState() => _SeriesCalculatingState();
}

class _SeriesCalculatingState extends ConsumerState<_SeriesCalculating> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(seriesCalculatingProvider(widget.tabId).notifier).state = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_top, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            'Calculating…',
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
