// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'calendar.dart';
import 'pref_field.dart';
import 'time_scale.dart';

/// Immutable state for the global context bar.
///
/// All calculation tabs read from this shared state by default.
/// Engine configuration is derived from this via AppliedGlobals.
const Object _sentinel = Object();

class ContextBarState {
  const ContextBarState({
    required this.utcOffset,
    required this.jdUt,
    this.calendar = Calendar.auto,
    this.timeScale = TimeScale.ut1,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.altitude = 0.0,
    this.cityLabel = '',
    this.origin = Origin.geocentric,
    this.zodiacRef = ZodiacRef.tropical,
    this.eqRef = EqRef.trueEquinoxOfDate,
    this.ayanamsa =
        -1, // -1 = none; 0+ = SE_SIDM_* constant (only meaningful when sidereal)
    this.lastSiderealAyanamsa =
        0, // remembered choice when switching back to sidereal
    this.userAyanId,
    this.projection = SiderealProjection.standard,
    this.epheSource = EpheSource.moshier,
    this.jplFilename,
  });

  final double utcOffset; // hours
  final double jdUt;

  /// Which calendar civil dates are read in / rendered on. View-layer only:
  /// [jdUt] stays canonical, and the calendar just maps civil ↔ JD.
  final Calendar calendar;

  /// Which time scale the civil date/time is entered in / displayed on
  /// (swetest `-ut`/`-t`/`-utc`). View-layer only, like [calendar]: [jdUt] stays
  /// canonical UT1, and the scale is an input transform + display label. Never
  /// enters a compute signature.
  final TimeScale timeScale;

  // Location
  final double latitude;
  final double longitude;
  final double altitude; // meters
  final String cityLabel;

  // Calculation options
  final Origin origin;
  final ZodiacRef zodiacRef;
  final EqRef eqRef;
  final int ayanamsa; // SE_SIDM_* constant (when sidereal); 255 = user-defined
  final int
  lastSiderealAyanamsa; // stashed sidereal choice (survives tropical toggle)
  /// Which user-defined ayanamsha is selected when [ayanamsa] is 255 — an id
  /// into `userAyanamsasProvider`, which owns the parameters themselves (t0,
  /// value, jdisut). The Context stores the choice, not a second copy of the
  /// numbers, so editing an entry on the Ayanamsa tab moves the chart too.
  final int? userAyanId;
  final SiderealProjection projection; // SE_SIDBIT_* projection plane modifier
  final EpheSource epheSource;
  final String?
  jplFilename; // e.g. 'de440.eph'; only used when epheSource == jpl

