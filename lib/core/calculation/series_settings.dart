// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../calendar.dart';
import 'moment.dart';
import 'series_layout.dart';
import 'series_spec.dart';

/// A tab's series-mode settings: whether the tab is in series mode, and the
/// shape of the series if it is.
///
/// The start Moment is deliberately absent — it is the Context Moment, and the
/// Context owns it. A series setting that could disagree with the Context bar
/// is a second source of truth for the same quantity.
class SeriesSettings {
  const SeriesSettings({
    this.enabled = false,
    this.stepValue = 1.0,
    this.stepUnit = StepUnit.days,
    this.rowCount = 30,
    this.hiddenLabels = const {},
    this.layout = SeriesLayout.horizontal,
  });

  /// Series mode is per-tab and defaults off: 7 of 17 tabs are ineligible, so
  /// a global toggle would be a no-op or actively misleading on them.
  final bool enabled;

  final double stepValue;
  final StepUnit stepUnit;
  final int rowCount;

  /// Quantities the user has switched off, by field label.
  ///
  /// Stored as the *hidden* set rather than the visible one so the picker
  /// defaults to all-on and a quantity added to a tab later shows up without
  /// the user having to go and enable it.
  final Set<String> hiddenLabels;

  /// The shape the series is shown *and* exported in — one setting, because a
  /// screen that disagreed with the file it saves is what made the layout
  /// choice read as broken. A setting rather than widget state because a user
  /// who works in horizontal wants it on the next tab too — the same reason
  /// the hidden quantities are stored.
  ///
  /// Persisted under `layout`, which replaced `export_layout` from when the
  /// choice only reached the file. The key had to change with it: `vertical`
  /// named a different shape under the old one, so keeping the key would have
  /// kept the spelling and quietly swapped the meaning. `PersistenceService`
  /// translates a value found under only the old key.
  final SeriesLayout layout;

  bool showsLabel(String label) => !hiddenLabels.contains(label);

  /// The series to compute from [start], which is the Context Moment, stepping
  /// the month/year units on [calendar] — also Context-owned, and absent from
  /// the settings for the same reason [start] is.
  SeriesSpec specFrom(Moment start, [Calendar calendar = Calendar.gregorian]) =>
      SeriesSpec(
        start: start,
        stepValue: stepValue,
        stepUnit: stepUnit,
        rowCount: rowCount,
        calendar: calendar,
      );

  SeriesSettings copyWith({
    bool? enabled,
    double? stepValue,
    StepUnit? stepUnit,
    int? rowCount,
    Set<String>? hiddenLabels,
    SeriesLayout? layout,
  }) => SeriesSettings(
    enabled: enabled ?? this.enabled,
    stepValue: stepValue ?? this.stepValue,
    stepUnit: stepUnit ?? this.stepUnit,
    rowCount: rowCount ?? this.rowCount,
    hiddenLabels: hiddenLabels ?? this.hiddenLabels,
    layout: layout ?? this.layout,
  );
}
