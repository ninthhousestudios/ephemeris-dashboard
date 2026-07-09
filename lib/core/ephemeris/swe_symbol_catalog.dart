// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph/src/constants.dart';

enum CodeTarget { c, dart }

enum TracedFunction {
  sweAzalt('swe_azalt', 'azAlt'),
  sweAzaltRev('swe_azalt_rev', 'azAltRev'),
  sweCalcPctr('swe_calc_pctr', 'calcPctr'),
  sweCalcUt('swe_calc_ut', 'calcUt'),
  sweCotrans('swe_cotrans', 'cotrans'),
  sweDeltat('swe_deltat', 'deltat'),
  sweFixstar2Ut('swe_fixstar2_ut', 'fixstar2Ut'),
  sweGauquelinSector('swe_gauquelin_sector', 'gauquelinSector'),
  sweGetAyanamsaExUt('swe_get_ayanamsa_ex_ut', 'getAyanamsaExUt'),
  sweGetAyanamsaUt('swe_get_ayanamsa_ut', 'getAyanamsaUt'),
  sweGetOrbitalElements('swe_get_orbital_elements', 'getOrbitalElements'),
  sweHeliacalUt('swe_heliacal_ut', 'heliacalUt'),
  sweHeliocrossUt('swe_heliocross_ut', 'helioCrossUt'),
  sweHouses('swe_houses', 'houses'),
  sweLatToLmt('swe_lat_to_lmt', 'latToLmt'),
  sweLmtToLat('swe_lmt_to_lat', 'lmtToLat'),
  sweLunEclipseHow('swe_lun_eclipse_how', 'lunEclipseHow'),
  sweLunEclipseWhen('swe_lun_eclipse_when', 'lunEclipseWhen'),
  sweLunEclipseWhenLoc('swe_lun_eclipse_when_loc', 'lunEclipseWhenLoc'),
  sweMooncrossNodeUt('swe_mooncross_node_ut', 'moonCrossNodeUt'),
  sweMooncrossUt('swe_mooncross_ut', 'moonCrossUt'),
  sweNodApsUt('swe_nod_aps_ut', 'nodApsUt'),
  sweOrbitMaxMinTrueDistance(
    'swe_orbit_max_min_true_distance',
    'orbitMaxMinTrueDistance',
  ),
  swePhenoUt('swe_pheno_ut', 'phenoUt'),
  sweRefrac('swe_refrac', 'refrac'),
  sweRiseTrans('swe_rise_trans', 'riseTrans'),
  sweRiseTransTrueHor('swe_rise_trans_true_hor', 'riseTransTrueHor'),
  sweSetEphePath('swe_set_ephe_path', 'setEphePath'),
  sweSetJplFile('swe_set_jpl_file', 'setJplFile'),
  sweSetSidMode('swe_set_sid_mode', 'setSidMode'),
  sweSetTopo('swe_set_topo', 'setTopo'),
  sweSidtime('swe_sidtime', 'sidTime'),
  sweSidtime0('swe_sidtime0', 'sidTime0'),
  sweSolcrossUt('swe_solcross_ut', 'solCrossUt'),
  sweSolEclipseHow('swe_sol_eclipse_how', 'solEclipseHow'),
  sweSolEclipseWhenGlob('swe_sol_eclipse_when_glob', 'solEclipseWhenGlob'),
  sweSolEclipseWhenLoc('swe_sol_eclipse_when_loc', 'solEclipseWhenLoc'),
  sweSolEclipseWhere('swe_sol_eclipse_where', 'solEclipseWhere'),
  sweTimeEqu('swe_time_equ', 'timeEqu');

  const TracedFunction(this.cName, this.dartMethodName);
  final String cName;
  final String dartMethodName;
}

typedef SymbolPair = ({String c, String dart});

class SweSymbolCatalog {
  SweSymbolCatalog._();

