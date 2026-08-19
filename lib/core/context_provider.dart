// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ayanamsa_catalog.dart';
import 'calendar.dart';
import 'context_state.dart';
import 'jd_utils.dart';
import 'persistence.dart';
import 'ephe/bootstrap.dart';
import 'swe_utils_provider.dart';
import 'swe_utils.dart';
import 'time_scale.dart';
import 'user_ayanamsa.dart';
import 'chart_io.dart';

/// Global context bar state provider.
final contextBarProvider =
    StateNotifierProvider<ContextBarNotifier, ContextBarState>((ref) {
      final swe = ref.watch(sweProvider);
      final persistence = ref.watch(persistenceProvider);
      final notifier = ContextBarNotifier(
        swe,
        persistence,
        ref.watch(epheBootstrapProvider).hasEpheFiles,
      );

      // The Context holds an id into a list it does not own, so it reconciles
      // against that list from here rather than the list reaching back into it.
      // Once at creation, because the restored id can name an entry the store
      // no longer has; and on every later edit, because deleting the selected
      // entry has to move the selection instead of dangling it.
      void reconcile(List<UserAyanamsa> entries) =>
          notifier.reconcileUserAyanamsa([for (final u in entries) u.id]);
      reconcile(ref.read(userAyanamsasProvider));
      ref.listen<List<UserAyanamsa>>(
        userAyanamsasProvider,
        (_, entries) => reconcile(entries),
      );

      return notifier;
    });

/// Manages context bar state with bidirectional JD ↔ DateTime sync.
class ContextBarNotifier extends StateNotifier<ContextBarState> {
  ContextBarNotifier(SweUtils swe, this._persistence, this._hasEpheFiles)
    : _jdUtils = JdUtils(swe),
      super(_initialState(swe, _hasEpheFiles)) {
    restoreFromPersistence();
  }

  final JdUtils _jdUtils;
  final PersistenceService _persistence;

  /// Whether startup staged any `.se1` files. When false the Ephemeris
  /// Source is pinned to Moshier no matter what is persisted or selected.
  final bool _hasEpheFiles;

  static ContextBarState _initialState(SweUtils swe, bool hasEpheFiles) {
    final now = DateTime.now().toUtc();
    final jdUtils = JdUtils(swe);
    final jd = jdUtils.dateTimeToJd(now);
    final localOffset = DateTime.now().timeZoneOffset.inMinutes / 60.0;
    return ContextBarState(
      utcOffset: localOffset,
      jdUt: jd,
      // Prefer the ephemeris we ship. `ContextBarState`'s own default stays
      // Moshier, which is what a build with no .se1 files has to fall back to.
      epheSource: hasEpheFiles ? EpheSource.swissEph : EpheSource.moshier,
    );
  }

  /// Apply persisted values after construction (called from provider factory).
  ///
  /// Which fields those are is [contextBarPrefFields]' business, not this
  /// method's — the restore folds over the same list the save writes.
  void restoreFromPersistence() {
    state = _persistence.restoreContextBar(state);
    // The one field the store does not get the last word on: with no .se1
    // files staged, a persisted Swiss Ephemeris choice is unusable.
    if (!_hasEpheFiles) {
      state = state.copyWith(epheSource: EpheSource.moshier);
    }
  }

  void _save() => _persistence.saveContextBar(state);

  /// Set Julian Day. The Moment is canonical; the civil view is derived on read.
  void setJd(double jd) {
    state = state.copyWith(jdUt: jd);
    // jd not persisted
  }

  /// Set the calendar civil dates are read/rendered in. The Moment (JD) stays
  /// canonical; only the derived civil view changes, so the displayed date is
  /// recomputed from [jdUt] under the new calendar.
  void setCalendar(Calendar calendar) {
    state = state.copyWith(calendar: calendar);
    _save();
  }

  /// Set the time scale the civil date/time is entered/displayed on. The Moment
  /// (UT1 JD) stays canonical; only the derived civil view changes. Advisory —
  /// never reaches a compute.
  void setTimeScale(TimeScale scale) {
    state = state.copyWith(timeScale: scale);
    _save();
  }

