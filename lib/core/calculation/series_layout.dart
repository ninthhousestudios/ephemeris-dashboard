// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Which axis the steps of a series run along, on screen and in the export.
///
/// The two are transposes of each other, not two different tables: the same
/// built `SeriesTable` read along either axis.
///
/// Its own file, with no dependencies: [SeriesSettings] persists the choice,
/// and `series_export.dart` and `SeriesGrid` act on it. The settings type has
/// no business pulling in the export stack (and `package:file_saver` behind
/// it) to name a layout.
enum SeriesLayout {
  /// Steps across the x-axis, one row per (row identifier, quantity).
  vertical('Vertical (row per body)'),

  /// Steps down the y-axis, one row per step — swetest's `-hor`.
  horizontal('Horizontal (row per step)');

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