  static const _bodies = <int, SymbolPair>{
    seEclNut: (c: 'SE_ECL_NUT', dart: 'seEclNut'),
    seSun: (c: 'SE_SUN', dart: 'seSun'),
    seMoon: (c: 'SE_MOON', dart: 'seMoon'),
    seMercury: (c: 'SE_MERCURY', dart: 'seMercury'),
    seVenus: (c: 'SE_VENUS', dart: 'seVenus'),
    seMars: (c: 'SE_MARS', dart: 'seMars'),
    seJupiter: (c: 'SE_JUPITER', dart: 'seJupiter'),
    seSaturn: (c: 'SE_SATURN', dart: 'seSaturn'),
    seUranus: (c: 'SE_URANUS', dart: 'seUranus'),
    seNeptune: (c: 'SE_NEPTUNE', dart: 'seNeptune'),
    sePluto: (c: 'SE_PLUTO', dart: 'sePluto'),
    seMeanNode: (c: 'SE_MEAN_NODE', dart: 'seMeanNode'),
    seTrueNode: (c: 'SE_TRUE_NODE', dart: 'seTrueNode'),
    seMeanApog: (c: 'SE_MEAN_APOG', dart: 'seMeanApog'),
    seOscuApog: (c: 'SE_OSCU_APOG', dart: 'seOscuApog'),
    seEarth: (c: 'SE_EARTH', dart: 'seEarth'),
    seChiron: (c: 'SE_CHIRON', dart: 'seChiron'),
    sePholus: (c: 'SE_PHOLUS', dart: 'sePholus'),
    seCeres: (c: 'SE_CERES', dart: 'seCeres'),
    sePallas: (c: 'SE_PALLAS', dart: 'sePallas'),
    seJuno: (c: 'SE_JUNO', dart: 'seJuno'),
    seVesta: (c: 'SE_VESTA', dart: 'seVesta'),
    seIntpApog: (c: 'SE_INTP_APOG', dart: 'seIntpApog'),
    seIntpPerg: (c: 'SE_INTP_PERG', dart: 'seIntpPerg'),
    seCupido: (c: 'SE_CUPIDO', dart: 'seCupido'),
    seHades: (c: 'SE_HADES', dart: 'seHades'),
    seZeus: (c: 'SE_ZEUS', dart: 'seZeus'),
    seKronos: (c: 'SE_KRONOS', dart: 'seKronos'),
    seApollon: (c: 'SE_APOLLON', dart: 'seApollon'),
    seAdmetos: (c: 'SE_ADMETOS', dart: 'seAdmetos'),
    seVulkanus: (c: 'SE_VULKANUS', dart: 'seVulkanus'),
    sePoseidon: (c: 'SE_POSEIDON', dart: 'sePoseidon'),
  };

  static const _flags = <int, SymbolPair>{
    seFlgJplEph: (c: 'SEFLG_JPLEPH', dart: 'seFlgJplEph'),
    seFlgSwiEph: (c: 'SEFLG_SWIEPH', dart: 'seFlgSwiEph'),
    seFlgMosEph: (c: 'SEFLG_MOSEPH', dart: 'seFlgMosEph'),
    seFlgHelCtr: (c: 'SEFLG_HELCTR', dart: 'seFlgHelCtr'),
    seFlgTruePos: (c: 'SEFLG_TRUEPOS', dart: 'seFlgTruePos'),
    seFlgJ2000: (c: 'SEFLG_J2000', dart: 'seFlgJ2000'),
    seFlgNoNut: (c: 'SEFLG_NONUT', dart: 'seFlgNoNut'),
    seFlgSpeed3: (c: 'SEFLG_SPEED3', dart: 'seFlgSpeed3'),
    seFlgSpeed: (c: 'SEFLG_SPEED', dart: 'seFlgSpeed'),
    seFlgNoGdefl: (c: 'SEFLG_NOGDEFL', dart: 'seFlgNoGdefl'),
    seFlgNoAberr: (c: 'SEFLG_NOABERR', dart: 'seFlgNoAberr'),
    seFlgEquatorial: (c: 'SEFLG_EQUATORIAL', dart: 'seFlgEquatorial'),
    seFlgXyz: (c: 'SEFLG_XYZ', dart: 'seFlgXyz'),
    seFlgRadians: (c: 'SEFLG_RADIANS', dart: 'seFlgRadians'),
    seFlgBaryCtr: (c: 'SEFLG_BARYCTR', dart: 'seFlgBaryCtr'),
    seFlgTopoCtr: (c: 'SEFLG_TOPOCTR', dart: 'seFlgTopoCtr'),
    seFlgSidereal: (c: 'SEFLG_SIDEREAL', dart: 'seFlgSidereal'),
    seFlgIcrs: (c: 'SEFLG_ICRS', dart: 'seFlgIcrs'),
    seFlgJplHor: (c: 'SEFLG_JPLHOR', dart: 'seFlgJplHor'),
    seFlgJplHorApprox: (c: 'SEFLG_JPLHOR_APPROX', dart: 'seFlgJplHorApprox'),
    seFlgCenterBody: (c: 'SEFLG_CENTER_BODY', dart: 'seFlgCenterBody'),
  };

