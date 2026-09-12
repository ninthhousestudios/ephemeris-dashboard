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
import 'timezone_offset.dart';
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

/// Trust status of the Context's linked time zone — null when the offset is
/// manual/free (no zone linked).
///
/// A reactive projection (ADR-0001): the confidence of the *current* Context's
/// derived offset, recomputed on any Context change, so the context bar can
/// flag a low-confidence offset (pre-1970 / LMT / DST gap or fold) without the
/// notifier storing derived state. Carries the zone id alongside its resolution
/// for display. The offset math is shared with the notifier (`timezone_offset`),
/// so a value shown here matches the one the notifier committed.
final contextTzStatusProvider =
    Provider<({String zoneId, TzOffset resolution})?>((ref) {
      final ctx = ref.watch(contextBarProvider);
      final zoneId = ctx.timeZoneId;
      if (zoneId == null) return null;
      final jdu = JdUtils(ref.watch(sweProvider));
      final local = jdu.localCivilOf(
        ctx.jdUt,
        calendar: ctx.calendar,
        scale: ctx.timeScale,
        offsetHours: ctx.utcOffset,
      );
      // Resolve in Gregorian (tzdata's calendar), matching the notifier — so the
      // warning shown here is for the same offset the notifier committed.
      return (
        zoneId: zoneId,
        resolution: resolveTzOffsetForLocal(
          zoneId,
          jdu.toGregorianCivil(local, ctx.calendar),
        ),
      );
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
    // A linked offset is a pure function of (zone, Moment), but the Moment is
    // not persisted — a fresh "now" JD comes from [_initialState]. The persisted
    // offset belongs to whenever it was saved, so re-derive it for the current
    // instant (keeping the old value only if the zone no longer resolves);
    // otherwise a summer-saved link restarts on a winter Moment still holding
    // the summer offset (swe-dashboard/113).
    if (state.timeZoneId != null) {
      state = state.copyWith(utcOffset: _deriveOffsetForInstant(state.jdUt));
    }
  }

  void _save() => _persistence.saveContextBar(state);

  /// Set Julian Day. The Moment is canonical; the civil view is derived on read.
  ///
  /// This is the *instant* entry path (a raw JD): the instant is kept and, when
  /// a zone is linked, the offset re-derives for it so the local display stays
  /// consistent. Civil (wall-clock) entry goes through [setLocalCivil] instead,
  /// which keeps the wall time and moves the instant.
  void setJd(double jd) {
    final offset = _deriveOffsetForInstant(jd);
    state = state.copyWith(jdUt: jd, utcOffset: offset);
    // jd is not persisted; a re-derived offset is, so save only when a zone
    // could have changed it.
    if (state.timeZoneId != null) _save();
  }

  /// The offset a linked zone implies for the UTC instant [jd], keeping the
  /// instant (letting the local display shift). UTC→local is unambiguous, so no
  /// gap/fold arises here. Returns the current offset when no zone is linked.
  double _deriveOffsetForInstant(double jd) {
    final zoneId = state.timeZoneId;
    if (zoneId == null) return state.utcOffset;
    // tzdata is Gregorian-indexed and the instant→offset map is calendar-
    // independent, so query in Gregorian regardless of the display calendar.
    final utc = _jdUtils.civilFieldsOn(jd, Calendar.gregorian);
    final r = resolveTzOffsetForInstant(zoneId, utc);
    return r.resolved ? r.offsetHours : state.utcOffset;
  }

  /// Map local wall-clock [local] to (canonical UT1 JD, offset). When [zoneId]
  /// is linked the offset re-derives for these fields and the returned JD keeps
  /// the wall time; otherwise the current offset is used unchanged.
  (double, double) _applyLocalWithZone(Civil local, String? zoneId) {
    var offset = state.utcOffset;
    if (zoneId != null) {
      // tzdata is Gregorian-indexed: reinterpret the wall date across the
      // calendar reform before resolving, so a Julian/auto date can't land the
      // query on the wrong side of a DST transition. Identity for Gregorian.
      final greg = _jdUtils.toGregorianCivil(local, state.calendar);
      final r = resolveTzOffsetForLocal(zoneId, greg);
      if (r.resolved) offset = r.offsetHours;
    }
    final jd = _jdUtils.localCivilToJdUt(
      local,
      calendar: state.calendar,
      scale: state.timeScale,
      offsetHours: offset,
    );
    return (jd, offset);
  }

  /// Commit local civil (wall-clock) fields as the new Moment — the civil-entry
  /// path the date/time fields commit through. When a zone is linked the offset
  /// is re-derived for these fields (preserving the wall time, recomputing the
  /// canonical UT1 Moment); otherwise the current offset is used.
  void setLocalCivil(Civil local) {
    final (jd, offset) = _applyLocalWithZone(local, state.timeZoneId);
    state = state.copyWith(jdUt: jd, utcOffset: offset);
    _save();
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

  /// Set the UTC offset by hand. A hand-picked offset is a manual override, so
  /// this *detaches* from any linked time zone (clears [ContextBarState.timeZoneId]);
  /// selecting a city re-links. Does not change the Moment (UT/JD) — only the
  /// offset (which is itself a compute input for the Rise/Set search window, not
  /// merely display).
  void setUtcOffset(double offsetHours) {
    state = state.copyWith(utcOffset: offsetHours, timeZoneId: null);
    _save();
  }

  /// Set "now" — current system time. An instant, so a linked zone's offset
  /// re-derives for it (local display becomes the current time in that zone).
  void setNow() {
    final jd = _jdUtils.dateTimeToJd(DateTime.now().toUtc());
    state = state.copyWith(jdUt: jd, utcOffset: _deriveOffsetForInstant(jd));
    // jd not persisted; a re-derived offset is.
    if (state.timeZoneId != null) _save();
  }

  /// Set geographic location. [timeZoneId] links the offset to a zone (the
  /// selected city's IANA zone); a null/empty id leaves the offset manual and
  /// clears any previous link. When a zone links, the current local wall time is
  /// preserved and the offset re-derived for it (recomputing the Moment), so
  /// entering a birth time before or after picking the city gives the same UT.
  void setLocation({
    required double latitude,
    required double longitude,
    double? altitude,
    String? cityLabel,
    String? timeZoneId,
  }) {
    final zone = (timeZoneId != null && timeZoneId.isNotEmpty)
        ? timeZoneId
        : null;
    var jd = state.jdUt;
    var offset = state.utcOffset;
    if (zone != null) {
      final local = _jdUtils.localCivilOf(
        state.jdUt,
        calendar: state.calendar,
        scale: state.timeScale,
        offsetHours: state.utcOffset,
      );
      (jd, offset) = _applyLocalWithZone(local, zone);
    }
    state = state.copyWith(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      cityLabel: cityLabel,
      jdUt: jd,
      utcOffset: offset,
      timeZoneId: zone,
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
      // The chart carries its own explicit offset+DST; that is authoritative,
      // so no zone link — the offset is manual until a city is selected.
      timeZoneId: null,
    );
    _save();
  }
}
