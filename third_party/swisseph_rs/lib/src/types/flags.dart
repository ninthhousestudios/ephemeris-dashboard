// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

// --------------------------------------------------------------------------
// Bitflag extension types — Counterpart: swisseph::flags (bitflags!)
// --------------------------------------------------------------------------

/// Counterpart: swisseph::flags::CalcFlags
extension type const CalcFlags(int value) {
  /// Counterpart: swisseph::flags::CalcFlags::empty
  static const none = CalcFlags(0);

  /// Counterpart: swisseph::flags::CalcFlags::JPLEPH
  static const jplEph = CalcFlags(1);

  /// Counterpart: swisseph::flags::CalcFlags::SWIEPH
  static const swiEph = CalcFlags(2);

  /// Counterpart: swisseph::flags::CalcFlags::MOSEPH
  static const mosEph = CalcFlags(4);

  /// Counterpart: swisseph::flags::CalcFlags::HELCTR
  static const helctr = CalcFlags(8);

  /// Counterpart: swisseph::flags::CalcFlags::TRUEPOS
  static const truePos = CalcFlags(16);

  /// Counterpart: swisseph::flags::CalcFlags::J2000
  static const j2000 = CalcFlags(32);

  /// Counterpart: swisseph::flags::CalcFlags::NONUT
  static const noNut = CalcFlags(64);

  /// Counterpart: swisseph::flags::CalcFlags::SPEED3
  static const speed3 = CalcFlags(128);

  /// Counterpart: swisseph::flags::CalcFlags::SPEED
  static const speed = CalcFlags(256);

  /// Counterpart: swisseph::flags::CalcFlags::NOGDEFL
  static const noGdefl = CalcFlags(512);

  /// Counterpart: swisseph::flags::CalcFlags::NOABERR
  static const noAberr = CalcFlags(1024);

  /// Counterpart: swisseph::flags::CalcFlags::EQUATORIAL
  static const equatorial = CalcFlags(2048);

  /// Counterpart: swisseph::flags::CalcFlags::XYZ
  static const xyz = CalcFlags(4096);

  /// Counterpart: swisseph::flags::CalcFlags::RADIANS
  static const radians = CalcFlags(8192);

  /// Counterpart: swisseph::flags::CalcFlags::BARYCTR
  static const baryctr = CalcFlags(16384);

  /// Counterpart: swisseph::flags::CalcFlags::TOPOCTR
  static const topoctr = CalcFlags(32768);

  /// Counterpart: swisseph::flags::CalcFlags::SIDEREAL
  static const sidereal = CalcFlags(65536);

  /// Counterpart: swisseph::flags::CalcFlags::ICRS
  static const icrs = CalcFlags(131072);

  /// Counterpart: swisseph::flags::CalcFlags::DPSIDEPS_1980
  static const dpsideps1980 = CalcFlags(262144);

  /// Counterpart: swisseph::flags::CalcFlags::JPLHOR_APPROX
  static const jplHorApprox = CalcFlags(524288);

  /// Counterpart: swisseph::flags::CalcFlags::CENTER_BODY
  static const centerBody = CalcFlags(1048576);

  /// Counterpart: swisseph::flags::CalcFlags::ASTROMETRIC
  static const astrometric = CalcFlags(1536);

  /// Counterpart: swisseph::flags::CalcFlags::DEFAULTEPH
  static const defaultEph = CalcFlags(2);

  CalcFlags operator |(CalcFlags other) => CalcFlags(value | other.value);
  CalcFlags operator &(CalcFlags other) => CalcFlags(value & other.value);
  bool contains(CalcFlags flag) => value & flag.value == flag.value;
}

/// Counterpart: swisseph::flags::SiderealBits
extension type const SiderealBits(int value) {
  static const none = SiderealBits(0);

  /// Counterpart: swisseph::flags::SiderealBits::ECL_T0
  static const eclT0 = SiderealBits(256);

  /// Counterpart: swisseph::flags::SiderealBits::SSY_PLANE
  static const ssyPlane = SiderealBits(512);