  static const _sidModes = <int, SymbolPair>{
    seSidmFaganBradley: (
      c: 'SE_SIDM_FAGAN_BRADLEY',
      dart: 'seSidmFaganBradley',
    ),
    seSidmLahiri: (c: 'SE_SIDM_LAHIRI', dart: 'seSidmLahiri'),
    seSidmDeluce: (c: 'SE_SIDM_DELUCE', dart: 'seSidmDeluce'),
    seSidmRaman: (c: 'SE_SIDM_RAMAN', dart: 'seSidmRaman'),
    seSidmUshashashi: (c: 'SE_SIDM_USHASHASHI', dart: 'seSidmUshashashi'),
    seSidmKrishnamurti: (c: 'SE_SIDM_KRISHNAMURTI', dart: 'seSidmKrishnamurti'),
    seSidmDjwhalKhul: (c: 'SE_SIDM_DJWHAL_KHUL', dart: 'seSidmDjwhalKhul'),
    seSidmYukteshwar: (c: 'SE_SIDM_YUKTESHWAR', dart: 'seSidmYukteshwar'),
    seSidmJnBhasin: (c: 'SE_SIDM_JN_BHASIN', dart: 'seSidmJnBhasin'),
    seSidmBabylKugler1: (
      c: 'SE_SIDM_BABYL_KUGLER1',
      dart: 'seSidmBabylKugler1',
    ),
    seSidmBabylKugler2: (
      c: 'SE_SIDM_BABYL_KUGLER2',
      dart: 'seSidmBabylKugler2',
    ),
    seSidmBabylKugler3: (
      c: 'SE_SIDM_BABYL_KUGLER3',
      dart: 'seSidmBabylKugler3',
    ),
    seSidmBabylHuber: (c: 'SE_SIDM_BABYL_HUBER', dart: 'seSidmBabylHuber'),
    seSidmBabylEtpsc: (c: 'SE_SIDM_BABYL_ETPSC', dart: 'seSidmBabylEtpsc'),
    seSidmAldebaran15tau: (
      c: 'SE_SIDM_ALDEBARAN_15TAU',
      dart: 'seSidmAldebaran15tau',
    ),
    seSidmHipparchos: (c: 'SE_SIDM_HIPPARCHOS', dart: 'seSidmHipparchos'),
    seSidmSassanian: (c: 'SE_SIDM_SASSANIAN', dart: 'seSidmSassanian'),
    seSidmGalcent0sag: (c: 'SE_SIDM_GALCENT_0SAG', dart: 'seSidmGalcent0sag'),
    seSidmJ2000: (c: 'SE_SIDM_J2000', dart: 'seSidmJ2000'),
    seSidmJ1900: (c: 'SE_SIDM_J1900', dart: 'seSidmJ1900'),
    seSidmB1950: (c: 'SE_SIDM_B1950', dart: 'seSidmB1950'),
    seSidmSuryasiddhanta: (
      c: 'SE_SIDM_SURYASIDDHANTA',
      dart: 'seSidmSuryasiddhanta',
    ),
    seSidmSuryasiddhantaMsun: (
      c: 'SE_SIDM_SURYASIDDHANTA_MSUN',
      dart: 'seSidmSuryasiddhantaMsun',
    ),
    seSidmAryabhata: (c: 'SE_SIDM_ARYABHATA', dart: 'seSidmAryabhata'),
    seSidmAryabhataMsun: (
      c: 'SE_SIDM_ARYABHATA_MSUN',
      dart: 'seSidmAryabhataMsun',
    ),
    seSidmSsRevati: (c: 'SE_SIDM_SS_REVATI', dart: 'seSidmSsRevati'),
    seSidmSsCitra: (c: 'SE_SIDM_SS_CITRA', dart: 'seSidmSsCitra'),
    seSidmTrueCitra: (c: 'SE_SIDM_TRUE_CITRA', dart: 'seSidmTrueCitra'),
    seSidmTrueRevati: (c: 'SE_SIDM_TRUE_REVATI', dart: 'seSidmTrueRevati'),
    seSidmTruePushya: (c: 'SE_SIDM_TRUE_PUSHYA', dart: 'seSidmTruePushya'),
    seSidmGalcentRgilbrand: (
      c: 'SE_SIDM_GALCENT_RGILBRAND',
      dart: 'seSidmGalcentRgilbrand',
    ),
    seSidmGalequIau1958: (
      c: 'SE_SIDM_GALEQU_IAU1958',
      dart: 'seSidmGalequIau1958',
    ),
    seSidmGalequTrue: (c: 'SE_SIDM_GALEQU_TRUE', dart: 'seSidmGalequTrue'),
    seSidmGalequMula: (c: 'SE_SIDM_GALEQU_MULA', dart: 'seSidmGalequMula'),
    seSidmGalalignMardyks: (
      c: 'SE_SIDM_GALALIGN_MARDYKS',
      dart: 'seSidmGalalignMardyks',
    ),
    seSidmTrueMula: (c: 'SE_SIDM_TRUE_MULA', dart: 'seSidmTrueMula'),
    seSidmGalcentMulaWilhelm: (
      c: 'SE_SIDM_GALCENT_MULA_WILHELM',
      dart: 'seSidmGalcentMulaWilhelm',
    ),
    seSidmAryabhata522: (
      c: 'SE_SIDM_ARYABHATA_522',
      dart: 'seSidmAryabhata522',
    ),
    seSidmBabylBritton: (
      c: 'SE_SIDM_BABYL_BRITTON',
      dart: 'seSidmBabylBritton',
    ),
    seSidmTrueSheoran: (c: 'SE_SIDM_TRUE_SHEORAN', dart: 'seSidmTrueSheoran'),
    seSidmGalcentCochrane: (
      c: 'SE_SIDM_GALCENT_COCHRANE',
      dart: 'seSidmGalcentCochrane',
    ),
    seSidmGalequFiorenza: (
      c: 'SE_SIDM_GALEQU_FIORENZA',
      dart: 'seSidmGalequFiorenza',
    ),
    seSidmValensMoon: (c: 'SE_SIDM_VALENS_MOON', dart: 'seSidmValensMoon'),
    seSidmLahiri1940: (c: 'SE_SIDM_LAHIRI_1940', dart: 'seSidmLahiri1940'),
    seSidmLahiriVp285: (c: 'SE_SIDM_LAHIRI_VP285', dart: 'seSidmLahiriVp285'),
    seSidmKrishnamurtiVp291: (
      c: 'SE_SIDM_KRISHNAMURTI_VP291',
      dart: 'seSidmKrishnamurtiVp291',
    ),
    seSidmLahiriIcrc: (c: 'SE_SIDM_LAHIRI_ICRC', dart: 'seSidmLahiriIcrc'),
    seSidmUser: (c: 'SE_SIDM_USER', dart: 'seSidmUser'),
  };

