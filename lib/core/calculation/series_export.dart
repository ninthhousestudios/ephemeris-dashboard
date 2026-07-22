// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../export_service.dart';
import 'moment.dart';
import 'series_table.dart';

/// The two shapes swetest emits for a series.
enum SeriesLayout {
  /// One row per (step, row identifier) — swetest's default.
  vertical('Vertical (row per body)'),

  /// One row per step, every quantity flattened across — swetest's `-hor`.
  horizontal('Horizontal (row per step)');

  const SeriesLayout(this.label);

  final String label;
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

  final rows = <ExportRow>[];
  for (final row in table.rows) {
    final leading = _leading(row.moment, label);
    if (row.error case final message?) {
      rows.add(ExportRow(header: '', fields: [...leading, ('Error', message)]));
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
      return ExportRow(
        header: leading.last.$2,
        fields: [...leading, ('Error', message)],
      );
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

/// JD then the formatted date, leading every row in both layouts. Eight
/// decimals matches the Table View export — a millisecond is ~1.2e-8 days.
List<(String, String)> _leading(Moment moment, String Function(Moment) label) {
  return [('JD', moment.ut.toStringAsFixed(8)), ('Date', label(moment))];
}
