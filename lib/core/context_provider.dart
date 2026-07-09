// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import 'context_state.dart';
import 'jd_utils.dart';
import 'persistence.dart';
import 'swe_service.dart';
import 'chart_io.dart';

/// Global context bar state provider.
final contextBarProvider =
    StateNotifierProvider<ContextBarNotifier, ContextBarState>((ref) {
      final swe = ref.watch(sweProvider);
      final persistence = ref.watch(persistenceProvider);
      return ContextBarNotifier(swe, persistence);
    });

/// Manages context bar state with bidirectional JD ↔ DateTime sync.
class ContextBarNotifier extends StateNotifier<ContextBarState> {
  ContextBarNotifier(SwissEph swe, this._persistence)
    : _jdUtils = JdUtils(swe),
      super(_initialState(swe)) {
    restoreFromPersistence();
  }

  final JdUtils _jdUtils;
  final PersistenceService _persistence;

  static ContextBarState _initialState(SwissEph swe) {
    final now = DateTime.now().toUtc();
    final jdUtils = JdUtils(swe);
    final jd = jdUtils.dateTimeToJd(now);
    final localOffset = DateTime.now().timeZoneOffset.inMinutes / 60.0;
    return ContextBarState(dateTime: now, utcOffset: localOffset, jdUt: jd);
  }

  /// Apply persisted values after construction (called from provider factory).
  void restoreFromPersistence() {
    final overrides = _persistence.loadContextBar();
    if (overrides.isEmpty) return;
    state = state.copyWith(
      latitude: overrides['latitude'] as double?,
      longitude: overrides['longitude'] as double?,
      altitude: overrides['altitude'] as double?,
      cityLabel: overrides['cityLabel'] as String?,
      origin: overrides['origin'] as Origin?,
      zodiacRef: overrides['zodiacRef'] as ZodiacRef?,
      eqRef: overrides['eqRef'] as EqRef?,
      ayanamsa: overrides['ayanamsa'] as int?,
      userAyanT0: overrides['userAyanT0'] as double?,
      userAyanValue: overrides['userAyanValue'] as double?,
      epheSource: hasEpheFiles
          ? overrides['epheSource'] as EpheSource?
          : EpheSource.moshier,
      utcOffset: overrides['utcOffset'] as double?,
    );
  }

  void _save() => _persistence.saveContextBar(state);

  /// Set date/time (UT) — JD is recomputed.
  void setDateTime(DateTime dt) {
    final jd = _jdUtils.dateTimeToJd(dt);
    state = state.copyWith(dateTime: dt, jdUt: jd);
    // dateTime not persisted
  }

  /// Set Julian Day — DateTime is recomputed.
  void setJd(double jd) {
    final dt = _jdUtils.jdToDateTime(jd);
    state = state.copyWith(jdUt: jd, dateTime: dt);
    // jd not persisted
  }

  /// Set UTC offset (display only — does not change UT or JD).
  void setUtcOffset(double offsetHours) {
    state = state.copyWith(utcOffset: offsetHours);
    _save();
  }

  /// Set "now" — current system time.
  void setNow() {
    final now = DateTime.now().toUtc();
    final jd = _jdUtils.dateTimeToJd(now);
    state = state.copyWith(dateTime: now, jdUt: jd);
    // dateTime not persisted
  }

  /// Set geographic location.
  void setLocation({
    required double latitude,
    required double longitude,
    double? altitude,
    String? cityLabel,
  }) {
    state = state.copyWith(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      cityLabel: cityLabel,
    );
    _save();
  }

  void setLatitude(double v) {
    state = state.copyWith(latitude: v);
    _save();
  }

  void setLongitude(double v) {
    state = state.copyWith(longitude: v);
    _save();
  }

  void setAltitude(double v) {
    state = state.copyWith(altitude: v);
    _save();
  }

  void setCityLabel(String v) {
    state = state.copyWith(cityLabel: v);
    _save();
  }

  void setOrigin(Origin origin) {
    state = state.copyWith(origin: origin);
    _save();
  }

  void setZodiacRef(ZodiacRef zodiacRef) {
    state = state.copyWith(zodiacRef: zodiacRef);
    _save();
  }

  void setEqRef(EqRef eqRef) {
    state = state.copyWith(eqRef: eqRef);
    _save();
  }

  void setAyanamsa(int sidMode) {
    state = state.copyWith(ayanamsa: sidMode);
    _save();
  }

  /// Set user-defined ayanamsa parameters (SE_SIDM_USER, 255).
  void setUserAyanamsa({required double t0, required double value}) {
    state = state.copyWith(userAyanT0: t0, userAyanValue: value);
    _save();
  }

  void setEpheSource(EpheSource source) {
    // Force Moshier when no ephemeris files are available (e.g. web).
    final effective = hasEpheFiles ? source : EpheSource.moshier;
    state = state.copyWith(epheSource: effective);
    _save();
  }

  /// Load context from a parsed chart file.
  void loadFromChart(ChartData chart) {
    final utcDt = chart.utcDateTime;
    final jd = _jdUtils.dateTimeToJd(utcDt);
    final totalOffset = chart.utcOffsetHours + chart.dstOffsetHours;
    final loc = chart.birthLocation;
    state = state.copyWith(
      dateTime: utcDt,
      jdUt: jd,
      utcOffset: totalOffset,
      latitude: loc.latitude,
      longitude: loc.longitude,
      cityLabel: '${loc.city}, ${loc.country}',
    );
    _save();
  }
}