  /// Counterpart: swisseph::flags::SiderealBits::USER_UT
  static const userUt = SiderealBits(1024);

  /// Counterpart: swisseph::flags::SiderealBits::ECL_DATE
  static const eclDate = SiderealBits(2048);

  /// Counterpart: swisseph::flags::SiderealBits::NO_PREC_OFFSET
  static const noPrecOffset = SiderealBits(4096);

  /// Counterpart: swisseph::flags::SiderealBits::PREC_ORIG
  static const precOrig = SiderealBits(8192);

  SiderealBits operator |(SiderealBits other) =>
      SiderealBits(value | other.value);
  SiderealBits operator &(SiderealBits other) =>
      SiderealBits(value & other.value);
  bool contains(SiderealBits flag) => value & flag.value == flag.value;
}

/// Counterpart: swisseph::flags::EclipseFlags
extension type const EclipseFlags(int value) {
  static const none = EclipseFlags(0);

  /// Counterpart: swisseph::flags::EclipseFlags::CENTRAL
  static const central = EclipseFlags(1);

  /// Counterpart: swisseph::flags::EclipseFlags::NONCENTRAL
  static const noncentral = EclipseFlags(2);

  /// Counterpart: swisseph::flags::EclipseFlags::TOTAL
  static const total = EclipseFlags(4);

  /// Counterpart: swisseph::flags::EclipseFlags::ANNULAR
  static const annular = EclipseFlags(8);

  /// Counterpart: swisseph::flags::EclipseFlags::PARTIAL
  static const partial = EclipseFlags(16);

  /// Counterpart: swisseph::flags::EclipseFlags::HYBRID
  static const hybrid = EclipseFlags(32);

  /// Counterpart: swisseph::flags::EclipseFlags::PENUMBRAL
  static const penumbral = EclipseFlags(64);

  /// Counterpart: swisseph::flags::EclipseFlags::VISIBLE
  static const visible = EclipseFlags(128);

  /// Counterpart: swisseph::flags::EclipseFlags::MAX_VISIBLE
  static const maxVisible = EclipseFlags(256);

  /// Counterpart: swisseph::flags::EclipseFlags::PARTBEG_VISIBLE
  static const partbegVisible = EclipseFlags(512);

  /// Counterpart: swisseph::flags::EclipseFlags::TOTBEG_VISIBLE
  static const totbegVisible = EclipseFlags(1024);

  /// Counterpart: swisseph::flags::EclipseFlags::TOTEND_VISIBLE
  static const totendVisible = EclipseFlags(2048);

  /// Counterpart: swisseph::flags::EclipseFlags::PARTEND_VISIBLE
  static const partendVisible = EclipseFlags(4096);

  /// Counterpart: swisseph::flags::EclipseFlags::PENUMBBEG_VISIBLE
  static const penumbbegVisible = EclipseFlags(8192);

  /// Counterpart: swisseph::flags::EclipseFlags::PENUMBEND_VISIBLE
  static const penumbendVisible = EclipseFlags(16384);

  /// Counterpart: swisseph::flags::EclipseFlags::OCC_BEG_DAYLIGHT
  static const occBegDaylight = EclipseFlags(8192);

  /// Counterpart: swisseph::flags::EclipseFlags::OCC_END_DAYLIGHT
  static const occEndDaylight = EclipseFlags(16384);

  /// Counterpart: swisseph::flags::EclipseFlags::ONE_TRY
  static const oneTry = EclipseFlags(32768);

  /// Counterpart: swisseph::flags::EclipseFlags::ALLTYPES_SOLAR
  static const allTypesSolar = EclipseFlags(63);

  /// Counterpart: swisseph::flags::EclipseFlags::ALLTYPES_LUNAR
  static const allTypesLunar = EclipseFlags(84);

  EclipseFlags operator |(EclipseFlags other) =>
      EclipseFlags(value | other.value);
  EclipseFlags operator &(EclipseFlags other) =>
      EclipseFlags(value & other.value);
  bool contains(EclipseFlags flag) => value & flag.value == flag.value;
}

