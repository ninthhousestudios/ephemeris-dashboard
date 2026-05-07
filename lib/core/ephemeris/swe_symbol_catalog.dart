import 'package:swisseph/src/constants.dart';

class SweSymbolCatalog {
  SweSymbolCatalog._();

  static const _bodies = <int, String>{
    seEclNut: 'SE_ECL_NUT',
    seSun: 'SE_SUN',
    seMoon: 'SE_MOON',
    seMercury: 'SE_MERCURY',
    seVenus: 'SE_VENUS',
    seMars: 'SE_MARS',
    seJupiter: 'SE_JUPITER',
    seSaturn: 'SE_SATURN',
    seUranus: 'SE_URANUS',
    seNeptune: 'SE_NEPTUNE',
    sePluto: 'SE_PLUTO',
    seMeanNode: 'SE_MEAN_NODE',
    seTrueNode: 'SE_TRUE_NODE',
    seMeanApog: 'SE_MEAN_APOG',
    seOscuApog: 'SE_OSCU_APOG',
    seEarth: 'SE_EARTH',
    seChiron: 'SE_CHIRON',
    sePholus: 'SE_PHOLUS',
    seCeres: 'SE_CERES',
    sePallas: 'SE_PALLAS',
    seJuno: 'SE_JUNO',
    seVesta: 'SE_VESTA',
    seIntpApog: 'SE_INTP_APOG',
    seIntpPerg: 'SE_INTP_PERG',
    seCupido: 'SE_CUPIDO',
    seHades: 'SE_HADES',
    seZeus: 'SE_ZEUS',
    seKronos: 'SE_KRONOS',
    seApollon: 'SE_APOLLON',
    seAdmetos: 'SE_ADMETOS',
    seVulkanus: 'SE_VULKANUS',
    sePoseidon: 'SE_POSEIDON',
  };

  static const _flags = <int, String>{
    seFlgJplEph: 'SEFLG_JPLEPH',
    seFlgSwiEph: 'SEFLG_SWIEPH',
    seFlgMosEph: 'SEFLG_MOSEPH',
    seFlgHelCtr: 'SEFLG_HELCTR',
    seFlgTruePos: 'SEFLG_TRUEPOS',
    seFlgJ2000: 'SEFLG_J2000',
    seFlgNoNut: 'SEFLG_NONUT',
    seFlgSpeed3: 'SEFLG_SPEED3',
    seFlgSpeed: 'SEFLG_SPEED',
    seFlgNoGdefl: 'SEFLG_NOGDEFL',
    seFlgNoAberr: 'SEFLG_NOABERR',
    seFlgEquatorial: 'SEFLG_EQUATORIAL',
    seFlgXyz: 'SEFLG_XYZ',
    seFlgRadians: 'SEFLG_RADIANS',
    seFlgBaryCtr: 'SEFLG_BARYCTR',
    seFlgTopoCtr: 'SEFLG_TOPOCTR',
    seFlgSidereal: 'SEFLG_SIDEREAL',
    seFlgIcrs: 'SEFLG_ICRS',
    seFlgJplHor: 'SEFLG_JPLHOR',
    seFlgJplHorApprox: 'SEFLG_JPLHOR_APPROX',
    seFlgCenterBody: 'SEFLG_CENTER_BODY',
  };

