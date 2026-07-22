// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// The two shapes swetest emits for a series.
///
/// Its own file, with no dependencies: [SeriesSettings] persists the choice
/// and `series_export.dart` acts on it, and the settings type has no business
/// pulling in the export stack (and `package:file_saver` behind it) to name a
/// layout.
enum SeriesLayout {
  /// One row per (step, row identifier) — swetest's default.
  vertical('Vertical (row per body)'),

  /// One row per step, every quantity flattened across — swetest's `-hor`.
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
