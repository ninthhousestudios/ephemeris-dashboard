import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/src/constants.dart';
import 'package:swe_dashboard/core/ephemeris/swe_symbol_catalog.dart';

void main() {
  group('bodyName (C)', () {
    test('returns C name for SE_SUN', () {
      expect(SweSymbolCatalog.bodyName(seSun, CodeTarget.c), equals('SE_SUN'));
    });

    test('returns C name for all standard bodies', () {
      expect(
        SweSymbolCatalog.bodyName(seMoon, CodeTarget.c),
        equals('SE_MOON'),
      );
      expect(
        SweSymbolCatalog.bodyName(seMercury, CodeTarget.c),
        equals('SE_MERCURY'),
      );
      expect(
        SweSymbolCatalog.bodyName(seVenus, CodeTarget.c),
        equals('SE_VENUS'),
      );
      expect(
        SweSymbolCatalog.bodyName(seMars, CodeTarget.c),
        equals('SE_MARS'),
      );
      expect(
        SweSymbolCatalog.bodyName(seJupiter, CodeTarget.c),
        equals('SE_JUPITER'),
      );
      expect(
        SweSymbolCatalog.bodyName(seSaturn, CodeTarget.c),
        equals('SE_SATURN'),
      );
      expect(
        SweSymbolCatalog.bodyName(seUranus, CodeTarget.c),
        equals('SE_URANUS'),
      );
      expect(
        SweSymbolCatalog.bodyName(seNeptune, CodeTarget.c),
        equals('SE_NEPTUNE'),
      );
      expect(
        SweSymbolCatalog.bodyName(sePluto, CodeTarget.c),
        equals('SE_PLUTO'),
      );
    });

    test('returns C name for lunar nodes and apsides', () {
      expect(
        SweSymbolCatalog.bodyName(seMeanNode, CodeTarget.c),
        equals('SE_MEAN_NODE'),
      );
      expect(
        SweSymbolCatalog.bodyName(seTrueNode, CodeTarget.c),
        equals('SE_TRUE_NODE'),
      );
      expect(
        SweSymbolCatalog.bodyName(seMeanApog, CodeTarget.c),
        equals('SE_MEAN_APOG'),
      );
      expect(
        SweSymbolCatalog.bodyName(seOscuApog, CodeTarget.c),
        equals('SE_OSCU_APOG'),
      );
      expect(
        SweSymbolCatalog.bodyName(seIntpApog, CodeTarget.c),
        equals('SE_INTP_APOG'),
      );
      expect(
        SweSymbolCatalog.bodyName(seIntpPerg, CodeTarget.c),
        equals('SE_INTP_PERG'),
      );
    });

    test('returns C name for minor bodies', () {
      expect(
        SweSymbolCatalog.bodyName(seEarth, CodeTarget.c),
        equals('SE_EARTH'),
      );
      expect(
        SweSymbolCatalog.bodyName(seChiron, CodeTarget.c),
        equals('SE_CHIRON'),
      );
      expect(
        SweSymbolCatalog.bodyName(sePholus, CodeTarget.c),
        equals('SE_PHOLUS'),
      );
      expect(
        SweSymbolCatalog.bodyName(seCeres, CodeTarget.c),
        equals('SE_CERES'),
      );
      expect(
        SweSymbolCatalog.bodyName(sePallas, CodeTarget.c),
        equals('SE_PALLAS'),
      );
      expect(
        SweSymbolCatalog.bodyName(seJuno, CodeTarget.c),
        equals('SE_JUNO'),
      );
      expect(
        SweSymbolCatalog.bodyName(seVesta, CodeTarget.c),
        equals('SE_VESTA'),
      );
    });

    test('returns C name for fictitious bodies', () {
      expect(
        SweSymbolCatalog.bodyName(seCupido, CodeTarget.c),
        equals('SE_CUPIDO'),
      );
      expect(
        SweSymbolCatalog.bodyName(seHades, CodeTarget.c),
        equals('SE_HADES'),
      );
      expect(
        SweSymbolCatalog.bodyName(seZeus, CodeTarget.c),
        equals('SE_ZEUS'),
      );
      expect(
        SweSymbolCatalog.bodyName(seKronos, CodeTarget.c),
        equals('SE_KRONOS'),
      );
      expect(
        SweSymbolCatalog.bodyName(seApollon, CodeTarget.c),
        equals('SE_APOLLON'),
      );
      expect(
        SweSymbolCatalog.bodyName(seAdmetos, CodeTarget.c),
        equals('SE_ADMETOS'),
      );
      expect(
        SweSymbolCatalog.bodyName(seVulkanus, CodeTarget.c),
        equals('SE_VULKANUS'),
      );
      expect(
        SweSymbolCatalog.bodyName(sePoseidon, CodeTarget.c),
        equals('SE_POSEIDON'),
      );
    });

    test('returns C name for SE_ECL_NUT', () {
      expect(
        SweSymbolCatalog.bodyName(seEclNut, CodeTarget.c),
        equals('SE_ECL_NUT'),
      );
    });

    test('returns integer fallback for unknown body', () {
      expect(SweSymbolCatalog.bodyName(9999, CodeTarget.c), equals('9999'));
    });
  });

  group('bodyName (Dart)', () {
    test('returns Dart name for standard bodies', () {
      expect(
        SweSymbolCatalog.bodyName(seSun, CodeTarget.dart),
        equals('seSun'),
      );
      expect(
        SweSymbolCatalog.bodyName(seMoon, CodeTarget.dart),
        equals('seMoon'),
      );
      expect(
        SweSymbolCatalog.bodyName(sePluto, CodeTarget.dart),
        equals('sePluto'),
      );
    });

    test('returns integer fallback for unknown body', () {
      expect(SweSymbolCatalog.bodyName(9999, CodeTarget.dart), equals('9999'));
    });
  });

  group('flagDecompose (C)', () {
    test('decomposes single flag', () {
      expect(
        SweSymbolCatalog.flagDecompose(seFlgSpeed, CodeTarget.c),
        equals(['SEFLG_SPEED']),
      );
    });

    test('decomposes combined flags', () {
      final flags = seFlgSwiEph | seFlgSpeed;
      final names = SweSymbolCatalog.flagDecompose(flags, CodeTarget.c);
      expect(names, containsAll(['SEFLG_SWIEPH', 'SEFLG_SPEED']));
      expect(names, hasLength(2));
    });

    test('decomposes complex flag combination', () {
      final flags = seFlgSwiEph | seFlgSpeed | seFlgTopoCtr | seFlgSidereal;
      final names = SweSymbolCatalog.flagDecompose(flags, CodeTarget.c);
      expect(
        names,
        containsAll([
          'SEFLG_SWIEPH',
          'SEFLG_SPEED',
          'SEFLG_TOPOCTR',
          'SEFLG_SIDEREAL',
        ]),
      );
      expect(names, hasLength(4));
    });

    test('returns empty list for zero', () {
      expect(SweSymbolCatalog.flagDecompose(0, CodeTarget.c), isEmpty);
    });

    test('includes integer remainder for unknown bits', () {
      final flags = seFlgSpeed | (1 << 25);
      final names = SweSymbolCatalog.flagDecompose(flags, CodeTarget.c);
      expect(names, contains('SEFLG_SPEED'));
      expect(names, contains('${1 << 25}'));
    });
  });

  group('flagDecompose (Dart)', () {
    test('decomposes single flag with Dart name', () {
      expect(
        SweSymbolCatalog.flagDecompose(seFlgSpeed, CodeTarget.dart),
        equals(['seFlgSpeed']),
      );
    });

    test('decomposes combined flags with Dart names', () {
      final flags = seFlgSwiEph | seFlgSpeed;
      final names = SweSymbolCatalog.flagDecompose(flags, CodeTarget.dart);
      expect(names, containsAll(['seFlgSwiEph', 'seFlgSpeed']));
      expect(names, hasLength(2));
    });
  });

  group('sidModeName (C)', () {
    test('returns C name for common modes', () {
      expect(
        SweSymbolCatalog.sidModeName(seSidmFaganBradley, CodeTarget.c),
        equals('SE_SIDM_FAGAN_BRADLEY'),
      );
      expect(
        SweSymbolCatalog.sidModeName(seSidmLahiri, CodeTarget.c),
        equals('SE_SIDM_LAHIRI'),
      );
      expect(
        SweSymbolCatalog.sidModeName(seSidmRaman, CodeTarget.c),
        equals('SE_SIDM_RAMAN'),
      );
      expect(
        SweSymbolCatalog.sidModeName(seSidmKrishnamurti, CodeTarget.c),
        equals('SE_SIDM_KRISHNAMURTI'),
      );
    });

    test('returns C name for all 47 modes', () {
      for (int i = 0; i <= 46; i++) {
        final name = SweSymbolCatalog.sidModeName(i, CodeTarget.c);
        expect(
          name,
          startsWith('SE_SIDM_'),
          reason: 'mode $i should have SE_SIDM_ prefix',
        );
      }
    });

    test('returns C name for SE_SIDM_USER', () {
      expect(
        SweSymbolCatalog.sidModeName(seSidmUser, CodeTarget.c),
        equals('SE_SIDM_USER'),
      );
    });

    test('returns integer fallback for unknown mode', () {
      expect(SweSymbolCatalog.sidModeName(200, CodeTarget.c), equals('200'));
    });
  });

  group('sidModeName (Dart)', () {
    test('returns Dart name for common modes', () {
      expect(
        SweSymbolCatalog.sidModeName(seSidmLahiri, CodeTarget.dart),
        equals('seSidmLahiri'),
      );
      expect(
        SweSymbolCatalog.sidModeName(seSidmFaganBradley, CodeTarget.dart),
        equals('seSidmFaganBradley'),
      );
    });

    test('returns integer fallback for unknown mode', () {
      expect(SweSymbolCatalog.sidModeName(200, CodeTarget.dart), equals('200'));
    });
  });

  group('houseSysName', () {
    test('returns display name for common house systems', () {
      expect(SweSymbolCatalog.houseSysName(hsysPlacidus), equals('Placidus'));
      expect(SweSymbolCatalog.houseSysName(hsysKoch), equals('Koch'));
      expect(
        SweSymbolCatalog.houseSysName(hsysWholeSign),
        equals('Whole Sign'),
      );
      expect(SweSymbolCatalog.houseSysName(hsysEqual), equals('Equal'));
      expect(SweSymbolCatalog.houseSysName(hsysCampanus), equals('Campanus'));
    });

    test('returns display name for all house systems', () {
      expect(SweSymbolCatalog.houseSysName(hsysPorphyry), equals('Porphyry'));
      expect(
        SweSymbolCatalog.houseSysName(hsysRegiomontanus),
        equals('Regiomontanus'),
      );
      expect(
        SweSymbolCatalog.houseSysName(hsysAlcabitius),
        equals('Alcabitius'),
      );
      expect(
        SweSymbolCatalog.houseSysName(hsysTopocentric),
        equals('Topocentric'),
      );
      expect(SweSymbolCatalog.houseSysName(hsysMeridian), equals('Meridian'));
      expect(SweSymbolCatalog.houseSysName(hsysMorinus), equals('Morinus'));
      expect(
        SweSymbolCatalog.houseSysName(hsysKrusinski),
        equals('Krusinski-Pisa'),
      );
      expect(SweSymbolCatalog.houseSysName(hsysVehlow), equals('Vehlow Equal'));
      expect(
        SweSymbolCatalog.houseSysName(hsysGauquelin),
        equals('Gauquelin Sectors'),
      );
    });

    test('returns integer fallback for unknown house system', () {
      expect(SweSymbolCatalog.houseSysName(0xFF), equals('255'));
    });
  });
}
