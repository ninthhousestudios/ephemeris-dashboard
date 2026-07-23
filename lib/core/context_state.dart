// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Immutable state for the global context bar.
///
/// All calculation tabs read from this shared state by default.
/// Engine configuration is derived from this via AppliedGlobals.
const Object _sentinel = Object();

class ContextBarState {
  const ContextBarState({
    required this.dateTime,
    required this.utcOffset,
    required this.jdUt,
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
    this.userAyanT0 = 0.0,
    this.userAyanValue = 0.0,
    this.userAyanT0IsUt = false,
    this.projection = SiderealProjection.standard,
    this.epheSource = EpheSource.moshier,
    this.jplFilename,
  });

  final DateTime dateTime;
  final double utcOffset; // hours
  final double jdUt;

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
  final double userAyanT0; // reference JD for SE_SIDM_USER
  final double userAyanValue; // ayanamsa value at t0, degrees
  final bool
  userAyanT0IsUt; // SE_SIDBIT_USER_UT: t0 is UT rather than TT (user-defined only)
  final SiderealProjection projection; // SE_SIDBIT_* projection plane modifier
  final EpheSource epheSource;
  final String?
  jplFilename; // e.g. 'de440.eph'; only used when epheSource == jpl

  ContextBarState copyWith({
    DateTime? dateTime,
    double? utcOffset,
    double? jdUt,
    double? latitude,
    double? longitude,
    double? altitude,
    String? cityLabel,
    Origin? origin,
    ZodiacRef? zodiacRef,
    EqRef? eqRef,
    int? ayanamsa,
    int? lastSiderealAyanamsa,
    double? userAyanT0,
    double? userAyanValue,
    bool? userAyanT0IsUt,
    SiderealProjection? projection,
    EpheSource? epheSource,
    Object? jplFilename = _sentinel,
  }) {
    return ContextBarState(
      dateTime: dateTime ?? this.dateTime,
      utcOffset: utcOffset ?? this.utcOffset,
      jdUt: jdUt ?? this.jdUt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      cityLabel: cityLabel ?? this.cityLabel,
      origin: origin ?? this.origin,
      zodiacRef: zodiacRef ?? this.zodiacRef,
      eqRef: eqRef ?? this.eqRef,
      ayanamsa: ayanamsa ?? this.ayanamsa,
      lastSiderealAyanamsa: lastSiderealAyanamsa ?? this.lastSiderealAyanamsa,
      userAyanT0: userAyanT0 ?? this.userAyanT0,
      userAyanValue: userAyanValue ?? this.userAyanValue,
      userAyanT0IsUt: userAyanT0IsUt ?? this.userAyanT0IsUt,
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
          dateTime == other.dateTime &&
          utcOffset == other.utcOffset &&
          jdUt == other.jdUt &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          altitude == other.altitude &&
          cityLabel == other.cityLabel &&
          origin == other.origin &&
          zodiacRef == other.zodiacRef &&
          eqRef == other.eqRef &&
          ayanamsa == other.ayanamsa &&
          lastSiderealAyanamsa == other.lastSiderealAyanamsa &&
          userAyanT0 == other.userAyanT0 &&
          userAyanValue == other.userAyanValue &&
          userAyanT0IsUt == other.userAyanT0IsUt &&
          projection == other.projection &&
          epheSource == other.epheSource &&
          jplFilename == other.jplFilename;

  @override
  int get hashCode => Object.hash(
    dateTime,
    utcOffset,
    jdUt,
    latitude,
    longitude,
    altitude,
    cityLabel,
    origin,
    zodiacRef,
    eqRef,
    ayanamsa,
    lastSiderealAyanamsa,
    userAyanT0,
    userAyanValue,
    userAyanT0IsUt,
    projection,
    epheSource,
    jplFilename,
  );
}

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