/// Counterpart: swisseph::flags::RiseSetFlags
extension type const RiseSetFlags(int value) {
  static const none = RiseSetFlags(0);

  /// Counterpart: swisseph::flags::RiseSetFlags::RISE
  static const rise = RiseSetFlags(1);

  /// Counterpart: swisseph::flags::RiseSetFlags::SET
  static const set = RiseSetFlags(2);

  /// Counterpart: swisseph::flags::RiseSetFlags::MTRANSIT
  static const mtransit = RiseSetFlags(4);

  /// Counterpart: swisseph::flags::RiseSetFlags::ITRANSIT
  static const itransit = RiseSetFlags(8);

  /// Counterpart: swisseph::flags::RiseSetFlags::GEOCTR_NO_ECL_LAT
  static const geoctrNoEclLat = RiseSetFlags(128);

  /// Counterpart: swisseph::flags::RiseSetFlags::DISC_CENTER
  static const discCenter = RiseSetFlags(256);

  /// Counterpart: swisseph::flags::RiseSetFlags::NO_REFRACTION
  static const noRefraction = RiseSetFlags(512);

  /// Counterpart: swisseph::flags::RiseSetFlags::CIVIL_TWILIGHT
  static const civilTwilight = RiseSetFlags(1024);

  /// Counterpart: swisseph::flags::RiseSetFlags::NAUTIC_TWILIGHT
  static const nauticTwilight = RiseSetFlags(2048);

  /// Counterpart: swisseph::flags::RiseSetFlags::ASTRO_TWILIGHT
  static const astroTwilight = RiseSetFlags(4096);

  /// Counterpart: swisseph::flags::RiseSetFlags::DISC_BOTTOM
  static const discBottom = RiseSetFlags(8192);

  /// Counterpart: swisseph::flags::RiseSetFlags::FIXED_DISC_SIZE
  static const fixedDiscSize = RiseSetFlags(16384);

  /// Counterpart: swisseph::flags::RiseSetFlags::FORCE_SLOW
  static const forceSlow = RiseSetFlags(32768);

  /// Counterpart: swisseph::flags::RiseSetFlags::HINDU_RISING
  static const hinduRising = RiseSetFlags(896);

  RiseSetFlags operator |(RiseSetFlags other) =>
      RiseSetFlags(value | other.value);
  RiseSetFlags operator &(RiseSetFlags other) =>
      RiseSetFlags(value & other.value);
  bool contains(RiseSetFlags flag) => value & flag.value == flag.value;
}

/// Counterpart: swisseph::flags::SplitDegFlags
extension type const SplitDegFlags(int value) {
  static const none = SplitDegFlags(0);

  /// Counterpart: swisseph::flags::SplitDegFlags::ROUND_SEC
  static const roundSec = SplitDegFlags(1);

  /// Counterpart: swisseph::flags::SplitDegFlags::ROUND_MIN
  static const roundMin = SplitDegFlags(2);

  /// Counterpart: swisseph::flags::SplitDegFlags::ROUND_DEG
  static const roundDeg = SplitDegFlags(4);

  /// Counterpart: swisseph::flags::SplitDegFlags::ZODIACAL
  static const zodiacal = SplitDegFlags(8);

  /// Counterpart: swisseph::flags::SplitDegFlags::KEEP_SIGN
  static const keepSign = SplitDegFlags(16);

  /// Counterpart: swisseph::flags::SplitDegFlags::KEEP_DEG
  static const keepDeg = SplitDegFlags(32);

  /// Counterpart: swisseph::flags::SplitDegFlags::NAKSHATRA
  static const nakshatra = SplitDegFlags(1024);

  SplitDegFlags operator |(SplitDegFlags other) =>
      SplitDegFlags(value | other.value);
  SplitDegFlags operator &(SplitDegFlags other) =>
      SplitDegFlags(value & other.value);
  bool contains(SplitDegFlags flag) => value & flag.value == flag.value;
}

/// Counterpart: swisseph::flags::HeliacalFlags
extension type const HeliacalFlags(int value) {
  static const none = HeliacalFlags(0);