  static const _houseSystems = <int, String>{
    hsysPlacidus: 'Placidus',
    hsysKoch: 'Koch',
    hsysPorphyry: 'Porphyry',
    hsysRegiomontanus: 'Regiomontanus',
    hsysCampanus: 'Campanus',
    hsysEqual: 'Equal',
    hsysWholeSign: 'Whole Sign',
    hsysAlcabitius: 'Alcabitius',
    hsysTopocentric: 'Topocentric',
    hsysMeridian: 'Meridian',
    hsysMorinus: 'Morinus',
    hsysKrusinski: 'Krusinski-Pisa',
    hsysVehlow: 'Vehlow Equal',
    hsysGauquelin: 'Gauquelin Sectors',
  };

  static String bodyName(int body, CodeTarget target) {
    final pair = _bodies[body];
    if (pair == null) return body.toString();
    return switch (target) {
      CodeTarget.c => pair.c,
      CodeTarget.dart => pair.dart,
    };
  }

  static String sidModeName(int mode, CodeTarget target) {
    final pair = _sidModes[mode];
    if (pair == null) return mode.toString();
    return switch (target) {
      CodeTarget.c => pair.c,
      CodeTarget.dart => pair.dart,
    };
  }

  static String houseSysName(int hsys) =>
      _houseSystems[hsys] ?? hsys.toString();

  static List<String> flagDecompose(int flags, CodeTarget target) {
    final result = <String>[];
    var remainder = flags;
    for (final entry in _flags.entries) {
      if (remainder & entry.key == entry.key) {
        result.add(switch (target) {
          CodeTarget.c => entry.value.c,
          CodeTarget.dart => entry.value.dart,
        });
        remainder &= ~entry.key;
      }
    }
    if (remainder != 0) {
      result.add(remainder.toString());
    }
    return result;
  }
}