  static const _sidModes = <int, String>{
    seSidmFaganBradley: 'SE_SIDM_FAGAN_BRADLEY',
    seSidmLahiri: 'SE_SIDM_LAHIRI',
    seSidmDeluce: 'SE_SIDM_DELUCE',
    seSidmRaman: 'SE_SIDM_RAMAN',
    seSidmUshashashi: 'SE_SIDM_USHASHASHI',
    seSidmKrishnamurti: 'SE_SIDM_KRISHNAMURTI',
    seSidmDjwhalKhul: 'SE_SIDM_DJWHAL_KHUL',
    seSidmYukteshwar: 'SE_SIDM_YUKTESHWAR',
    seSidmJnBhasin: 'SE_SIDM_JN_BHASIN',
    seSidmBabylKugler1: 'SE_SIDM_BABYL_KUGLER1',
    seSidmBabylKugler2: 'SE_SIDM_BABYL_KUGLER2',
    seSidmBabylKugler3: 'SE_SIDM_BABYL_KUGLER3',
    seSidmBabylHuber: 'SE_SIDM_BABYL_HUBER',
    seSidmBabylEtpsc: 'SE_SIDM_BABYL_ETPSC',
    seSidmAldebaran15tau: 'SE_SIDM_ALDEBARAN_15TAU',
    seSidmHipparchos: 'SE_SIDM_HIPPARCHOS',
    seSidmSassanian: 'SE_SIDM_SASSANIAN',
    seSidmGalcent0sag: 'SE_SIDM_GALCENT_0SAG',
    seSidmJ2000: 'SE_SIDM_J2000',
    seSidmJ1900: 'SE_SIDM_J1900',
    seSidmB1950: 'SE_SIDM_B1950',
    seSidmSuryasiddhanta: 'SE_SIDM_SURYASIDDHANTA',
    seSidmSuryasiddhantaMsun: 'SE_SIDM_SURYASIDDHANTA_MSUN',
    seSidmAryabhata: 'SE_SIDM_ARYABHATA',
    seSidmAryabhataMsun: 'SE_SIDM_ARYABHATA_MSUN',
    seSidmSsRevati: 'SE_SIDM_SS_REVATI',
    seSidmSsCitra: 'SE_SIDM_SS_CITRA',
    seSidmTrueCitra: 'SE_SIDM_TRUE_CITRA',
    seSidmTrueRevati: 'SE_SIDM_TRUE_REVATI',
    seSidmTruePushya: 'SE_SIDM_TRUE_PUSHYA',
    seSidmGalcentRgilbrand: 'SE_SIDM_GALCENT_RGILBRAND',
    seSidmGalequIau1958: 'SE_SIDM_GALEQU_IAU1958',
    seSidmGalequTrue: 'SE_SIDM_GALEQU_TRUE',
    seSidmGalequMula: 'SE_SIDM_GALEQU_MULA',
    seSidmGalalignMardyks: 'SE_SIDM_GALALIGN_MARDYKS',
    seSidmTrueMula: 'SE_SIDM_TRUE_MULA',
    seSidmGalcentMulaWilhelm: 'SE_SIDM_GALCENT_MULA_WILHELM',
    seSidmAryabhata522: 'SE_SIDM_ARYABHATA_522',
    seSidmBabylBritton: 'SE_SIDM_BABYL_BRITTON',
    seSidmTrueSheoran: 'SE_SIDM_TRUE_SHEORAN',
    seSidmGalcentCochrane: 'SE_SIDM_GALCENT_COCHRANE',
    seSidmGalequFiorenza: 'SE_SIDM_GALEQU_FIORENZA',
    seSidmValensMoon: 'SE_SIDM_VALENS_MOON',
    seSidmLahiri1940: 'SE_SIDM_LAHIRI_1940',
    seSidmLahiriVp285: 'SE_SIDM_LAHIRI_VP285',
    seSidmKrishnamurtiVp291: 'SE_SIDM_KRISHNAMURTI_VP291',
    seSidmLahiriIcrc: 'SE_SIDM_LAHIRI_ICRC',
    seSidmUser: 'SE_SIDM_USER',
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

  static String bodyName(int body) =>
      _bodies[body] ?? body.toString();

  static String sidModeName(int mode) =>
      _sidModes[mode] ?? mode.toString();

  static String houseSysName(int hsys) =>
      _houseSystems[hsys] ?? hsys.toString();

  static List<String> flagDecompose(int flags) {
    final result = <String>[];
    var remainder = flags;
    for (final entry in _flags.entries) {
      if (remainder & entry.key == entry.key) {
        result.add(entry.value);
        remainder &= ~entry.key;
      }
    }
    if (remainder != 0) {
      result.add(remainder.toString());
    }
    return result;
  }
}
