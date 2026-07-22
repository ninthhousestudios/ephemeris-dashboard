// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

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
    this.exportLayout = SeriesLayout.vertical,
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

  /// Which shape the export offers first. A setting rather than widget state
  /// because a user who works in horizontal wants it on the next tab too —
  /// the same reason the hidden quantities are stored.
  final SeriesLayout exportLayout;

  bool showsLabel(String label) => !hiddenLabels.contains(label);

  /// The series to compute from [start], which is the Context Moment.
  SeriesSpec specFrom(Moment start) => SeriesSpec(
    start: start,
    stepValue: stepValue,
    stepUnit: stepUnit,
    rowCount: rowCount,
  );

  SeriesSettings copyWith({
    bool? enabled,
    double? stepValue,
    StepUnit? stepUnit,
    int? rowCount,
    Set<String>? hiddenLabels,
    SeriesLayout? exportLayout,
  }) => SeriesSettings(
    enabled: enabled ?? this.enabled,
    stepValue: stepValue ?? this.stepValue,
    stepUnit: stepUnit ?? this.stepUnit,
    rowCount: rowCount ?? this.rowCount,
    hiddenLabels: hiddenLabels ?? this.hiddenLabels,
    exportLayout: exportLayout ?? this.exportLayout,
  );
}
