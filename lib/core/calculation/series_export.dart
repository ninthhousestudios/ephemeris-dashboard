// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../export_service.dart';
import 'moment.dart';
import 'series_layout.dart';
import 'series_table.dart';

export 'series_layout.dart' show SeriesLayout;

/// Filename stem for a series export: `swe_<tabId>_series_<start JD>`.
///
/// A series is identified by where it starts, so the start Moment is in the
/// name. Without it two exports taken at different Contexts collide in the save
/// dialog and cannot be told apart afterwards. Four decimals (~8 seconds)
/// matches the single-Moment tabs. A series with no steps, or one whose start
/// UT could not be computed, falls back to the bare stem rather than naming a
/// file `NaN`.
String seriesFilenameStem(String tabId, List<SeriesStep> steps) {
  const bare = '';
  final jd = steps.isEmpty ? double.nan : steps.first.$1.ut;
  final suffix = jd.isNaN ? bare : '_${jd.toStringAsFixed(4)}';
  return 'swe_${tabId}_series$suffix';
}

/// Projects an already-built [SeriesTable] into export rows.
///
/// Taking the table rather than the raw steps is what makes the export match
/// the screen: the hidden quantities are already dropped and the column order
/// is the grid's own union-in-first-appearance order, so
/// [SeriesLayout.horizontal] and the grid cannot disagree.
List<ExportRow> seriesToExportRows(
  SeriesTable table,
  SeriesLayout layout, {
  required String Function(Moment) momentLabel,
}) {
  return switch (layout) {
    SeriesLayout.vertical => _vertical(table, momentLabel),
    SeriesLayout.horizontal => _horizontal(table, momentLabel),
  };
}

/// One row per (step, row identifier), quantities as columns.
List<ExportRow> _vertical(SeriesTable table, String Function(Moment) label) {
  // Row identifiers in column order, so the bodies come out in the order the
  // grid shows them rather than in map order.
  final headers = <String>[];
  final seen = <String>{};
  for (final column in table.columns) {
    if (seen.add(column.header)) headers.add(column.header);
  }

  // Quantity labels are shared across bodies, so the vertical schema is the
  // distinct labels in column order.
  final labels = <String>[];
  final seenLabels = <String>{};
  for (final column in table.columns) {
    if (seenLabels.add(column.label)) labels.add(column.label);
  }

  final rows = <ExportRow>[];
  for (final row in table.rows) {
    final leading = _leading(row.moment, label);
    if (row.error case final message?) {
      rows.add(_errorRow('', leading, labels, message));
      continue;
    }
    for (final header in headers) {
      final fields = <(String, String)>[...leading];
      for (final column in table.columns) {
        if (column.header != header) continue;
        final value = row.values[column];
        if (value != null) fields.add((column.label, value));
      }
      // A body that dropped out of this step contributes no row at all —
      // an all-empty row would read as a result of "".
      if (fields.length > leading.length) {
        rows.add(ExportRow(header: header, fields: fields));
      }
    }
  }
  return rows;
}

/// One row per step, every (row identifier, quantity) flattened across.
List<ExportRow> _horizontal(SeriesTable table, String Function(Moment) label) {
  return table.rows.map((row) {
    final leading = _leading(row.moment, label);
    if (row.error case final message?) {
      return _errorRow(leading.last.$2, leading, [
        for (final column in table.columns) column.title,
      ], message);
    }
    return ExportRow(
      header: leading.last.$2,
      fields: [
        ...leading,
        for (final column in table.columns)
          (column.title, row.values[column] ?? ''),
      ],
    );
  }).toList();
}

/// A failed step, padded out to the full [schema] before the message.
///
/// The padding is load-bearing, not decoration: `ExportService` derives its
/// columns from first appearance across rows, so an unpadded error row as step
/// 0 would put Error ahead of every quantity and make the exported column
/// order depend on which step failed.
ExportRow _errorRow(
  String header,
  List<(String, String)> leading,
  List<String> schema,
  String message,
) {
  return ExportRow(
    header: header,
    fields: [
      ...leading,
      for (final label in schema) (label, ''),
      ('Error', message),
    ],
  );
}

/// JD then the formatted date, leading every row in both layouts. Eight
/// decimals matches the Table View export — a millisecond is ~1.2e-8 days.
List<(String, String)> _leading(Moment moment, String Function(Moment) label) {
  return [('JD', moment.ut.toStringAsFixed(8)), ('Date', label(moment))];
}