  /// Counterpart: swisseph::flags::HeliacalFlags::LONG_SEARCH
  static const longSearch = HeliacalFlags(128);

  /// Counterpart: swisseph::flags::HeliacalFlags::HIGH_PRECISION
  static const highPrecision = HeliacalFlags(256);

  /// Counterpart: swisseph::flags::HeliacalFlags::OPTICAL_PARAMS
  static const opticalParams = HeliacalFlags(512);

  /// Counterpart: swisseph::flags::HeliacalFlags::NO_DETAILS
  static const noDetails = HeliacalFlags(1024);

  /// Counterpart: swisseph::flags::HeliacalFlags::SEARCH_1_PERIOD
  static const search1Period = HeliacalFlags(2048);

  /// Counterpart: swisseph::flags::HeliacalFlags::VISLIM_DARK
  static const vislimDark = HeliacalFlags(4096);

  /// Counterpart: swisseph::flags::HeliacalFlags::VISLIM_NOMOON
  static const vislimNomoon = HeliacalFlags(8192);

  /// Counterpart: swisseph::flags::HeliacalFlags::VISLIM_PHOTOPIC
  static const vislimPhotopic = HeliacalFlags(16384);

  /// Counterpart: swisseph::flags::HeliacalFlags::VISLIM_SCOTOPIC
  static const vislimScotopic = HeliacalFlags(32768);

  /// Counterpart: swisseph::flags::HeliacalFlags::AV
  static const av = HeliacalFlags(65536);

  /// Counterpart: swisseph::flags::HeliacalFlags::AVKIND_VR
  static const avkindVr = HeliacalFlags(65536);

  /// Counterpart: swisseph::flags::HeliacalFlags::AVKIND_PTO
  static const avkindPto = HeliacalFlags(131072);

  /// Counterpart: swisseph::flags::HeliacalFlags::AVKIND_MIN7
  static const avkindMin7 = HeliacalFlags(262144);

  /// Counterpart: swisseph::flags::HeliacalFlags::AVKIND_MIN9
  static const avkindMin9 = HeliacalFlags(524288);

  /// Counterpart: swisseph::flags::HeliacalFlags::AVKIND
  static const avkind = HeliacalFlags(983040);

  HeliacalFlags operator |(HeliacalFlags other) =>
      HeliacalFlags(value | other.value);
  HeliacalFlags operator &(HeliacalFlags other) =>
      HeliacalFlags(value & other.value);
  bool contains(HeliacalFlags flag) => value & flag.value == flag.value;
}

/// Counterpart: swisseph::flags::VisLimFlags
extension type const VisLimFlags(int value) {
  static const none = VisLimFlags(0);

  /// Counterpart: swisseph::flags::VisLimFlags::SCOTOPIC
  static const scotopic = VisLimFlags(1);

  /// Counterpart: swisseph::flags::VisLimFlags::MIXED
  static const mixed = VisLimFlags(2);

  VisLimFlags operator |(VisLimFlags other) => VisLimFlags(value | other.value);
  VisLimFlags operator &(VisLimFlags other) => VisLimFlags(value & other.value);
  bool contains(VisLimFlags flag) => value & flag.value == flag.value;
}

/// Counterpart: swisseph::nodaps::NodApsMethod
extension type const NodApsMethod(int value) {
  static const none = NodApsMethod(0);

  /// Counterpart: swisseph::nodaps::NodApsMethod::MEAN
  static const mean = NodApsMethod(1);

  /// Counterpart: swisseph::nodaps::NodApsMethod::OSCU
  static const oscu = NodApsMethod(2);

  /// Counterpart: swisseph::nodaps::NodApsMethod::OSCU_BAR
  static const oscuBar = NodApsMethod(4);

  /// Counterpart: swisseph::nodaps::NodApsMethod::FOPOINT
  static const fopoint = NodApsMethod(256);

  NodApsMethod operator |(NodApsMethod other) =>
      NodApsMethod(value | other.value);
  NodApsMethod operator &(NodApsMethod other) =>
      NodApsMethod(value & other.value);
  bool contains(NodApsMethod flag) => value & flag.value == flag.value;
}
