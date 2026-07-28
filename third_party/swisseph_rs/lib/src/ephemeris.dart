// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'ffi_types.dart';
import 'lifecycle.dart' as lifecycle;

import 'marshal/marshal.dart' as marshal;
import 'types/types.dart';

/// Counterpart: swisseph::Ephemeris
final class Ephemeris implements Finalizable {
  final Pointer<Void> _handle;
  bool _closed = false;

  /// Counterpart: swisseph::Ephemeris::new
  Ephemeris(EphemerisConfig config) : _handle = marshal.createHandle(config) {
    lifecycle.attachCleanup(this, _handle);
  }

  /// Counterpart: swisseph_ffi::swisseph_share
  ///
  /// Materialize a shared engine from a token obtained via [share].
  /// The resulting instance is a co-equal [Ephemeris] over the same engine —
  /// not a view. Each instance closes independently; the last close frees the
  /// engine. Close order is irrelevant.
  Ephemeris.fromShareToken(int token)
    : _handle = Pointer<Void>.fromAddress(token) {
    lifecycle.attachCleanup(this, _handle);
  }

  void _checkOpen() {
    if (_closed) {
      throw StateError('Ephemeris has been closed');
    }
  }

  /// Counterpart: swisseph::Ephemeris::calc_ut
  CalcResult calcUt(JdUt1 jd, Body body, CalcFlags flags) {
    _checkOpen();
    return marshal.calcUt(_handle, jd.value, body.rawValue, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::calc_ut_with_config
  CalcResult calcUtWithConfig(
    JdUt1 jd,
    Body body,
    CalcFlags flags,
    EphemerisConfig config,
  ) {
    _checkOpen();
    return marshal.calcUtWithConfig(
      _handle,
      jd.value,
      body.rawValue,
      flags.value,
      config,
    );
  }

  /// Counterpart: swisseph::Ephemeris::calc
  CalcResult calc(JdTt jd, Body body, CalcFlags flags) {
    _checkOpen();
    return marshal.calc(_handle, jd.value, body.rawValue, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::calc_with_config
  CalcResult calcWithConfig(
    JdTt jd,
    Body body,
    CalcFlags flags,
    EphemerisConfig config,
  ) {
    _checkOpen();
    return marshal.calcWithConfig(
      _handle,
      jd.value,
      body.rawValue,
      flags.value,
      config,
    );
  }

  /// Counterpart: swisseph::Ephemeris::calc_pctr
  CalcResult calcPctr(JdTt jd, Body body, Body center, CalcFlags flags) {
    _checkOpen();
    return marshal.calcPctr(
      _handle,
      jd.value,
      body.rawValue,
      center.rawValue,
      flags.value,
    );
  }

  /// Counterpart: swisseph_ffi::swisseph_free
  ///
  /// Release the native handle. Idempotent; use-after-close throws
  /// [StateError]. A [NativeFinalizer] backstop ensures cleanup if this
  /// method is never called.
  void close() {
    if (_closed) return;
    _closed = true;
    lifecycle.detachCleanup(this);
    marshal.freeHandle(_handle);
  }

  /// Counterpart: swisseph::Ephemeris::delta_t
  double deltaT(JdUt1 jd) {
    _checkOpen();
    return marshal.deltaT(_handle, jd.value);
  }

  /// Counterpart: swisseph::Ephemeris::sidereal_time
  double siderealTime(JdUt1 jd) {
    _checkOpen();
    return marshal.siderealTime(_handle, jd.value);
  }

  /// Counterpart: swisseph::Ephemeris::sidereal_time0
  double siderealTime0(JdUt1 jd, double eps, double nut) {
    _checkOpen();
    return marshal.siderealTime0(_handle, jd.value, eps, nut);
  }

  /// Counterpart: swisseph::Ephemeris::time_equ
  double timeEqu(double tjdUt) {
    _checkOpen();
    return marshal.timeEqu(_handle, tjdUt);
  }

  /// Counterpart: swisseph::Ephemeris::lmt_to_lat
  double lmtToLat(double tjdLmt, double geolon) {
    _checkOpen();
    return marshal.lmtToLat(_handle, tjdLmt, geolon);
  }

  /// Counterpart: swisseph::Ephemeris::lat_to_lmt
  double latToLmt(double tjdLat, double geolon) {
    _checkOpen();
    return marshal.latToLmt(_handle, tjdLat, geolon);
  }

  /// Counterpart: swisseph::Ephemeris::get_planet_name
  String getPlanetName(Body body) {
    _checkOpen();
    return marshal.getPlanetName(_handle, body.rawValue);
  }

  /// Counterpart: swisseph::date::utc_to_jd
  UtcToJd utcToJd(UtcComponents utc, CalendarType cal) {
    _checkOpen();
    return marshal.utcToJd(
      _handle,
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
      cal.value,
    );
  }

  /// Counterpart: swisseph::date::jdet_to_utc
  UtcComponents jdetToUtc(JdTt jd, CalendarType cal) {
    _checkOpen();
    return marshal.jdetToUtc(_handle, jd.value, cal.value);
  }

  /// Counterpart: swisseph::date::jdut1_to_utc
  UtcComponents jdut1ToUtc(JdUt1 jd, CalendarType cal) {
    _checkOpen();
    return marshal.jdut1ToUtc(_handle, jd.value, cal.value);
  }

  // -----------------------------------------------------------------------
  // Houses
  // -----------------------------------------------------------------------

  /// Counterpart: swisseph::Ephemeris::houses
  HouseResult houses(JdUt1 jd, double geolat, double geolon, HouseSystem hsys) {
    _checkOpen();
    return marshal.housesEx2(
      _handle,
      jd.value,
      0, // no flags
      geolat,
      geolon,
      hsys.charCode,
    );
  }

  /// Counterpart: swisseph::Ephemeris::houses_ex2
  HouseResult housesEx2(
    JdUt1 jd,
    CalcFlags flags,
    double geolat,
    double geolon,
    HouseSystem hsys,
  ) {
    _checkOpen();
    return marshal.housesEx2(
      _handle,
      jd.value,
      flags.value,
      geolat,
      geolon,
      hsys.charCode,
    );
  }

  /// Counterpart: swisseph::Ephemeris::gauquelin_sector
  double gauquelinSector(
    JdUt1 jd,
    Body body,
    CalcFlags flags,
    int method,
    double geolon,
    double geolat,
    double geoalt, {
    double atpress = 0,
    double attemp = 0,
    String? starname,
  }) {
    _checkOpen();
    return marshal.gauquelinSector(
      _handle,
      jd.value,
      body.rawValue,
      starname,
      flags.value,
      method,
      geolon,
      geolat,
      geoalt,
      atpress,
      attemp,
    );
  }

  /// Counterpart: swisseph::Ephemeris::gauquelin_sector_geometric
  double gauquelinSectorGeometric(
    JdUt1 jd,
    Body body,
    CalcFlags flags,
    int method,
    double geolon,
    double geolat, {
    String? starname,
  }) {
    _checkOpen();
    return marshal.gauquelinSector(
      _handle,
      jd.value,
      body.rawValue,
      starname,
      flags.value,
      method,
      geolon,
      geolat,
      0,
      0,
      0,
    );
  }

  // -----------------------------------------------------------------------
  // Ayanamsa
  // -----------------------------------------------------------------------

  /// Counterpart: swisseph::Ephemeris::get_ayanamsa_ex
  ({double ayanamsa, CalcFlags flagsUsed}) getAyanamsaEx(
    JdTt jd,
    CalcFlags flags,
  ) {
    _checkOpen();
    return marshal.getAyanamsaEx(_handle, jd.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::get_ayanamsa_ex_with_config
  ({double ayanamsa, CalcFlags flagsUsed}) getAyanamsaExWithConfig(
    JdTt jd,
    CalcFlags flags,
    EphemerisConfig config,
  ) {
    _checkOpen();
    return marshal.getAyanamsaExWithConfig(
      _handle,
      jd.value,
      flags.value,
      config,
    );
  }

  /// Counterpart: swisseph::Ephemeris::get_ayanamsa_ut
  ({double ayanamsa, CalcFlags flagsUsed}) getAyanamsaUt(
    JdUt1 jd,
    CalcFlags flags,
  ) {
    _checkOpen();
    return marshal.getAyanamsaUt(_handle, jd.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::get_ayanamsa
  double getAyanamsa(JdTt jd) {
    _checkOpen();
    return marshal.getAyanamsa(_handle, jd.value);
  }

  /// Counterpart: swisseph_ffi::swisseph_share
  ///
  /// Returns an isolate-sendable token representing a shared engine handle.
  /// Materialize in the receiving isolate via [Ephemeris.fromShareToken].
  /// Native-only; throws [UnsupportedError] on web.
  int share() {
    _checkOpen();
    return marshal.shareHandle(_handle).address;
  }

  // -----------------------------------------------------------------------
  // Eclipses & occultations
  // -----------------------------------------------------------------------

  /// Counterpart: swisseph::Ephemeris::sol_eclipse_when_glob
  SolarEclipseGlobal solEclipseWhenGlob(
    JdUt1 jdStart,
    CalcFlags flags, {
    EclipseFlags eclType = EclipseFlags.none,
    bool backward = false,
  }) {
    _checkOpen();
    return marshal.solEclipseWhenGlob(
      _handle,
      jdStart.value,
      flags.value,
      eclType.value,
      backward,
    );
  }

  /// Counterpart: swisseph::Ephemeris::sol_eclipse_when_loc
  SolarEclipseLocal solEclipseWhenLoc(
    JdUt1 jdStart,
    CalcFlags flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    _checkOpen();
    return marshal.solEclipseWhenLoc(
      _handle,
      jdStart.value,
      flags.value,
      geolon,
      geolat,
      geoalt,
      backward,
    );
  }

  /// Counterpart: swisseph::Ephemeris::sol_eclipse_where
  EclipseWhere solEclipseWhere(JdUt1 jd, CalcFlags flags) {
    _checkOpen();
    return marshal.solEclipseWhere(_handle, jd.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::sol_eclipse_how
  EclipseHow solEclipseHow(
    JdUt1 jd,
    CalcFlags flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    _checkOpen();
    return marshal.solEclipseHow(
      _handle,
      jd.value,
      flags.value,
      geolon,
      geolat,
      geoalt,
    );
  }

  /// Counterpart: swisseph::Ephemeris::lun_eclipse_how
  LunarEclipseHow lunEclipseHow(
    JdUt1 jd,
    CalcFlags flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    _checkOpen();
    return marshal.lunEclipseHow(
      _handle,
      jd.value,
      flags.value,
      geolon,
      geolat,
      geoalt,
    );
  }

  /// Counterpart: swisseph::Ephemeris::lun_eclipse_when
  LunarEclipseGlobal lunEclipseWhen(
    JdUt1 jdStart,
    CalcFlags flags, {
    EclipseFlags eclType = EclipseFlags.none,
    bool backward = false,
  }) {
    _checkOpen();
    return marshal.lunEclipseWhen(
      _handle,
      jdStart.value,
      flags.value,
      eclType.value,
      backward,
    );
  }

  /// Counterpart: swisseph::Ephemeris::lun_eclipse_when_loc
  LunarEclipseLocal lunEclipseWhenLoc(
    JdUt1 jdStart,
    CalcFlags flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    _checkOpen();
    return marshal.lunEclipseWhenLoc(
      _handle,
      jdStart.value,
      flags.value,
      geolon,
      geolat,
      geoalt,
      backward,
    );
  }

  /// Counterpart: swisseph::Ephemeris::lun_occult_where
  EclipseWhere lunOccultWhere(
    JdUt1 jd,
    Body body,
    CalcFlags flags, {
    String? starname,
  }) {
    _checkOpen();
    return marshal.lunOccultWhere(
      _handle,
      jd.value,
      body.rawValue,
      starname,
      flags.value,
    );
  }

  /// Counterpart: swisseph::Ephemeris::lun_occult_when_glob
  OccultGlobal lunOccultWhenGlob(
    JdUt1 jdStart,
    Body body,
    CalcFlags flags, {
    String? starname,
    EclipseFlags eclType = EclipseFlags.none,
    bool backward = false,
  }) {
    _checkOpen();
    return marshal.lunOccultWhenGlob(
      _handle,
      jdStart.value,
      body.rawValue,
      starname,
      flags.value,
      eclType.value,
      backward,
    );
  }

  /// Counterpart: swisseph::Ephemeris::lun_occult_when_loc
  OccultLocal lunOccultWhenLoc(
    JdUt1 jdStart,
    Body body,
    CalcFlags flags, {
    String? starname,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    _checkOpen();
    return marshal.lunOccultWhenLoc(
      _handle,
      jdStart.value,
      body.rawValue,
      starname,
      flags.value,
      geolon,
      geolat,
      geoalt,
      backward,
    );
  }

  // -----------------------------------------------------------------------
  // Rise/set & crossings (task /32)
  // -----------------------------------------------------------------------

  /// Counterpart: swisseph::Ephemeris::rise_trans
  RiseSetResult riseTrans(
    JdUt1 jdUt,
    Body body,
    CalcFlags epheflag,
    RiseSetFlags rsmi, {
    String? starname,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
  }) {
    _checkOpen();
    return marshal.riseTrans(
      _handle,
      jdUt.value,
      body.rawValue,
      starname,
      epheflag.value,
      rsmi.value,
      geolon,
      geolat,
      geoalt,
      atpress,
      attemp,
    );
  }

  /// Counterpart: swisseph::Ephemeris::rise_trans_true_hor
  RiseSetResult riseTransTrueHor(
    JdUt1 jdUt,
    Body body,
    CalcFlags epheflag,
    RiseSetFlags rsmi, {
    String? starname,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    double horhgt = 0,
  }) {
    _checkOpen();
    return marshal.riseTransTrueHor(
      _handle,
      jdUt.value,
      body.rawValue,
      starname,
      epheflag.value,
      rsmi.value,
      geolon,
      geolat,
      geoalt,
      atpress,
      attemp,
      horhgt,
    );
  }

  /// Counterpart: swisseph::Ephemeris::solcross
  double solcross(double x2cross, JdTt jdEt, CalcFlags flags) {
    _checkOpen();
    return marshal.solcross(_handle, x2cross, jdEt.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::solcross_ut
  double solcrossUt(double x2cross, JdUt1 jdUt, CalcFlags flags) {
    _checkOpen();
    return marshal.solcrossUt(_handle, x2cross, jdUt.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::mooncross
  double mooncross(double x2cross, JdTt jdEt, CalcFlags flags) {
    _checkOpen();
    return marshal.mooncross(_handle, x2cross, jdEt.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::mooncross_ut
  double mooncrossUt(double x2cross, JdUt1 jdUt, CalcFlags flags) {
    _checkOpen();
    return marshal.mooncrossUt(_handle, x2cross, jdUt.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::mooncross_node
  MoonCrossing mooncrossNode(JdTt jdEt, CalcFlags flags) {
    _checkOpen();
    return marshal.mooncrossNode(_handle, jdEt.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::mooncross_node_ut
  MoonCrossing mooncrossNodeUt(JdUt1 jdUt, CalcFlags flags) {
    _checkOpen();
    return marshal.mooncrossNodeUt(_handle, jdUt.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::helio_cross
  double helioCross(
    Body body,
    double x2cross,
    JdTt jdEt,
    CalcFlags flags, {
    int dir = 1,
  }) {
    _checkOpen();
    return marshal.helioCross(
      _handle,
      body.rawValue,
      x2cross,
      jdEt.value,
      flags.value,
      dir,
    );
  }

  /// Counterpart: swisseph::Ephemeris::helio_cross_ut
  double helioCrossUt(
    Body body,
    double x2cross,
    JdUt1 jdUt,
    CalcFlags flags, {
    int dir = 1,
  }) {
    _checkOpen();
    return marshal.helioCrossUt(
      _handle,
      body.rawValue,
      x2cross,
      jdUt.value,
      flags.value,
      dir,
    );
  }

  // -----------------------------------------------------------------------
  // Phenomena, orbital, nodes/apsides (task /33)
  // -----------------------------------------------------------------------

  /// Counterpart: swisseph::Ephemeris::pheno_ut
  Phenomena phenoUt(JdUt1 jdUt, Body body, CalcFlags flags) {
    _checkOpen();
    return marshal.phenoUt(_handle, jdUt.value, body.rawValue, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::pheno
  Phenomena pheno(JdTt jdEt, Body body, CalcFlags flags) {
    _checkOpen();
    return marshal.pheno(_handle, jdEt.value, body.rawValue, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::nod_aps_ut
  NodesApsides nodApsUt(
    JdUt1 jdUt,
    Body body,
    CalcFlags flags,
    NodApsMethod method,
  ) {
    _checkOpen();
    return marshal.nodApsUt(
      _handle,
      jdUt.value,
      body.rawValue,
      flags.value,
      method.value,
    );
  }

  /// Counterpart: swisseph::Ephemeris::nod_aps
  NodesApsides nodAps(
    JdTt jdEt,
    Body body,
    CalcFlags flags,
    NodApsMethod method,
  ) {
    _checkOpen();
    return marshal.nodAps(
      _handle,
      jdEt.value,
      body.rawValue,
      flags.value,
      method.value,
    );
  }

  /// Counterpart: swisseph::Ephemeris::get_orbital_elements
  OrbitalElements getOrbitalElements(JdTt jdEt, Body body, CalcFlags flags) {
    _checkOpen();
    return marshal.getOrbitalElements(
      _handle,
      jdEt.value,
      body.rawValue,
      flags.value,
    );
  }

  /// Counterpart: swisseph::Ephemeris::orbit_max_min_true_distance
  OrbitDistances orbitMaxMinTrueDistance(
    JdTt jdEt,
    Body body,
    CalcFlags flags,
  ) {
    _checkOpen();
    return marshal.orbitMaxMinTrueDistance(
      _handle,
      jdEt.value,
      body.rawValue,
      flags.value,
    );
  }

  /// Counterpart: swisseph::Ephemeris::pheno_with_config
  Phenomena phenoWithConfig(
    JdTt jdEt,
    Body body,
    CalcFlags flags,
    EphemerisConfig config,
  ) {
    _checkOpen();
    return marshal.phenoWithConfig(
      _handle,
      jdEt.value,
      body.rawValue,
      flags.value,
      config,
    );
  }

  /// Counterpart: swisseph::Ephemeris::pheno_ut_with_config
  Phenomena phenoUtWithConfig(
    JdUt1 jdUt,
    Body body,
    CalcFlags flags,
    EphemerisConfig config,
  ) {
    _checkOpen();
    return marshal.phenoUtWithConfig(
      _handle,
      jdUt.value,
      body.rawValue,
      flags.value,
      config,
    );
  }

  // -----------------------------------------------------------------------
  // Horizon & refraction (task /34)
  // -----------------------------------------------------------------------

  /// Counterpart: swisseph::Ephemeris::azalt
  AzaltResult azalt(
    JdUt1 jdUt,
    AzAltDir dir, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    double lapseRate = 0.0,
    required double xin0,
    required double xin1,
  }) {
    _checkOpen();
    return marshal.azalt(
      _handle,
      jdUt.value,
      dir.value,
      geolon,
      geolat,
      geoalt,
      atpress,
      attemp,
      lapseRate,
      xin0,
      xin1,
    );
  }

  /// Counterpart: swisseph::Ephemeris::azalt_rev
  ({double lon, double lat}) azaltRev(
    JdUt1 jdUt,
    HorDir dir, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required double azimuth,
    required double trueAltitude,
  }) {
    _checkOpen();
    return marshal.azaltRev(
      _handle,
      jdUt.value,
      dir.value,
      geolon,
      geolat,
      geoalt,
      azimuth,
      trueAltitude,
    );
  }

  // -----------------------------------------------------------------------
  // Fixed stars (task /33)
  // -----------------------------------------------------------------------

  /// Counterpart: swisseph::Ephemeris::fixstar2
  FixstarResult fixstar2(String star, JdTt jdEt, CalcFlags flags) {
    _checkOpen();
    return marshal.fixstar2(_handle, star, jdEt.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::fixstar2_ut
  FixstarResult fixstar2Ut(String star, JdUt1 jdUt, CalcFlags flags) {
    _checkOpen();
    return marshal.fixstar2Ut(_handle, star, jdUt.value, flags.value);
  }

  /// Counterpart: swisseph::Ephemeris::fixstar2_with_config
  FixstarResult fixstar2WithConfig(
    String star,
    JdTt jdEt,
    CalcFlags flags,
    EphemerisConfig config,
  ) {
    _checkOpen();
    return marshal.fixstar2WithConfig(
      _handle,
      star,
      jdEt.value,
      flags.value,
      config,
    );
  }

  /// Counterpart: swisseph::Ephemeris::fixstar2_ut_with_config
  FixstarResult fixstar2UtWithConfig(
    String star,
    JdUt1 jdUt,
    CalcFlags flags,
    EphemerisConfig config,
  ) {
    _checkOpen();
    return marshal.fixstar2UtWithConfig(
      _handle,
      star,
      jdUt.value,
      flags.value,
      config,
    );
  }

  /// Counterpart: swisseph::Ephemeris::fixstar2_mag
  FixstarMagResult fixstar2Mag(String star) {
    _checkOpen();
    return marshal.fixstar2Mag(_handle, star);
  }

  // -----------------------------------------------------------------------
  // Heliacal (task /33)
  // -----------------------------------------------------------------------

  /// Counterpart: swisseph::Ephemeris::heliacal_ut
  HeliacalEvent heliacalUt(
    JdUt1 jdStart,
    String objectName,
    HeliacalEventType event,
    CalcFlags epheflag,
    HeliacalFlags helflag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double pressure = 1013.25,
    double temperature = 15.0,
    double humidity = 40.0,
    double extinction = 0.0,
    double age = 36.0,
    double snellenRatio = 1.0,
    double opticType = 0,
    double aperture = 0,
    double magnification = 0,
    double transmission = 0,
  }) {
    _checkOpen();
    return marshal.heliacalUt(
      _handle,
      jdStart.value,
      geolon,
      geolat,
      geoalt,
      pressure,
      temperature,
      humidity,
      extinction,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
      objectName,
      event.value,
      epheflag.value | helflag.value,
    );
  }

  /// Counterpart: swisseph::Ephemeris::heliacal_pheno_ut
  HeliacalPheno heliacalPhenoUt(
    JdUt1 jdUt,
    String objectName,
    HeliacalEventType event,
    CalcFlags epheflag,
    HeliacalFlags helflag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double pressure = 1013.25,
    double temperature = 15.0,
    double humidity = 40.0,
    double extinction = 0.0,
    double age = 36.0,
    double snellenRatio = 1.0,
    double opticType = 0,
    double aperture = 0,
    double magnification = 0,
    double transmission = 0,
  }) {
    _checkOpen();
    return marshal.heliacalPhenoUt(
      _handle,
      jdUt.value,
      geolon,
      geolat,
      geoalt,
      pressure,
      temperature,
      humidity,
      extinction,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
      objectName,
      event.value,
      epheflag.value | helflag.value,
    );
  }

  /// Counterpart: swisseph::Ephemeris::vis_limit_mag
  VisLimitMagResult visLimitMag(
    JdUt1 jdUt,
    String objectName,
    CalcFlags epheflag,
    HeliacalFlags helflag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double pressure = 1013.25,
    double temperature = 15.0,
    double humidity = 40.0,
    double extinction = 0.0,
    double age = 36.0,
    double snellenRatio = 1.0,
    double opticType = 0,
    double aperture = 0,
    double magnification = 0,
    double transmission = 0,
  }) {
    _checkOpen();
    return marshal.visLimitMag(
      _handle,
      jdUt.value,
      geolon,
      geolat,
      geoalt,
      pressure,
      temperature,
      humidity,
      extinction,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
      objectName,
      epheflag.value | helflag.value,
    );
  }

  /// Counterpart: swisseph::Ephemeris::heliacal_angle
  HeliacalAngleResult heliacalAngle(
    JdUt1 jdUt,
    HeliacalFlags helflag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double pressure = 1013.25,
    double temperature = 15.0,
    double humidity = 40.0,
    double extinction = 0.0,
    double age = 36.0,
    double snellenRatio = 1.0,
    double opticType = 0,
    double aperture = 0,
    double magnification = 0,
    double transmission = 0,
    required double mag,
    required double aziObj,
    required double aziSun,
    required double aziMoon,
    required double altMoon,
  }) {
    _checkOpen();
    return marshal.heliacalAngle(
      _handle,
      jdUt.value,
      geolon,
      geolat,
      geoalt,
      pressure,
      temperature,
      humidity,
      extinction,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
      helflag.value,
      mag,
      aziObj,
      aziSun,
      aziMoon,
      altMoon,
    );
  }

  /// Counterpart: swisseph::Ephemeris::topo_arcus_visionis
  double topoArcusVisionis(
    JdUt1 jdUt,
    HeliacalFlags helflag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double pressure = 1013.25,
    double temperature = 15.0,
    double humidity = 40.0,
    double extinction = 0.0,
    double age = 36.0,
    double snellenRatio = 1.0,
    double opticType = 0,
    double aperture = 0,
    double magnification = 0,
    double transmission = 0,
    required double mag,
    required double aziObj,
    required double altObj,
    required double aziSun,
    required double aziMoon,
    required double altMoon,
  }) {
    _checkOpen();
    return marshal.topoArcusVisionis(
      _handle,
      jdUt.value,
      geolon,
      geolat,
      geoalt,
      pressure,
      temperature,
      humidity,
      extinction,
      age,
      snellenRatio,
      opticType,
      aperture,
      magnification,
      transmission,
      helflag.value,
      mag,
      aziObj,
      altObj,
      aziSun,
      aziMoon,
      altMoon,
    );
  }
}

/// Counterpart: swisseph_ffi::swisseph_version
String get engineVersion => marshal.engineVersion();

/// Counterpart: swisseph::date::julday
JdUt1 julday(int year, int month, int day, double hour, CalendarType cal) {
  return JdUt1(marshal.julday(year, month, day, hour, cal.value));
}

/// Counterpart: swisseph::date::revjul
({int year, int month, int day, double hour}) revjul(
  double jd,
  CalendarType cal,
) {
  return marshal.revjul(jd, cal.value);
}

/// Counterpart: swisseph::date::date_conversion
JdUt1 dateConversion(
  int year,
  int month,
  int day,
  double hour,
  CalendarType cal,
) {
  final calChar = cal == CalendarType.gregorian ? 0x67 : 0x6A; // 'g' or 'j'
  return JdUt1(marshal.dateConversion(year, month, day, hour, calChar));
}

/// Counterpart: swisseph::date::day_of_week
int dayOfWeek(double jd) {
  return marshal.dayOfWeek(jd);
}

/// Counterpart: swisseph::date::utc_time_zone
UtcComponents utcTimeZone(UtcComponents input, double tzOffset) {
  return marshal.utcTimeZone(
    input.year,
    input.month,
    input.day,
    input.hour,
    input.minute,
    input.second,
    tzOffset,
  );
}

/// Counterpart: swisseph::math::split_degrees
DegreeParts splitDegrees(double ddeg, SplitDegFlags flags) {
  return marshal.splitDegrees(ddeg, flags.value);
}

/// Counterpart: swisseph::math::normalize_degrees
double normalizeDegrees(double x) {
  var result = x % 360.0;
  if (result < 0) result += 360.0;
  return result;
}

/// Counterpart: swisseph::math::cotrans
List<double> cotrans(double lon, double lat, double dist, double eps) {
  return marshal.cotrans(lon, lat, dist, eps);
}

/// Counterpart: swisseph::math::cotrans_with_speed
List<double> cotransWithSpeed(
  double lon,
  double lat,
  double dist,
  double lonSpeed,
  double latSpeed,
  double distSpeed,
  double eps,
) {
  return marshal.cotransWithSpeed(
    lon,
    lat,
    dist,
    lonSpeed,
    latSpeed,
    distSpeed,
    eps,
  );
}

/// Counterpart: swisseph::houses::houses_armc
HouseResult housesArmc(
  double armc,
  double geolat,
  double eps,
  HouseSystem hsys, {
  double? sundec,
}) {
  return marshal.housesArmcEx2(
    armc,
    geolat,
    eps,
    hsys.charCode,
    sundec: sundec,
  );
}

/// Counterpart: swisseph::houses::house_pos
double housePos(
  double armc,
  double geolat,
  double eps,
  HouseSystem hsys,
  double bodyLon,
  double bodyLat, {
  double? sundec,
}) {
  return marshal.housePos(
    armc,
    geolat,
    eps,
    hsys.charCode,
    bodyLon,
    bodyLat,
    sundec: sundec,
  );
}

/// Counterpart: swisseph::types::HouseSystem::name
String houseName(HouseSystem hsys) {
  return marshal.houseName(hsys.charCode);
}

/// Counterpart: swisseph_ffi::swisseph_get_ayanamsa_name
String getAyanamsaName(SiderealMode sidMode) {
  return marshal.getAyanamsaName(sidMode.value);
}

/// Counterpart: swisseph::azalt::refrac
double refrac(double inalt, double atpress, double attemp, RefracDir dir) {
  return marshal.refrac(inalt, atpress, attemp, dir.value);
}

/// Counterpart: swisseph::azalt::refrac_extended
RefracExtendedResult refracExtended(
  double inalt,
  double geoalt,
  double atpress,
  double attemp,
  double lapseRate,
  RefracDir dir,
) {
  return marshal.refracExtended(
    inalt,
    geoalt,
    atpress,
    attemp,
    lapseRate,
    dir.value,
  );
}
