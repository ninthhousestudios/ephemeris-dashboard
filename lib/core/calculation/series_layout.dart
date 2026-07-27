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
  ///
  /// The bare [fallback] tracks `SeriesSettings`'s own default; persistence
  /// always passes `defaults.layout` explicitly rather than relying on it,
  /// since this file deliberately has no dependency on the settings type.
  static SeriesLayout byName(
    String? name, {
    SeriesLayout fallback = horizontal,
  }) {
    if (name == null) return fallback;
    for (final layout in values) {
      if (layout.name == name) return layout;
    }
    return fallback;
  }

  /// Resolves a name written under the superseded key `export_layout`, where
  /// the layouts were named for the export alone and `vertical` meant what is
  /// now [long] — swetest's row per body — rather than the transpose.
  ///
  /// The spelling survived the rename but the shape it names did not, so a
  /// stored `vertical` read through [byName] would resolve onto the new case
  /// of the same name and hand back a layout the user never chose. This is why
  /// the persisted key changed with the vocabulary rather than being kept.
  static SeriesLayout legacyByName(
    String? name, {
    required SeriesLayout fallback,
  }) => switch (name) {
    'vertical' => long,
    'horizontal' => horizontal,
    _ => fallback,
  };
}
