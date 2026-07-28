// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'flags.dart';

// --------------------------------------------------------------------------
// Ephemeris source
// --------------------------------------------------------------------------

/// Counterpart: swisseph::config::EphemerisSource
enum EphemerisSource {
  /// Counterpart: swisseph::config::EphemerisSource::Moshier
  moshier(0),

  /// Counterpart: swisseph::config::EphemerisSource::Swiss
  swiss(1),

  /// Counterpart: swisseph::config::EphemerisSource::Jpl
  jpl(2);

  final int value;
  const EphemerisSource(this.value);
}

// --------------------------------------------------------------------------
// Sidereal mode (47 variants)
// --------------------------------------------------------------------------

/// Counterpart: swisseph::types::SiderealMode
enum SiderealMode {
  /// Counterpart: swisseph::types::SiderealMode::FaganBradley
  faganBradley(0),

  /// Counterpart: swisseph::types::SiderealMode::Lahiri
  lahiri(1),

  /// Counterpart: swisseph::types::SiderealMode::DeLuce
  deLuce(2),

  /// Counterpart: swisseph::types::SiderealMode::Raman
  raman(3),

  /// Counterpart: swisseph::types::SiderealMode::Ushashashi
  ushashashi(4),

  /// Counterpart: swisseph::types::SiderealMode::Krishnamurti
  krishnamurti(5),

  /// Counterpart: swisseph::types::SiderealMode::DjwhalKhul
  djwhalKhul(6),

  /// Counterpart: swisseph::types::SiderealMode::Yukteshwar
  yukteshwar(7),

  /// Counterpart: swisseph::types::SiderealMode::JnBhasin
  jnBhasin(8),

  /// Counterpart: swisseph::types::SiderealMode::BabylKugler1
  babylKugler1(9),

  /// Counterpart: swisseph::types::SiderealMode::BabylKugler2
  babylKugler2(10),

  /// Counterpart: swisseph::types::SiderealMode::BabylKugler3
  babylKugler3(11),

  /// Counterpart: swisseph::types::SiderealMode::BabylHuber
  babylHuber(12),

  /// Counterpart: swisseph::types::SiderealMode::BabylEtpsc
  babylEtpsc(13),

  /// Counterpart: swisseph::types::SiderealMode::Aldebaran15Tau
  aldebaran15Tau(14),

  /// Counterpart: swisseph::types::SiderealMode::Hipparchos
  hipparchos(15),

  /// Counterpart: swisseph::types::SiderealMode::Sassanian
  sassanian(16),

  /// Counterpart: swisseph::types::SiderealMode::GalCent0Sag
  galCent0Sag(17),

  /// Counterpart: swisseph::types::SiderealMode::J2000
  j2000(18),

  /// Counterpart: swisseph::types::SiderealMode::J1900
  j1900(19),

  /// Counterpart: swisseph::types::SiderealMode::B1950
  b1950(20),

  /// Counterpart: swisseph::types::SiderealMode::Suryasiddhanta
  suryasiddhanta(21),

  /// Counterpart: swisseph::types::SiderealMode::SuryasiddhantaMsun
  suryasiddhantaMsun(22),

  /// Counterpart: swisseph::types::SiderealMode::Aryabhata
  aryabhata(23),

  /// Counterpart: swisseph::types::SiderealMode::AryabhataMsun
  aryabhataMsun(24),

  /// Counterpart: swisseph::types::SiderealMode::SsRevati
  ssRevati(25),

  /// Counterpart: swisseph::types::SiderealMode::SsCitra
  ssCitra(26),

  /// Counterpart: swisseph::types::SiderealMode::TrueCitra
  trueCitra(27),

  /// Counterpart: swisseph::types::SiderealMode::TrueRevati
  trueRevati(28),

  /// Counterpart: swisseph::types::SiderealMode::TruePushya
  truePushya(29),

  /// Counterpart: swisseph::types::SiderealMode::GalCentRgilbrand
  galCentRgilbrand(30),

  /// Counterpart: swisseph::types::SiderealMode::GalEquIau1958
  galEquIau1958(31),

  /// Counterpart: swisseph::types::SiderealMode::GalEquTrue
  galEquTrue(32),

  /// Counterpart: swisseph::types::SiderealMode::GalEquMula
  galEquMula(33),

  /// Counterpart: swisseph::types::SiderealMode::GalAlignMardyks
  galAlignMardyks(34),

  /// Counterpart: swisseph::types::SiderealMode::TrueMula
  trueMula(35),

  /// Counterpart: swisseph::types::SiderealMode::GalCentMulaWilhelm
  galCentMulaWilhelm(36),

  /// Counterpart: swisseph::types::SiderealMode::Aryabhata522
  aryabhata522(37),

  /// Counterpart: swisseph::types::SiderealMode::BabylBritton
  babylBritton(38),

  /// Counterpart: swisseph::types::SiderealMode::TrueSheoran
  trueSheoran(39),

