// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calculation/series_layout.dart';
import 'calculation/series_settings.dart';
import 'calculation/series_spec.dart';
import 'calendar.dart';
import 'context_state.dart';
import 'flag_state.dart';
import '../layout/tab_definitions.dart';

/// Provider for the SharedPreferences instance, initialized in main().
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

class PersistenceService {
  PersistenceService(this._prefs);
  final SharedPreferences _prefs;

  // ── Context Bar ──

  void saveContextBar(ContextBarState s) {
    _prefs.setDouble('ctx_latitude', s.latitude);
    _prefs.setDouble('ctx_longitude', s.longitude);
    _prefs.setDouble('ctx_altitude', s.altitude);
    _prefs.setString('ctx_city_label', s.cityLabel);
    _prefs.setString('ctx_origin', s.origin.name);
    _prefs.setString('ctx_zodiac_ref', s.zodiacRef.name);
    _prefs.setString('ctx_eq_ref', s.eqRef.name);
    _prefs.setInt('ctx_ayanamsa', s.ayanamsa);
    _prefs.setInt('ctx_last_sidereal_ayanamsa', s.lastSiderealAyanamsa);
    _prefs.setDouble('ctx_user_ayan_t0', s.userAyanT0);
    _prefs.setDouble('ctx_user_ayan_value', s.userAyanValue);
    _prefs.setBool('ctx_user_ayan_t0_is_ut', s.userAyanT0IsUt);
    _prefs.setString('ctx_sidereal_projection', s.projection.name);
    _prefs.setString('ctx_ephe_source', s.epheSource.name);
    _prefs.setDouble('ctx_utc_offset', s.utcOffset);
    _prefs.setString('ctx_calendar', s.calendar.name);
  }

  /// Returns a map of overrides to apply to the initial ContextBarState.
  /// dateTime/jdUt are NOT persisted — always start at "now".
  Map<String, dynamic> loadContextBar() {
    final map = <String, dynamic>{};
    if (_prefs.containsKey('ctx_latitude')) {
      map['latitude'] = _prefs.getDouble('ctx_latitude');
    }
    if (_prefs.containsKey('ctx_longitude')) {
      map['longitude'] = _prefs.getDouble('ctx_longitude');
    }
    if (_prefs.containsKey('ctx_altitude')) {
      map['altitude'] = _prefs.getDouble('ctx_altitude');
    }
    if (_prefs.containsKey('ctx_city_label')) {
      map['cityLabel'] = _prefs.getString('ctx_city_label');
    }
    if (_prefs.containsKey('ctx_origin')) {
      final name = _prefs.getString('ctx_origin');
      map['origin'] = Origin.values.firstWhere(
        (e) => e.name == name,
        orElse: () => Origin.geocentric,
      );
    }
    if (_prefs.containsKey('ctx_zodiac_ref')) {
      final name = _prefs.getString('ctx_zodiac_ref');
      map['zodiacRef'] = ZodiacRef.values.firstWhere(
        (e) => e.name == name,
        orElse: () => ZodiacRef.tropical,
      );
    }
    if (_prefs.containsKey('ctx_eq_ref')) {
      final name = _prefs.getString('ctx_eq_ref');
      map['eqRef'] = EqRef.values.firstWhere(
        (e) => e.name == name,
        orElse: () => EqRef.trueEquinoxOfDate,
      );
    }
    if (_prefs.containsKey('ctx_ayanamsa')) {
      map['ayanamsa'] = _prefs.getInt('ctx_ayanamsa');
    }
    if (_prefs.containsKey('ctx_last_sidereal_ayanamsa')) {
      map['lastSiderealAyanamsa'] = _prefs.getInt('ctx_last_sidereal_ayanamsa');
    }
    if (_prefs.containsKey('ctx_user_ayan_t0')) {
      map['userAyanT0'] = _prefs.getDouble('ctx_user_ayan_t0');
    }
    if (_prefs.containsKey('ctx_user_ayan_value')) {
      map['userAyanValue'] = _prefs.getDouble('ctx_user_ayan_value');
    }
    if (_prefs.containsKey('ctx_user_ayan_t0_is_ut')) {
      map['userAyanT0IsUt'] = _prefs.getBool('ctx_user_ayan_t0_is_ut');
    }
    if (_prefs.containsKey('ctx_sidereal_projection')) {
      final name = _prefs.getString('ctx_sidereal_projection');
      map['projection'] = SiderealProjection.values.firstWhere(
        (e) => e.name == name,
        orElse: () => SiderealProjection.standard,
      );
    }
    if (_prefs.containsKey('ctx_ephe_source')) {
      final name = _prefs.getString('ctx_ephe_source');
      map['epheSource'] = EpheSource.values.firstWhere(
        (e) => e.name == name,
        orElse: () => EpheSource.swissEph,
      );
    }
    if (_prefs.containsKey('ctx_utc_offset')) {
      map['utcOffset'] = _prefs.getDouble('ctx_utc_offset');
    }
    if (_prefs.containsKey('ctx_calendar')) {
      final name = _prefs.getString('ctx_calendar');
      map['calendar'] = Calendar.values.firstWhere(
        (e) => e.name == name,
        orElse: () => Calendar.auto,
      );
    }
    return map;
  }

  // ── Flag Bar ──

  void saveFlagBar(FlagBarState s) {
    _prefs.setInt('flag_coord_value', s.coordValue);
    _prefs.setStringList(
      'flag_toggles',
      s.toggles.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> loadFlagBar() {
    final map = <String, dynamic>{};
    if (_prefs.containsKey('flag_coord_value')) {
      map['coordValue'] = _prefs.getInt('flag_coord_value');
    }
    if (_prefs.containsKey('flag_toggles')) {
      final list = _prefs.getStringList('flag_toggles') ?? [];
      map['toggles'] = list.map((s) => int.tryParse(s) ?? 0).toSet();
    }
    return map;
  }

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
    _prefs.setBool(_seriesKey(tabId, 'enabled'), s.enabled);
    _prefs.setDouble(_seriesKey(tabId, 'step_value'), s.stepValue);
    _prefs.setString(_seriesKey(tabId, 'step_unit'), s.stepUnit.name);
    _prefs.setInt(_seriesKey(tabId, 'row_count'), s.rowCount);
    _prefs.setStringList(
      _seriesKey(tabId, 'hidden_labels'),
      s.hiddenLabels.toList(),
    );
    _prefs.setString(_seriesKey(tabId, 'export_layout'), s.exportLayout.name);
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
      exportLayout: SeriesLayout.byName(
        _prefs.getString(_seriesKey(tabId, 'export_layout')),
        fallback: defaults.exportLayout,
      ),
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
