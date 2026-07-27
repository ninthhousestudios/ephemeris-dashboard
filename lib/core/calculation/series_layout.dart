// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// How a series is shaped, on screen and in the export.
///
/// [vertical] and [horizontal] are transposes of each other — the same built
/// `SeriesTable` read along either axis. [long] is neither: it trades the wide
/// shape for a tall one, which is what a spreadsheet or a dataframe wants.
///
/// Its own file, with no dependencies: [SeriesSettings] persists the choice,
/// and `series_export.dart` and `SeriesGrid` act on it. The settings type has
/// no business pulling in the export stack (and `package:file_saver` behind
/// it) to name a layout.
enum SeriesLayout {
  /// Steps across the x-axis, one row per (row identifier, quantity).
  vertical('Vertical (steps across)'),

  /// Steps down the y-axis, one row per step — swetest's `-hor`.
  horizontal('Horizontal (steps down)'),

  /// One row per (step, row identifier), quantities as the columns — swetest's
  /// own default, and the tidy shape that loads into a dataframe as-is where
  /// the other two need reshaping first.
  long('Long (row per step & body)');

  const SeriesLayout(this.label);

  final String label;

  /// Round-trips through persistence by [name], falling back rather than
  /// throwing on a value written by a build that named its layouts differently.
  static SeriesLayout byName(String? name, {SeriesLayout fallback = vertical}) {
    if (name == null) return fallback;
    for (final layout in values) {
      if (layout.name == name) return layout;
    }
    return fallback;
  }
}