  /// Counterpart: swisseph::types::SiderealMode::GalCentCochrane
  galCentCochrane(40),

  /// Counterpart: swisseph::types::SiderealMode::GalEquFiorenza
  galEquFiorenza(41),

  /// Counterpart: swisseph::types::SiderealMode::ValensMoon
  valensMoon(42),

  /// Counterpart: swisseph::types::SiderealMode::Lahiri1940
  lahiri1940(43),

  /// Counterpart: swisseph::types::SiderealMode::LahiriVp285
  lahiriVp285(44),

  /// Counterpart: swisseph::types::SiderealMode::KrishnamurtiVp291
  krishnamurtiVp291(45),

  /// Counterpart: swisseph::types::SiderealMode::LahiriIcrc
  lahiriIcrc(46),

  /// Counterpart: swisseph::types::SiderealMode::User
  user(255);

  final int value;
  const SiderealMode(this.value);
}

// --------------------------------------------------------------------------
// Astronomical model enums
// --------------------------------------------------------------------------

/// Counterpart: swisseph::types::PrecessionModel
enum PrecessionModel {
  /// Counterpart: swisseph::types::PrecessionModel::IAU1976
  iau1976(1),

  /// Counterpart: swisseph::types::PrecessionModel::Laskar1986
  laskar1986(2),

  /// Counterpart: swisseph::types::PrecessionModel::WillEpsLask
  willEpsLask(3),

  /// Counterpart: swisseph::types::PrecessionModel::Williams1994
  williams1994(4),

  /// Counterpart: swisseph::types::PrecessionModel::Simon1994
  simon1994(5),

  /// Counterpart: swisseph::types::PrecessionModel::IAU2000
  iau2000(6),

  /// Counterpart: swisseph::types::PrecessionModel::Bretagnon2003
  bretagnon2003(7),

  /// Counterpart: swisseph::types::PrecessionModel::IAU2006
  iau2006(8),

  /// Counterpart: swisseph::types::PrecessionModel::Vondrak2011
  vondrak2011(9),

  /// Counterpart: swisseph::types::PrecessionModel::Owen1990
  owen1990(10),

  /// Counterpart: swisseph::types::PrecessionModel::Newcomb
  newcomb(11);

  final int value;
  const PrecessionModel(this.value);
}

/// Counterpart: swisseph::types::NutationModel
enum NutationModel {
  /// Counterpart: swisseph::types::NutationModel::IAU1980
  iau1980(1),

  /// Counterpart: swisseph::types::NutationModel::IAUCorr1987
  iauCorr1987(2),

  /// Counterpart: swisseph::types::NutationModel::IAU2000A
  iau2000A(3),

  /// Counterpart: swisseph::types::NutationModel::IAU2000B
  iau2000B(4),

  /// Counterpart: swisseph::types::NutationModel::Woolard
  woolard(5);

  final int value;
  const NutationModel(this.value);
}

/// Counterpart: swisseph::types::DeltaTModel
enum DeltaTModel {
  /// Counterpart: swisseph::types::DeltaTModel::StephensonMorrison1984
  stephensonMorrison1984(1),

  /// Counterpart: swisseph::types::DeltaTModel::Stephenson1997
  stephenson1997(2),

  /// Counterpart: swisseph::types::DeltaTModel::StephensonMorrison2004
  stephensonMorrison2004(3),

  /// Counterpart: swisseph::types::DeltaTModel::EspenakMeeus2006
  espenakMeeus2006(4),

  /// Counterpart: swisseph::types::DeltaTModel::StephensonEtc2016
  stephensonEtc2016(5);

  final int value;
  const DeltaTModel(this.value);
}

/// Counterpart: swisseph::types::SiderealTimeModel
enum SiderealTimeModel {
  /// Counterpart: swisseph::types::SiderealTimeModel::IAU1976
  iau1976(1),

  /// Counterpart: swisseph::types::SiderealTimeModel::IAU2006
  iau2006(2),

  /// Counterpart: swisseph::types::SiderealTimeModel::IersConv2010
  iersConv2010(3),

  /// Counterpart: swisseph::types::SiderealTimeModel::Longterm
  longterm(4);

  final int value;
  const SiderealTimeModel(this.value);
}

/// Counterpart: swisseph::types::BiasModel
enum BiasModel {
  /// Counterpart: swisseph::types::BiasModel::None
  none(1),

  /// Counterpart: swisseph::types::BiasModel::IAU2000
  iau2000(2),

  /// Counterpart: swisseph::types::BiasModel::IAU2006
  iau2006(3);

  final int value;
  const BiasModel(this.value);
}

/// Counterpart: swisseph::types::JplHorMode
enum JplHorMode {
  /// Counterpart: swisseph::types::JplHorMode::LongAgreement
  longAgreement(1);

  final int value;
  const JplHorMode(this.value);
}

/// Counterpart: swisseph::types::JplHoraMode
enum JplHoraMode {
  /// Counterpart: swisseph::types::JplHoraMode::V1
  v1(1),

