// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../export_service.dart';
import 'calc_outcome.dart';
import 'moment.dart';

/// One step of a series, already projected through the tab's own
/// `*ToExportRows`. The [CalcOutcome] is per step, so one failing step is one
/// error row rather than an empty grid.
typedef SeriesStep = (Moment, CalcOutcome<List<ExportRow>>);

/// A grid column: one quantity of one row identifier, e.g. `("Sun",
/// "Longitude")`.
///
/// The pair is the identity because neither half is unique on its own — every
/// body has a "Longitude" and the Sun has several quantities. Making it the
/// identity is what lets the column set be a union across steps instead of a
/// shape the series has to promise up front.
class SeriesColumn {
  const SeriesColumn(this.header, this.label);

  /// `ExportRow.header` — the row identifier the quantity belongs to.
  final String header;

  /// The quantity's field label.
  final String label;

  /// Column heading. A tab whose rows have no meaningful identifier (one row
  /// per step) leaves the header empty and shows the bare label.
  String get title => header.isEmpty ? label : '$header $label';

  @override
  bool operator ==(Object other) =>
      other is SeriesColumn && other.header == header && other.label == label;

  @override
  int get hashCode => Object.hash(header, label);

  @override
  String toString() => 'SeriesColumn($header, $label)';
}

/// One grid row: a Moment and its cells, or a Moment and an error.
class SeriesTableRow {
  const SeriesTableRow({
    required this.moment,
    required this.values,
    this.error,
  });

  final Moment moment;

  /// Cell text by column. Absent keys render empty — a body that dropped out
  /// of this step is a hole in the row, not a shifted column.
  final Map<SeriesColumn, String> values;

  /// Step-level failure message, null on a successful step.
  final String? error;

  bool get isError => error != null;
}

/// The grid, ready to render: a stable column set and one row per step.
class SeriesTable {
  const SeriesTable({required this.columns, required this.rows});

  final List<SeriesColumn> columns;
  final List<SeriesTableRow> rows;

  bool get isEmpty => rows.isEmpty;
  bool get hasErrors => rows.any((r) => r.isError);
}

/// One row of the vertical shape: a single step's values for a single row
/// identifier, keyed by field label.
class SeriesVerticalRow {
  const SeriesVerticalRow({
    required this.moment,
    required this.header,
    required this.values,
    this.error,
  });

  final Moment moment;

  /// The row identifier — `ExportRow.header`. Empty on an errored step, and on
  /// a tab whose rows carry no identifier.
  final String header;

  /// Cell text by field label, in the column order of the source table.
  final Map<String, String> values;

  /// Step-level failure message, null on a successful step.
  final String? error;

  bool get isError => error != null;
}

/// The vertical shape of a [SeriesTable]: one row per (step, row identifier),
/// quantities as the columns.
///
/// Derived rather than built alongside the horizontal table, because the two
/// must not disagree: the source table has already dropped the hidden
/// quantities and fixed the column order, so both shapes inherit those.
class SeriesVerticalTable {
  const SeriesVerticalTable({required this.labels, required this.rows});

  /// Distinct quantity labels in column order. Shared across row identifiers —
  /// every body has the same quantities — which is what makes the shape
  /// rectangular where the horizontal one is wide.
  final List<String> labels;

  final List<SeriesVerticalRow> rows;

  /// Whether the row identifier earns a column. A tab with one row per step
  /// leaves the header empty, and a column of blanks is worse than no column —
  /// the same call [SeriesColumn.title] makes for the horizontal heading.
  bool get hasIdentifiers => rows.any((r) => r.header.isNotEmpty);

  bool get isEmpty => rows.isEmpty;
  bool get hasErrors => rows.any((r) => r.isError);
}

/// Re-shapes [table] into one row per (step, row identifier).
///
/// A row identifier that contributed nothing to a step yields no row at all,
/// rather than a row of blanks that would read as a result of "".
SeriesVerticalTable toVerticalTable(SeriesTable table) {
  final headers = <String>[];
  final seenHeaders = <String>{};
  final labels = <String>[];
  final seenLabels = <String>{};
  for (final column in table.columns) {
    if (seenHeaders.add(column.header)) headers.add(column.header);
    if (seenLabels.add(column.label)) labels.add(column.label);
  }

  final rows = <SeriesVerticalRow>[];
  for (final row in table.rows) {
    if (row.error case final message?) {
      rows.add(
        SeriesVerticalRow(
          moment: row.moment,
          header: '',
          values: const {},
          error: message,
        ),
      );
      continue;
    }
    for (final header in headers) {
      final values = <String, String>{};
      for (final column in table.columns) {
        if (column.header != header) continue;
        final value = row.values[column];
        if (value != null) values[column.label] = value;
      }
      if (values.isNotEmpty) {
        rows.add(
          SeriesVerticalRow(moment: row.moment, header: header, values: values),
        );
      }
    }
  }

  return SeriesVerticalTable(labels: labels, rows: rows);
}

/// Folds [steps] into a grid.
///
/// The column set is the union across all steps in first-appearance order, so
/// step 0 dictates the layout and later steps only ever append. That is what
/// keeps an errored step — or a body that drops out mid-series — from shifting
/// the columns under the ones that came before it.
///
/// [hiddenLabels] drops quantities by field label (not by column), because the
/// quantity picker is per-quantity, not per-body: hiding "Latitude" hides it
/// for every body at once.
SeriesTable buildSeriesTable(
  List<SeriesStep> steps, {
  Set<String> hiddenLabels = const {},
}) {
  final columns = <SeriesColumn>[];
  final seen = <SeriesColumn>{};
  final rows = <SeriesTableRow>[];

  for (final (moment, outcome) in steps) {
    switch (outcome) {
      case CalcError(message: final message):
        rows.add(
          SeriesTableRow(moment: moment, values: const {}, error: message),
        );
      case CalcOk(value: final exportRows):
        final values = <SeriesColumn, String>{};
        for (final row in exportRows) {
          for (final (label, value) in row.fields) {
            if (hiddenLabels.contains(label)) continue;
            final column = SeriesColumn(row.header, label);
            if (seen.add(column)) columns.add(column);
            values[column] = value;
          }
        }
        rows.add(SeriesTableRow(moment: moment, values: values));
    }
  }

  return SeriesTable(columns: columns, rows: rows);
}

/// The quantities the picker offers, in display order.
///
/// Taken from the first step that computed, not from every step: the picker is
/// a stable control, and letting it grow a chip because step 400 failed
/// differently would make it flicker as the Context moves. Field labels are
/// deduplicated across the step's rows — every body contributes the same
/// quantities.
List<String> seriesFieldLabels(List<SeriesStep> steps) {
  for (final (_, outcome) in steps) {
    if (outcome case CalcOk(value: final exportRows)) {
      final labels = <String>[];
      final seen = <String>{};
      for (final row in exportRows) {
        for (final (label, _) in row.fields) {
          if (seen.add(label)) labels.add(label);
        }
      }
      return labels;
    }
  }
  return const [];
}
