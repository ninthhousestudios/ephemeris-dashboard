// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../core/export_service.dart';
import 'result_card.dart';

/// One card's worth of a Result: the card title, its subtitle, and its fields.
///
/// A tab builds its sections once and uses them for *both* encodings — the
/// [ResultCard] widgets and, via [sectionsToExportRows], the CSV / series
/// columns / quantity chips. That is what keeps the two from drifting: a label
/// or a formatter lives in one place, so it cannot be renamed on one side only
/// (yojana swe-dashboard/91).
class ResultSection {
  const ResultSection({
    required this.title,
    this.subtitle,
    this.flagHex,
    required this.fields,
  });

  /// Card title — also the export row header.
  final String title;

  /// Card subtitle. Card-only: export rows have no room for it.
  final String? subtitle;

  /// Return-flag hex, shown in the card header. Card-only, like [subtitle].
  final String? flagHex;

  final List<ResultField> fields;

  /// This section as a card.
  ResultCard toCard() => ResultCard(
    title: title,
    subtitle: subtitle,
    flagHex: flagHex,
    fields: fields,
  );
}

/// Project card sections into export rows, one row per section.
///
/// Empty sections are dropped — an export column set is built from the union of
/// what the steps actually carry, so a headerless empty row is only noise.
List<ExportRow> sectionsToExportRows(List<ResultSection> sections) => [
  for (final s in sections)
    if (s.fields.isNotEmpty)
      ExportRow(
        header: s.title,
        fields: [for (final f in s.fields) (f.label, f.value)],
      ),
];