  ContextBarState copyWith({
    double? utcOffset,
    double? jdUt,
    Calendar? calendar,
    TimeScale? timeScale,
    double? latitude,
    double? longitude,
    double? altitude,
    String? cityLabel,
    Origin? origin,
    ZodiacRef? zodiacRef,
    EqRef? eqRef,
    int? ayanamsa,
    int? lastSiderealAyanamsa,
    int? userAyanId,
    SiderealProjection? projection,
    EpheSource? epheSource,
    Object? jplFilename = _sentinel,
  }) {
    return ContextBarState(
      utcOffset: utcOffset ?? this.utcOffset,
      jdUt: jdUt ?? this.jdUt,
      calendar: calendar ?? this.calendar,
      timeScale: timeScale ?? this.timeScale,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      cityLabel: cityLabel ?? this.cityLabel,
      origin: origin ?? this.origin,
      zodiacRef: zodiacRef ?? this.zodiacRef,
      eqRef: eqRef ?? this.eqRef,
      ayanamsa: ayanamsa ?? this.ayanamsa,
      lastSiderealAyanamsa: lastSiderealAyanamsa ?? this.lastSiderealAyanamsa,
      userAyanId: userAyanId ?? this.userAyanId,
      projection: projection ?? this.projection,
      epheSource: epheSource ?? this.epheSource,
      jplFilename: identical(jplFilename, _sentinel)
          ? this.jplFilename
          : jplFilename as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContextBarState &&
          utcOffset == other.utcOffset &&
          jdUt == other.jdUt &&
          calendar == other.calendar &&
          timeScale == other.timeScale &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          altitude == other.altitude &&
          cityLabel == other.cityLabel &&
          origin == other.origin &&
          zodiacRef == other.zodiacRef &&
          eqRef == other.eqRef &&
          ayanamsa == other.ayanamsa &&
          lastSiderealAyanamsa == other.lastSiderealAyanamsa &&
          userAyanId == other.userAyanId &&
          projection == other.projection &&
          epheSource == other.epheSource &&
          jplFilename == other.jplFilename;

  @override
  int get hashCode => Object.hash(
    utcOffset,
    jdUt,
    calendar,
    timeScale,
    latitude,
    longitude,
    altitude,
    cityLabel,
    origin,
    zodiacRef,
    eqRef,
    ayanamsa,
    lastSiderealAyanamsa,
    userAyanId,
    projection,
    epheSource,
    jplFilename,
  );
}

typedef _CtxPref<T extends Object> = TypedPrefField<ContextBarState, T>;

/// Every persisted [ContextBarState] field, stated once. Saving and restoring
/// both fold over this list, so persisting a new field is one row here beside
/// the field itself — not four hand-synchronised edits keyed by strings, which
/// is how `projection`, `userAyanT0IsUt` and `jplFilename` each got silently
/// dropped (swe-dashboard/80 A1, swe-dashboard/86).
///
/// The Moment ([ContextBarState.jdUt]) is deliberately absent: the JD is
/// canonical and the app always restarts at "now". That rule is visible here
/// as an absence from a single list.
final contextBarPrefFields = <PrefField<ContextBarState>>[
  _CtxPref<double>(
    key: 'ctx_utc_offset',
    getter: (s) => s.utcOffset,
    setter: (s, v) => s.copyWith(utcOffset: v),
    codec: doublePref,
  ),
  _CtxPref<Calendar>(
    key: 'ctx_calendar',
    getter: (s) => s.calendar,
    setter: (s, v) => s.copyWith(calendar: v),
    codec: const EnumPrefCodec(Calendar.values),
  ),
  _CtxPref<TimeScale>(
    key: 'ctx_time_scale',
    getter: (s) => s.timeScale,
    setter: (s, v) => s.copyWith(timeScale: v),
    codec: const EnumPrefCodec(TimeScale.values),
  ),
  _CtxPref<double>(
    key: 'ctx_latitude',
    getter: (s) => s.latitude,
    setter: (s, v) => s.copyWith(latitude: v),
    codec: doublePref,
  ),
  _CtxPref<double>(
    key: 'ctx_longitude',
    getter: (s) => s.longitude,
    setter: (s, v) => s.copyWith(longitude: v),
    codec: doublePref,
  ),
  _CtxPref<double>(
    key: 'ctx_altitude',
    getter: (s) => s.altitude,
    setter: (s, v) => s.copyWith(altitude: v),
    codec: doublePref,
  ),
  _CtxPref<String>(
    key: 'ctx_city_label',
    getter: (s) => s.cityLabel,
    setter: (s, v) => s.copyWith(cityLabel: v),
    codec: stringPref,
  ),
  _CtxPref<Origin>(
    key: 'ctx_origin',
    getter: (s) => s.origin,
    setter: (s, v) => s.copyWith(origin: v),
    codec: const EnumPrefCodec(Origin.values),
  ),
  _CtxPref<ZodiacRef>(
    key: 'ctx_zodiac_ref',
    getter: (s) => s.zodiacRef,
    setter: (s, v) => s.copyWith(zodiacRef: v),
    codec: const EnumPrefCodec(ZodiacRef.values),
  ),
  _CtxPref<EqRef>(
    key: 'ctx_eq_ref',
    getter: (s) => s.eqRef,
    setter: (s, v) => s.copyWith(eqRef: v),
    codec: const EnumPrefCodec(EqRef.values),
  ),
  _CtxPref<int>(
    key: 'ctx_ayanamsa',
    getter: (s) => s.ayanamsa,
    setter: (s, v) => s.copyWith(ayanamsa: v),
    codec: intPref,
  ),
  _CtxPref<int>(
    key: 'ctx_last_sidereal_ayanamsa',
    getter: (s) => s.lastSiderealAyanamsa,
    setter: (s, v) => s.copyWith(lastSiderealAyanamsa: v),
    codec: intPref,
  ),
  // The selected user-defined ayanamsha, by id. Its parameters are persisted
  // with the list itself (`userAyanamsasPrefKey`), not here — the Context has
  // held only the choice since the tab and the bar were unified.
  _CtxPref<int>(
    key: 'ctx_user_ayan_id',
    getter: (s) => s.userAyanId,
    setter: (s, v) => s.copyWith(userAyanId: v),
    codec: intPref,
  ),
  _CtxPref<SiderealProjection>(
    key: 'ctx_sidereal_projection',
    getter: (s) => s.projection,
    setter: (s, v) => s.copyWith(projection: v),
    codec: const EnumPrefCodec(SiderealProjection.values),
  ),
  _CtxPref<EpheSource>(
    key: 'ctx_ephe_source',
    getter: (s) => s.epheSource,
    setter: (s, v) => s.copyWith(epheSource: v),
    codec: const EnumPrefCodec(EpheSource.values),
  ),
  // Nullable, and the only field where that matters: no JPL file chosen has
  // to erase the key, not leave the previous choice behind for the next
  // restore to pick up. `getter` returning null is what does that.
  _CtxPref<String>(
    key: 'ctx_jpl_filename',
    getter: (s) => s.jplFilename,
    setter: (s, v) => s.copyWith(jplFilename: v),
    codec: stringPref,
  ),
];

/// Sidereal projection plane (SE_SIDBIT_* modifiers ORed into sid_mode).
///
/// Modifies how ecliptic longitudes are computed for *any* sidereal
/// ayanamsha. `standard` is Swiss Ephemeris' default behaviour (no bit set);
/// the other two match swetest's `-sidt0` and `-sidsp`. These do not change
/// the ayanamsha value itself, only the projection of body positions.
enum SiderealProjection {
  standard('Standard', 0),
  eclipticT0('Ecliptic of t0', 256), // SE_SIDBIT_ECL_T0
  solarSystemPlane('Solar system plane', 512); // SE_SIDBIT_SSY_PLANE

  const SiderealProjection(this.label, this.bit);
  final String label;
  final int bit;
}

/// Geocentric (default) vs topocentric vs heliocentric/barycentric.
enum Origin {
  geocentric('Geocentric'),
  topocentric('Topocentric'),
  heliocentric('Heliocentric'),
  barycentric('Barycentric');

  const Origin(this.label);
  final String label;
}

/// Tropical vs sidereal zodiac reference.
/// Tropical: 0° at vernal equinox. Sidereal: 0° at a fixed star reference.
enum ZodiacRef {
  tropical('Tropical'),
  sidereal('Sidereal');

  const ZodiacRef(this.label);
  final String label;
}

/// Equinoctial reference: where is 0° ecliptic longitude referred to?
/// True equinox of date (precession + nutation), mean equinox of date
/// (precession, no nutation — SEFLG_NONUT), or the frozen J2000 mean frame
/// (SEFLG_J2000). Mutually exclusive; drives a locked flag, like the zodiac
/// and origin references.
enum EqRef {
  trueEquinoxOfDate('True Equinox of Date'),
  meanEquinoxOfDate('Mean Equinox of Date'),
  meanEquinoxJ2000('Mean Equinox (J2000)');

  const EqRef(this.label);
  final String label;
}

/// Ephemeris source: Swiss Ephemeris, JPL, or Moshier.
enum EpheSource {
  swissEph('Swiss Ephemeris'),
  jpl('JPL'),
  moshier('Moshier');

  const EpheSource(this.label);
  final String label;
}
