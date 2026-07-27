// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calculation/series_layout.dart';
import 'calculation/series_settings.dart';
import 'calculation/series_spec.dart';
import 'context_state.dart';
import 'flag_state.dart';
import 'pref_field.dart';
import '../layout/tab_definitions.dart';

/// Provider for the SharedPreferences instance, initialized in main().
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

class PersistenceService {
  PersistenceService(this._prefs);
  final SharedPreferences _prefs;

  /// Write every field of [fields] for [state].
  void _saveAll<S>(List<PrefField<S>> fields, S state) {
    for (final field in fields) {
      field.save(_prefs, state);
    }
  }

  /// Fold the stored values back onto [state]. A field with nothing usable
  /// stored leaves the state alone, so [state]'s own values are the defaults.
  S _restoreAll<S>(List<PrefField<S>> fields, S state) =>
      fields.fold(state, (s, field) => field.restore(_prefs, s));

  /// Store one standalone value — state that lives in its own provider rather
  /// than as a field of a persisted state class (the user-defined ayanamsha
  /// list). The codec keeps the encoding beside the type it encodes.
  void saveValue<T extends Object>(PrefCodec<T> codec, String key, T value) =>
      codec.write(_prefs, key, value);

  T? loadValue<T extends Object>(PrefCodec<T> codec, String key) =>
      codec.read(_prefs, key);

  // ── Context Bar ──

  /// dateTime/jdUt are NOT persisted — always start at "now". See
  /// [contextBarPrefFields] for the field list both directions fold over.
  void saveContextBar(ContextBarState s) => _saveAll(contextBarPrefFields, s);

  ContextBarState restoreContextBar(ContextBarState s) =>
      _restoreAll(contextBarPrefFields, s);

  // ── Flag Bar ──

  void saveFlagBar(FlagBarState s) => _saveAll(flagBarPrefFields, s);

  FlagBarState restoreFlagBar(FlagBarState s) =>
      _restoreAll(flagBarPrefFields, s);

  // ── Theme ──

  void saveTheme(ThemeMode mode) {
    _prefs.setString('theme', mode.name);
  }

  ThemeMode loadTheme() {
    final name = _prefs.getString('theme');
    if (name == null) return ThemeMode.dark;
    return ThemeMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ThemeMode.dark,
    );
  }

  // ── Zoom ──

  void saveZoom(double scale) {
    _prefs.setDouble('zoom', scale);
  }

  double loadZoom() {
    return _prefs.getDouble('zoom') ?? 1.0;
  }

  // ── Selected Tab ──

  void saveTab(AppTab tab) {
    _prefs.setString('tab', tab.name);
  }

  AppTab loadTab() {
    final name = _prefs.getString('tab');
    if (name == null) return AppTab.planets;
    return AppTab.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AppTab.planets,
    );
  }

  // ── Series mode (per tab) ──

  String _seriesKey(String tabId, String field) => 'series_${tabId}_$field';

  void saveSeriesSettings(String tabId, SeriesSettings s) {
    _prefs
      ..setBool(_seriesKey(tabId, 'enabled'), s.enabled)
      ..setDouble(_seriesKey(tabId, 'step_value'), s.stepValue)
      ..setString(_seriesKey(tabId, 'step_unit'), s.stepUnit.name)
      ..setInt(_seriesKey(tabId, 'row_count'), s.rowCount)
      ..setStringList(
        _seriesKey(tabId, 'hidden_labels'),
        s.hiddenLabels.toList(),
      )
      ..setString(_seriesKey(tabId, 'layout'), s.layout.name);
  }

  /// The layout, from the current key or migrated once from the one it
  /// replaced.
  ///
  /// `export_layout` was written when the choice reached only the file, and
  /// under it `vertical` named swetest's row-per-body shape — now [
  /// SeriesLayout.long]. Reading that value by name would resolve it onto
  /// today's `vertical`, the transpose, and silently change the shape under a
  /// user who never touched the setting. So the key changed with the
  /// vocabulary: a value under the new key is current, and one under only the
  /// old key is translated. The stale key is left where it is — the next save
  /// writes the new one, and nothing reads the old one again.
  SeriesLayout _seriesLayout(String tabId, SeriesLayout fallback) {
    final current = _prefs.getString(_seriesKey(tabId, 'layout'));
    if (current != null) {
      return SeriesLayout.byName(current, fallback: fallback);
    }
    return SeriesLayout.legacyByName(
      _prefs.getString(_seriesKey(tabId, 'export_layout')),
      fallback: fallback,
    );
  }

  /// Loaded field by field against the defaults, so a tab that has never been
  /// in series mode — and a stored unit name from a since-renamed enum —
  /// both come back as a usable default rather than as nothing.
  SeriesSettings loadSeriesSettings(String tabId) {
    const defaults = SeriesSettings();
    final unitName = _prefs.getString(_seriesKey(tabId, 'step_unit'));
    final unit = unitName == null
        ? defaults.stepUnit
        : StepUnit.values.firstWhere(
            (u) => u.name == unitName,
            orElse: () => defaults.stepUnit,
          );
    final stepValue =
        _prefs.getDouble(_seriesKey(tabId, 'step_value')) ?? defaults.stepValue;
    return SeriesSettings(
      enabled: _prefs.getBool(_seriesKey(tabId, 'enabled')) ?? defaults.enabled,
      // A stored value the unit no longer accepts (the unit changed, or an
      // older build wrote it) would otherwise reach the series as-is.
      stepValue: unit.snapStepValue(stepValue),
      stepUnit: unit,
      rowCount:
          _prefs.getInt(_seriesKey(tabId, 'row_count')) ?? defaults.rowCount,
      hiddenLabels:
          _prefs.getStringList(_seriesKey(tabId, 'hidden_labels'))?.toSet() ??
          defaults.hiddenLabels,
      layout: _seriesLayout(tabId, defaults.layout),
    );
  }

  // ── House System ──

  void saveHouseSystem(int code) {
    _prefs.setInt('houses_hsys', code);
  }

  int loadHouseSystem() {
    return _prefs.getInt('houses_hsys') ?? 0x50; // Placidus default
  }
}

/// Provider for PersistenceService — reads the SharedPreferences provider.
final persistenceProvider = Provider<PersistenceService>((ref) {
  return PersistenceService(ref.watch(sharedPrefsProvider));
});
