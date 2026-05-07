import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/src/constants.dart';
import 'package:swe_dashboard/core/ephemeris/swe_symbol_catalog.dart';

void main() {
  group('bodyName', () {
    test('returns C name for SE_SUN', () {
      expect(SweSymbolCatalog.bodyName(seSun), equals('SE_SUN'));
    });

    test('returns C name for all standard bodies', () {
      expect(SweSymbolCatalog.bodyName(seMoon), equals('SE_MOON'));
      expect(SweSymbolCatalog.bodyName(seMercury), equals('SE_MERCURY'));
      expect(SweSymbolCatalog.bodyName(seVenus), equals('SE_VENUS'));
      expect(SweSymbolCatalog.bodyName(seMars), equals('SE_MARS'));
      expect(SweSymbolCatalog.bodyName(seJupiter), equals('SE_JUPITER'));
      expect(SweSymbolCatalog.bodyName(seSaturn), equals('SE_SATURN'));
      expect(SweSymbolCatalog.bodyName(seUranus), equals('SE_URANUS'));
      expect(SweSymbolCatalog.bodyName(seNeptune), equals('SE_NEPTUNE'));
      expect(SweSymbolCatalog.bodyName(sePluto), equals('SE_PLUTO'));
    });

    test('returns C name for lunar nodes and apsides', () {
      expect(SweSymbolCatalog.bodyName(seMeanNode), equals('SE_MEAN_NODE'));
      expect(SweSymbolCatalog.bodyName(seTrueNode), equals('SE_TRUE_NODE'));
      expect(SweSymbolCatalog.bodyName(seMeanApog), equals('SE_MEAN_APOG'));
      expect(SweSymbolCatalog.bodyName(seOscuApog), equals('SE_OSCU_APOG'));
      expect(SweSymbolCatalog.bodyName(seIntpApog), equals('SE_INTP_APOG'));
      expect(SweSymbolCatalog.bodyName(seIntpPerg), equals('SE_INTP_PERG'));
    });

    test('returns C name for minor bodies', () {
      expect(SweSymbolCatalog.bodyName(seEarth), equals('SE_EARTH'));
      expect(SweSymbolCatalog.bodyName(seChiron), equals('SE_CHIRON'));
      expect(SweSymbolCatalog.bodyName(sePholus), equals('SE_PHOLUS'));
      expect(SweSymbolCatalog.bodyName(seCeres), equals('SE_CERES'));
      expect(SweSymbolCatalog.bodyName(sePallas), equals('SE_PALLAS'));
      expect(SweSymbolCatalog.bodyName(seJuno), equals('SE_JUNO'));
      expect(SweSymbolCatalog.bodyName(seVesta), equals('SE_VESTA'));
    });

    test('returns C name for fictitious bodies', () {
      expect(SweSymbolCatalog.bodyName(seCupido), equals('SE_CUPIDO'));
      expect(SweSymbolCatalog.bodyName(seHades), equals('SE_HADES'));
      expect(SweSymbolCatalog.bodyName(seZeus), equals('SE_ZEUS'));
      expect(SweSymbolCatalog.bodyName(seKronos), equals('SE_KRONOS'));
      expect(SweSymbolCatalog.bodyName(seApollon), equals('SE_APOLLON'));
      expect(SweSymbolCatalog.bodyName(seAdmetos), equals('SE_ADMETOS'));
      expect(SweSymbolCatalog.bodyName(seVulkanus), equals('SE_VULKANUS'));
      expect(SweSymbolCatalog.bodyName(sePoseidon), equals('SE_POSEIDON'));
    });

    test('returns C name for SE_ECL_NUT', () {
      expect(SweSymbolCatalog.bodyName(seEclNut), equals('SE_ECL_NUT'));
    });

    test('returns integer fallback for unknown body', () {
      expect(SweSymbolCatalog.bodyName(9999), equals('9999'));
    });
  });

  group('flagDecompose', () {
    test('decomposes single flag', () {
      expect(SweSymbolCatalog.flagDecompose(seFlgSpeed), equals(['SEFLG_SPEED']));
    });

    test('decomposes combined flags', () {
      final flags = seFlgSwiEph | seFlgSpeed;
      final names = SweSymbolCatalog.flagDecompose(flags);
      expect(names, containsAll(['SEFLG_SWIEPH', 'SEFLG_SPEED']));
      expect(names, hasLength(2));
    });

    test('decomposes complex flag combination', () {
      final flags = seFlgSwiEph | seFlgSpeed | seFlgTopoCtr | seFlgSidereal;
      final names = SweSymbolCatalog.flagDecompose(flags);
      expect(names, containsAll([
        'SEFLG_SWIEPH',
        'SEFLG_SPEED',
        'SEFLG_TOPOCTR',
        'SEFLG_SIDEREAL',
      ]));
      expect(names, hasLength(4));
    });

    test('returns empty list for zero', () {
      expect(SweSymbolCatalog.flagDecompose(0), isEmpty);
    });

    test('includes integer remainder for unknown bits', () {
      final flags = seFlgSpeed | (1 << 25);
      final names = SweSymbolCatalog.flagDecompose(flags);
      expect(names, contains('SEFLG_SPEED'));
      expect(names, contains('${1 << 25}'));
    });
  });

  group('sidModeName', () {
    test('returns C name for common modes', () {
      expect(SweSymbolCatalog.sidModeName(seSidmFaganBradley), equals('SE_SIDM_FAGAN_BRADLEY'));
      expect(SweSymbolCatalog.sidModeName(seSidmLahiri), equals('SE_SIDM_LAHIRI'));
      expect(SweSymbolCatalog.sidModeName(seSidmRaman), equals('SE_SIDM_RAMAN'));
      expect(SweSymbolCatalog.sidModeName(seSidmKrishnamurti), equals('SE_SIDM_KRISHNAMURTI'));
    });

    test('returns C name for all 47 modes', () {
      for (int i = 0; i <= 46; i++) {
        final name = SweSymbolCatalog.sidModeName(i);
        expect(name, startsWith('SE_SIDM_'), reason: 'mode $i should have SE_SIDM_ prefix');
      }
    });

    test('returns C name for SE_SIDM_USER', () {
      expect(SweSymbolCatalog.sidModeName(seSidmUser), equals('SE_SIDM_USER'));
    });

    test('returns integer fallback for unknown mode', () {
      expect(SweSymbolCatalog.sidModeName(200), equals('200'));
    });
  });

  group('houseSysName', () {
    test('returns display name for common house systems', () {
      expect(SweSymbolCatalog.houseSysName(hsysPlacidus), equals('Placidus'));
      expect(SweSymbolCatalog.houseSysName(hsysKoch), equals('Koch'));
      expect(SweSymbolCatalog.houseSysName(hsysWholeSign), equals('Whole Sign'));
      expect(SweSymbolCatalog.houseSysName(hsysEqual), equals('Equal'));
      expect(SweSymbolCatalog.houseSysName(hsysCampanus), equals('Campanus'));
    });

    test('returns display name for all house systems', () {
      expect(SweSymbolCatalog.houseSysName(hsysPorphyry), equals('Porphyry'));
      expect(SweSymbolCatalog.houseSysName(hsysRegiomontanus), equals('Regiomontanus'));
      expect(SweSymbolCatalog.houseSysName(hsysAlcabitius), equals('Alcabitius'));
      expect(SweSymbolCatalog.houseSysName(hsysTopocentric), equals('Topocentric'));
      expect(SweSymbolCatalog.houseSysName(hsysMeridian), equals('Meridian'));
      expect(SweSymbolCatalog.houseSysName(hsysMorinus), equals('Morinus'));
      expect(SweSymbolCatalog.houseSysName(hsysKrusinski), equals('Krusinski-Pisa'));
      expect(SweSymbolCatalog.houseSysName(hsysVehlow), equals('Vehlow Equal'));
      expect(SweSymbolCatalog.houseSysName(hsysGauquelin), equals('Gauquelin Sectors'));
    });

    test('returns integer fallback for unknown house system', () {
      expect(SweSymbolCatalog.houseSysName(0xFF), equals('255'));
    });
  });
}
