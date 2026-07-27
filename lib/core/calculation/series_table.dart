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

/// The heading a step-level failure gets, kept clear of the headings in
/// [taken].
///
/// A per-body `Error` is a quantity like any other — planets, stars,
/// other_bodies and rise_set all emit one — so in a shape where such a field
/// is headed by the bare word `Error`, a step-level error column of the same
/// name is a second, unrelated column wearing an identical label. The grid
/// then shows two indistinguishable `Error` headings while `ExportService`,
/// which keys its schema on the label, folds them into one: the screen and the
/// file disagree on exactly the series that has both kinds of error.
///
/// Every shape derives the name from here, so none of them can disagree about
/// which error is which.
String stepErrorHeading(Iterable<String> taken) =>
    taken.contains('Error') ? 'Step Error' : 'Error';

/// The grid, ready to render: a stable column set and one row per step.
class SeriesTable {
  const SeriesTable({required this.columns, required this.rows});

  final List<SeriesColumn> columns;
  final List<SeriesTableRow> rows;

  bool get isEmpty => rows.isEmpty;
  bool get hasErrors => rows.any((r) => r.isError);

  /// Heading for the step-level error column, clear of the column titles —
  /// which is where the wide shapes would collide, a tab with no row
  /// identifier titling its per-body error column `Error` outright.
  String get errorHeading => stepErrorHeading(columns.map((c) => c.title));
}

/// One row of the long shape: a single step's values for a single row
/// identifier, keyed by field label.
class SeriesLongRow {
  const SeriesLongRow({
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

/// The long shape of a [SeriesTable]: one row per (step, row identifier),
/// quantities as the columns.
///
/// Derived rather than built alongside the source table, because the two must
/// not disagree: the source has already dropped the hidden quantities and
/// fixed the column order, so every shape inherits those.
class SeriesLongTable {
  const SeriesLongTable({required this.labels, required this.rows});

  /// Distinct quantity labels in column order. Shared across row identifiers —
  /// every body has the same quantities — which is what makes this shape
  /// narrow where the horizontal one is wide.
  final List<String> labels;

  final List<SeriesLongRow> rows;

  /// Whether the row identifier earns a column. A tab with one row per step
  /// leaves the header empty, and a column of blanks is worse than no column —
  /// the same call [SeriesColumn.title] makes for the horizontal heading.
  bool get hasIdentifiers => rows.any((r) => r.header.isNotEmpty);

  bool get isEmpty => rows.isEmpty;
  bool get hasErrors => rows.any((r) => r.isError);

  /// Heading for the step-level error column, clear of the quantity labels —
  /// which is where this shape collides, a per-body `Error` field being one of
  /// the shared labels rather than part of a wider column title.
  String get errorHeading => stepErrorHeading(labels);
}

/// Re-shapes [table] into one row per (step, row identifier).
///
/// A row identifier that contributed nothing to a step yields no row at all,
/// rather than a row of blanks that would read as a result of "".
SeriesLongTable toLongTable(SeriesTable table) {
  final headers = <String>[];
  final seenHeaders = <String>{};
  final labels = <String>[];
  final seenLabels = <String>{};
  for (final column in table.columns) {
    if (seenHeaders.add(column.header)) headers.add(column.header);
    if (seenLabels.add(column.label)) labels.add(column.label);
  }

  final rows = <SeriesLongRow>[];
  for (final row in table.rows) {
    if (row.error case final message?) {
      rows.add(
        SeriesLongRow(
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
          SeriesLongRow(moment: row.moment, header: header, values: values),
        );
      }
    }
  }

  return SeriesLongTable(labels: labels, rows: rows);
}

/// Column headings for the transposed shape, where the steps run across.
///
/// Transposing a [SeriesTable] is otherwise nothing but reading its two lists
/// the other way round — [SeriesTable.columns] become the rows, [SeriesTable
/// .rows] the columns — so this naming is the only part worth sharing between
/// the grid and the export.
///
/// Deduplicated by suffix: a step whose Moment formats exactly like an earlier
/// one (a step finer than the display resolution) would otherwise collide, and
/// both `ExportService` and a reader key on this string.
List<String> transposedStepLabels(
  SeriesTable table,
  String Function(Moment) label,
) {
  final counts = <String, int>{};
  final labels = <String>[];
  for (final row in table.rows) {
    final base = label(row.moment);
    final seen = counts.update(base, (n) => n + 1, ifAbsent: () => 1);
    labels.add(seen == 1 ? base : '$base ($seen)');
  }
  return labels;
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