  /// Set UTC offset (display only — does not change UT or JD).
  void setUtcOffset(double offsetHours) {
    state = state.copyWith(utcOffset: offsetHours);
    _save();
  }

  /// Set "now" — current system time.
  void setNow() {
    final jd = _jdUtils.dateTimeToJd(DateTime.now().toUtc());
    state = state.copyWith(jdUt: jd);
    // jd not persisted
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
    if (zodiacRef == ZodiacRef.sidereal &&
        state.zodiacRef == ZodiacRef.tropical) {
      state = state.copyWith(
        zodiacRef: zodiacRef,
        ayanamsa: state.lastSiderealAyanamsa,
      );
    } else if (zodiacRef == ZodiacRef.tropical &&
        state.zodiacRef == ZodiacRef.sidereal) {
      final stash = state.ayanamsa != ayanamsaTropicalId ? state.ayanamsa : 0;
      state = state.copyWith(
        zodiacRef: zodiacRef,
        lastSiderealAyanamsa: stash,
        ayanamsa: ayanamsaTropicalId,
      );
    } else {
      state = state.copyWith(zodiacRef: zodiacRef);
    }
    _save();
  }

  void setEqRef(EqRef eqRef) {
    state = state.copyWith(eqRef: eqRef);
    _save();
  }

  void setAyanamsa(int sidMode) {
    state = state.copyWith(
      ayanamsa: sidMode,
      lastSiderealAyanamsa: sidMode != ayanamsaTropicalId
          ? sidMode
          : state.lastSiderealAyanamsa,
    );
    _save();
  }

  /// Select a user-defined ayanamsha (SE_SIDM_USER, 255) by id. Its parameters
  /// (t0, value, `jdisut`) live in the entry itself, in `userAyanamsasProvider`
  /// — this only records which entry the chart uses.
  void selectUserAyanamsa(int id) {
    state = state.copyWith(
      ayanamsa: ayanamsaUserId,
      lastSiderealAyanamsa: ayanamsaUserId,
      userAyanId: id,
    );
    _save();
  }

  /// Keep the selection from dangling when the user-defined list changes.
  ///
  /// Called with the surviving entry ids when the Context is created — a
  /// restored id can name an entry the store no longer has — and after every
  /// later edit to `userAyanamsasProvider`. Losing the selected entry falls
  /// back to another user-defined one if there is one, and otherwise off
  /// user-defined entirely: leaving 255 selected with no entry behind it would
  /// give the dropdown nothing to show and the engine no parameters to
  /// configure from. Ids rather than entries because that is all this needs.
  void reconcileUserAyanamsa(List<int> entryIds) {
    if (state.ayanamsa != ayanamsaUserId) return;
    if (entryIds.contains(state.userAyanId)) return;
    if (entryIds.isNotEmpty) {
      selectUserAyanamsa(entryIds.first);
    } else {
      setAyanamsa(_fallbackAyanamsa);
    }
  }

  /// Where a Context lands when its user-defined ayanamsha disappears.
  static const int _fallbackAyanamsa = ayanamsaDefaultSiderealId;

  /// Set the sidereal projection plane (SE_SIDBIT_ECL_T0 / SSY_PLANE).
  void setSiderealProjection(SiderealProjection projection) {
    state = state.copyWith(projection: projection);
    _save();
  }

  void setEpheSource(EpheSource source) {
    // Force Moshier when no ephemeris files are available (e.g. web).
    final effective = _hasEpheFiles ? source : EpheSource.moshier;
    state = state.copyWith(epheSource: effective);
    _save();
  }

  void setJplFilename(String? filename) {
    state = state.copyWith(jplFilename: filename);
    _save();
  }

  /// Load context from a parsed chart file.
  void loadFromChart(ChartData chart) {
    final utcDt = chart.utcDateTime;
    final jd = _jdUtils.dateTimeToJd(utcDt);
    final totalOffset = chart.utcOffsetHours + chart.dstOffsetHours;
    final loc = chart.birthLocation;
    state = state.copyWith(
      jdUt: jd,
      utcOffset: totalOffset,
      latitude: loc.latitude,
      longitude: loc.longitude,
      cityLabel: '${loc.city}, ${loc.country}',
    );
    _save();
  }
}
