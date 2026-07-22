// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../persistence.dart';
import 'series_layout.dart';
import 'series_settings.dart';
import 'series_spec.dart';

/// Owns one tab's [SeriesSettings], persisting every change.
///
/// The step-value rules live here rather than in the widget so the invariant
/// "the stored step value is one the unit accepts" holds no matter which
/// surface set it.
class SeriesSettingsNotifier extends StateNotifier<SeriesSettings> {
  SeriesSettingsNotifier(this._persistence, this._tabId)
    : super(_persistence.loadSeriesSettings(_tabId));

  final PersistenceService _persistence;
  final String _tabId;

  void _set(SeriesSettings next) {
    state = next;
    _persistence.saveSeriesSettings(_tabId, next);
  }

  void setEnabled(bool enabled) => _set(state.copyWith(enabled: enabled));

  /// Accepts [value] only if the current unit can use it — a negative value
  /// runs the series backward (swetest `-bwd`), but zero, NaN and a fractional
  /// number of months are not series. Returns whether it was taken, so a text
  /// field can tell a rejected value from an accepted one.
  bool setStepValue(double value) {
    if (!state.stepUnit.acceptsStepValue(value)) return false;
    _set(state.copyWith(stepValue: value));
    return true;
  }

  /// Switches unit, snapping the step value if the new unit cannot use it
  /// (2.5 Days is meaningful, 2.5 Months is not). Returns the value now in
  /// effect so the caller can keep its input field in agreement with it.
  double setStepUnit(StepUnit unit) {
    final value = unit.snapStepValue(state.stepValue);
    _set(state.copyWith(stepUnit: unit, stepValue: value));
    return value;
  }

  /// Sets the requested row count. Values above the hard cap are stored as
  /// asked and capped at compute time by [SeriesSpec], which is what makes the
  /// cap visible to the user as a warning instead of silently rewriting input.
  bool setRowCount(int rows) {
    if (rows < 1) return false;
    _set(state.copyWith(rowCount: rows));
    return true;
  }

  void setExportLayout(SeriesLayout layout) =>
      _set(state.copyWith(exportLayout: layout));

  void setLabelVisible(String label, bool visible) {
    final hidden = {...state.hiddenLabels};
    if (visible) {
      hidden.remove(label);
    } else {
      hidden.add(label);
    }
    _set(state.copyWith(hiddenLabels: hidden));
  }
}

/// Per-tab series settings, keyed by `TabDescriptor.id`.
///
/// Keyed by a plain String rather than by `AppTab` so the series widgets stay
/// free of tab-specific types and `lib/core` stays free of `lib/layout`.
final seriesSettingsProvider =
    StateNotifierProvider.family<
      SeriesSettingsNotifier,
      SeriesSettings,
      String
    >(
      (ref, tabId) =>
          SeriesSettingsNotifier(ref.watch(persistenceProvider), tabId),
    );
