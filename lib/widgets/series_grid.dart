// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';

import '../core/calculation/moment.dart';
import '../core/calculation/series_layout.dart';
import '../core/calculation/series_table.dart';

/// Renders a [SeriesTable] in the chosen [SeriesLayout].
///
/// Both shapes come off the same built table, so the screen and the export of
/// the same layout agree by construction rather than by two implementations
/// staying in step:
///
/// - [SeriesLayout.horizontal] — one row per Moment, one column per
///   (row identifier, quantity).
/// - [SeriesLayout.vertical] — one row per (Moment, row identifier), one
///   column per quantity, via [toVerticalTable].
///
/// Tab-agnostic — it takes a built table and a way to label a Moment, and has
/// no idea what the quantities mean.
///
/// Sizing follows the zoom rules in CLAUDE.md: two-axis scrolling with
/// intrinsic column widths, no fixed aspect ratios and no fixed-width label
/// boxes, so the grid stays usable at any text scale. A sticky Moment column
/// is deliberately deferred.
class SeriesGrid extends StatelessWidget {
  const SeriesGrid({
    super.key,
    required this.table,
    required this.momentLabel,
    this.momentColumnTitle = 'Moment',
    required this.layout,
  });

  final SeriesTable table;

  /// How to render the leading cell of a row. The tab supplies this because
  /// formatting a Moment needs the engine and the Context's UTC offset.
  final String Function(Moment) momentLabel;

  final String momentColumnTitle;

  final SeriesLayout layout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (table.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No steps', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    return _scroller(
      Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
        children: switch (layout) {
          SeriesLayout.horizontal => _horizontalRows(theme),
          SeriesLayout.vertical => _verticalRows(theme),
        },
      ),
    );
  }

  /// One row per Moment, every (row identifier, quantity) across.
  List<TableRow> _horizontalRows(ThemeData theme) {
    // An error column is added only when some step failed, so a clean series
    // spends no width on it — and within one render the column set is fixed,
    // which is what "an errored step does not shift the columns" means.
    final hasErrors = table.hasErrors;

    return [
      TableRow(
        children: [
          _headerCell(theme, momentColumnTitle),
          for (final column in table.columns) _headerCell(theme, column.title),
          if (hasErrors) _headerCell(theme, 'Error'),
        ],
      ),
      for (final row in table.rows)
        TableRow(
          children: [
            _cell(theme, momentLabel(row.moment), isMoment: true),
            for (final column in table.columns)
              _cell(
                theme,
                // A missing value is a hole in this row — a body that dropped
                // out, or a step that failed — not a reason to move the
                // columns.
                row.isError ? '—' : (row.values[column] ?? ''),
              ),
            if (hasErrors) _cell(theme, row.error ?? '', isError: true),
          ],
        ),
    ];
  }

  /// One row per (Moment, row identifier), quantities across.
  ///
  /// The Moment repeats down its own group of rows rather than spanning them:
  /// `Table` has no row spanning, and a blank-until-it-changes column would
  /// break the moment a row is read out of order or copied.
  List<TableRow> _verticalRows(ThemeData theme) {
    final vertical = toVerticalTable(table);
    final hasErrors = vertical.hasErrors;
    // 'Name' is what `ExportService` calls this column, and the vertical
    // export is exactly these rows — the heading should not disagree.
    final showNames = vertical.hasIdentifiers;

    return [
      TableRow(
        children: [
          _headerCell(theme, momentColumnTitle),
          if (showNames) _headerCell(theme, 'Name'),
          for (final label in vertical.labels) _headerCell(theme, label),
          if (hasErrors) _headerCell(theme, 'Error'),
        ],
      ),
      for (final row in vertical.rows)
        TableRow(
          children: [
            _cell(theme, momentLabel(row.moment), isMoment: true),
            if (showNames) _cell(theme, row.header, isMoment: true),
            for (final label in vertical.labels)
              _cell(theme, row.isError ? '—' : (row.values[label] ?? '')),
            if (hasErrors) _cell(theme, row.error ?? '', isError: true),
          ],
        ),
    ];
  }

  Widget _scroller(Widget table) => SingleChildScrollView(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: table,
      ),
    ),
  );

  Widget _headerCell(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _cell(
    ThemeData theme,
    String text, {
    bool isMoment = false,
    bool isError = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        color: isError ? theme.colorScheme.error : null,
        fontWeight: isMoment ? FontWeight.w500 : null,
      ),
    ),
  );
}