  /// Counterpart: swisseph::types::JplHoraMode::V2
  v2(2),

  /// Counterpart: swisseph::types::JplHoraMode::V3
  v3(3);

  final int value;
  const JplHoraMode(this.value);
}

/// Counterpart: swisseph::types::AstroModels
final class AstroModels {
  /// Counterpart: swisseph::types::AstroModels::delta_t
  final DeltaTModel deltaT;

  /// Counterpart: swisseph::types::AstroModels::prec_longterm
  final PrecessionModel precLongterm;

  /// Counterpart: swisseph::types::AstroModels::prec_shortterm
  final PrecessionModel precShortterm;

  /// Counterpart: swisseph::types::AstroModels::nutation
  final NutationModel nutation;

  /// Counterpart: swisseph::types::AstroModels::bias
  final BiasModel bias;

  /// Counterpart: swisseph::types::AstroModels::jplhor_mode
  final JplHorMode jplhorMode;

  /// Counterpart: swisseph::types::AstroModels::jplhora_mode
  final JplHoraMode jplhoraMode;

  /// Counterpart: swisseph::types::AstroModels::sidereal_time
  final SiderealTimeModel siderealTime;

  const AstroModels({
    this.deltaT = DeltaTModel.stephensonEtc2016,
    this.precLongterm = PrecessionModel.vondrak2011,
    this.precShortterm = PrecessionModel.vondrak2011,
    this.nutation = NutationModel.iau2000B,
    this.bias = BiasModel.iau2006,
    this.jplhorMode = JplHorMode.longAgreement,
    this.jplhoraMode = JplHoraMode.v3,
    this.siderealTime = SiderealTimeModel.longterm,
  });
}

// --------------------------------------------------------------------------
// Geographic position
// --------------------------------------------------------------------------

/// Counterpart: swisseph::config::TopoPosition
final class TopoPosition {
  final double longitude;
  final double latitude;
  final double altitude;

  const TopoPosition({
    required this.longitude,
    required this.latitude,
    required this.altitude,
  });
}

// --------------------------------------------------------------------------
// Ephemeris configuration (immutable)
// --------------------------------------------------------------------------

/// Counterpart: swisseph::config::EphemerisConfig
final class EphemerisConfig {
  /// Counterpart: swisseph::config::EphemerisConfig::ephemeris_source
  final EphemerisSource ephemerisSource;

  /// Counterpart: swisseph::config::EphemerisConfig::ephe_path
  final String? ephePath;

  /// Counterpart: swisseph::config::EphemerisConfig::jpl_filename
  final String? jplFilename;

  /// Counterpart: swisseph::config::EphemerisConfig::sidereal_mode
  final SiderealMode? siderealMode;

  /// Counterpart: swisseph::config::EphemerisConfig::sidereal_t0
  final double siderealT0;

  /// Counterpart: swisseph::config::EphemerisConfig::sidereal_ayan_t0
  final double siderealAyanT0;

  /// Counterpart: swisseph::config::EphemerisConfig::sidereal_bits
  final SiderealBits siderealBits;

  /// Counterpart: swisseph::config::EphemerisConfig::sidereal_t0_is_ut
  final bool siderealT0IsUt;

  /// Counterpart: swisseph::config::EphemerisConfig::topographic
  final TopoPosition? topographic;

  /// Counterpart: swisseph::config::EphemerisConfig::astro_models
  ///
  /// When null, the engine uses its compiled-in defaults.
  final AstroModels? astroModels;

  /// Counterpart: swisseph::config::EphemerisConfig::tidal_acceleration
  ///
  /// When null, auto-derived from the ephemeris DE number.
  final double? tidalAcceleration;

  /// Counterpart: swisseph::config::EphemerisConfig::delta_t_userdef
  ///
  /// When non-null (days), bypasses all Delta T models.
  final double? deltaTUserdef;

  /// Counterpart: swisseph::config::EphemerisConfig::extra_leap_seconds
  final List<int> extraLeapSeconds;

  /// Counterpart: swisseph::config::EphemerisConfig::leap_seconds_file
  final String? leapSecondsFile;

  /// Counterpart: swisseph::config::EphemerisConfig::asteroid_numbers
  final List<int> asteroidNumbers;

  /// Counterpart: swisseph::config::EphemerisConfig::planet_moon_numbers
  final List<int> planetMoonNumbers;

  const EphemerisConfig({
    this.ephemerisSource = EphemerisSource.moshier,
    this.ephePath,
    this.jplFilename,
    this.siderealMode,
    this.siderealT0 = 0,
    this.siderealAyanT0 = 0,
    this.siderealBits = SiderealBits.none,
    this.siderealT0IsUt = false,
    this.topographic,
    this.astroModels,
    this.tidalAcceleration,
    this.deltaTUserdef,
    this.extraLeapSeconds = const [],
    this.leapSecondsFile,
    this.asteroidNumbers = const [],
    this.planetMoonNumbers = const [],
  });
}
