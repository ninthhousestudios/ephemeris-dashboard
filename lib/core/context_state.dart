/// Immutable state for the global context bar.
///
/// All calculation tabs read from this shared state by default.
/// C globals (setSidMode, setEphePath, etc.) are NOT set here —
/// they are set atomically at each calculation point.
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
    this.eqRef = EqRef.trueEquinox,
    this.ayanamsa =
        -1, // -1 = none; 0+ = SE_SIDM_* constant (only meaningful when sidereal)
    this.userAyanT0 = 0.0,
    this.userAyanValue = 0.0,
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
  final double userAyanT0; // reference JD for SE_SIDM_USER
  final double userAyanValue; // ayanamsa value at t0, degrees
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
    double? userAyanT0,
    double? userAyanValue,
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
      userAyanT0: userAyanT0 ?? this.userAyanT0,
      userAyanValue: userAyanValue ?? this.userAyanValue,
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
          userAyanT0 == other.userAyanT0 &&
          userAyanValue == other.userAyanValue &&
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
    userAyanT0,
    userAyanValue,
    epheSource,
    jplFilename,
  );
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

/// Equinoctial reference: where is 0° ecliptic longitude?
/// True equinox of date, or mean equinox of a standard epoch (J2000).
enum EqRef {
  trueEquinox('True Equinox'),
  meanEquinox('Mean Equinox (J2000)');

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
