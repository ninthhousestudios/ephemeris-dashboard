// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph/swisseph.dart' as swe;
import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

import 'src/agreement.dart';
import 'src/oracle.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Compare cusps[1..n] between engine and oracle (index 0 unused).
void _compareCusps(
  List<double> actual,
  List<double> expected,
  String label,
  AgreementClass cls, {
  int start = 1,
  int? end,
}) {
  final n = end ?? (actual.length - 1);
  for (var i = start; i <= n; i++) {
    expectAgreement('$label[$i]', actual[i], expected[i], cls);
  }
}

/// Compare AscMc fields against oracle ascmc array.
void _compareAscMc(
  AscMc actual,
  List<double> expected,
  String label,
  AgreementClass cls,
) {
  expectAgreement('$label.ascendant', actual.ascendant, expected[0], cls);
  expectAgreement('$label.mc', actual.mc, expected[1], cls);
  expectAgreement('$label.armc', actual.armc, expected[2], cls);
  expectAgreement('$label.vertex', actual.vertex, expected[3], cls);
  expectAgreement(
    '$label.equatorialAscendant',
    actual.equatorialAscendant,
    expected[4],
    cls,
  );
  expectAgreement(
    '$label.coascendantKoch',
    actual.coascendantKoch,
    expected[5],
    cls,
  );
  expectAgreement(
    '$label.coascendantMunkasey',
    actual.coascendantMunkasey,
    expected[6],
    cls,
  );
  expectAgreement(
    '$label.polarAscendant',
    actual.polarAscendant,
    expected[7],
    cls,
  );
}

void main() {
  late Ephemeris eph;
  late Oracle oracle;

  // Berlin: 52.52°N, 13.41°E
  const berlinLat = 52.52;
  const berlinLon = 13.41;

  // Polar: 67°N, 25°E (northern Finland)
  const polarLat = 67.0;
  const polarLon = 25.0;

  // J2000 epoch as JD UT
  const j2000Ut = JdUt1(2451545.0);

  setUpAll(() {
    eph = Ephemeris(const EphemerisConfig());
    oracle = Oracle();
  });

  tearDownAll(() {
    eph.close();
    oracle.close();
  });

  // -----------------------------------------------------------------------
  // Houses: Ephemeris.houses (= housesEx2 with no flags)
  // -----------------------------------------------------------------------

  group('houses', () {
    for (final hsys in HouseSystem.values) {
      test('${hsys.name} at Berlin', () {
        final actual = eph.houses(j2000Ut, berlinLat, berlinLon, hsys);
        final expected = oracle.houses(
          j2000Ut.value,
          berlinLat,
          berlinLon,
          hsys.charCode,
        );
        _compareCusps(
          actual.cusps,
          expected.cusps,
          'cusps',
          AgreementClass.positional,
        );
        _compareAscMc(
          actual.ascmc,
          expected.ascmc,
          'ascmc',
          AgreementClass.positional,
        );
      });
    }

    // Systems that work at all latitudes (no MC/ASC trisection).
    const polarSafe = {
      HouseSystem.wholeSign,
      HouseSystem.equal,
      HouseSystem.equalMC,
      HouseSystem.equalAries,
      HouseSystem.morinus,
      HouseSystem.vehlow,
      HouseSystem.meridian,
      HouseSystem.apc,
      HouseSystem.porphyry,
    };

    for (final hsys in polarSafe) {
      test('${hsys.name} at polar latitude', () {
        final actual = eph.houses(j2000Ut, polarLat, polarLon, hsys);
        final expected = oracle.houses(
          j2000Ut.value,
          polarLat,
          polarLon,
          hsys.charCode,
        );
        _compareCusps(
          actual.cusps,
          expected.cusps,
          'cusps',
          AgreementClass.positional,
        );
        _compareAscMc(
          actual.ascmc,
          expected.ascmc,
          'ascmc',
          AgreementClass.positional,
        );
      });
    }

    // Systems that fall back to Porphyry at polar latitudes. The oracle
    // (swisseph.dart) may throw on the fallback (return code -1). Verify
    // the engine either succeeds or throws a typed exception — never
    // returns garbage.
    final polarProblematic = HouseSystem.values
        .where((h) => !polarSafe.contains(h))
        .toList();

    for (final hsys in polarProblematic) {
      test('${hsys.name} at polar latitude (no crash)', () {
        try {
          final actual = eph.houses(j2000Ut, polarLat, polarLon, hsys);
          // Engine succeeded (Porphyry fallback) — cusps should be finite.
          for (var i = 1; i < actual.cusps.length; i++) {
            expect(
              actual.cusps[i].isFinite,
              isTrue,
              reason: 'cusp[$i] should be finite',
            );
          }
        } on SweException {
          // Typed exception is acceptable for documented polar failures.
        }
      });
    }
  });

  // -----------------------------------------------------------------------
  // Houses: Ephemeris.housesEx2 (with flags)
  // -----------------------------------------------------------------------

  group('housesEx2', () {
    test('Placidus with SPEED flag at Berlin', () {
      final actual = eph.housesEx2(
        j2000Ut,
        CalcFlags.speed,
        berlinLat,
        berlinLon,
        HouseSystem.placidus,
      );
      final expected = oracle.housesEx2(
        j2000Ut.value,
        swe.seFlgSpeed,
        berlinLat,
        berlinLon,
        HouseSystem.placidus.charCode,
      );
      _compareCusps(
        actual.cusps,
        expected.cusps,
        'cusps',
        AgreementClass.positional,
      );
      _compareCusps(
        actual.cuspSpeeds,
        expected.cuspSpeeds,
        'cuspSpeeds',
        AgreementClass.positional,
      );
      _compareAscMc(
        actual.ascmc,
        expected.ascmc,
        'ascmc',
        AgreementClass.positional,
      );
      _compareAscMc(
        actual.ascmcSpeeds,
        expected.ascmcSpeeds,
        'ascmcSpeeds',
        AgreementClass.positional,
      );
    });
  });

  // -----------------------------------------------------------------------
  // housesArmc (free function, handle-free)
  // -----------------------------------------------------------------------

  group('housesArmc', () {
    test('Placidus from ARMC', () {
      // First compute houses to get a known ARMC value
      final ref = eph.houses(
        j2000Ut,
        berlinLat,
        berlinLon,
        HouseSystem.placidus,
      );
      final armc = ref.ascmc.armc;
      // Use a typical obliquity (~23.44°)
      const eps = 23.4392911;

      final actual = housesArmc(armc, berlinLat, eps, HouseSystem.placidus);
      final expected = oracle.housesArmc(
        armc,
        berlinLat,
        eps,
        HouseSystem.placidus.charCode,
      );
      _compareCusps(
        actual.cusps,
        expected.cusps,
        'cusps',
        AgreementClass.positional,
      );
      _compareAscMc(
        actual.ascmc,
        expected.ascmc,
        'ascmc',
        AgreementClass.positional,
      );
    });
  });

  // -----------------------------------------------------------------------
  // housePos (free function, handle-free — inverse problem)
  // -----------------------------------------------------------------------

  group('housePos', () {
    test('round-trip: known body position returns expected house', () {
      final ref = eph.houses(
        j2000Ut,
        berlinLat,
        berlinLon,
        HouseSystem.placidus,
      );
      final armc = ref.ascmc.armc;
      const eps = 23.4392911;

      // Use MC longitude — should land near house position 10.0
      final bodyLon = ref.ascmc.mc;
      const bodyLat = 0.0;

      final actual = housePos(
        armc,
        berlinLat,
        eps,
        HouseSystem.placidus,
        bodyLon,
        bodyLat,
      );
      final expected = oracle.housePos(
        armc,
        berlinLat,
        eps,
        HouseSystem.placidus.charCode,
        bodyLon,
        bodyLat,
      );
      expectAgreement('housePos', actual, expected, AgreementClass.positional);
    });
  });

  // -----------------------------------------------------------------------
  // houseName (free function)
  // -----------------------------------------------------------------------

  group('houseName', () {
    test('Placidus', () {
      final actual = houseName(HouseSystem.placidus);
      final expected = oracle.houseName(HouseSystem.placidus.charCode);
      expect(actual, equals(expected));
    });

    test('Koch', () {
      final actual = houseName(HouseSystem.koch);
      final expected = oracle.houseName(HouseSystem.koch.charCode);
      expect(actual, equals(expected));
    });

    test('Whole Sign', () {
      final actual = houseName(HouseSystem.wholeSign);
      final expected = oracle.houseName(HouseSystem.wholeSign.charCode);
      expect(actual, equals(expected));
    });
  });

  // -----------------------------------------------------------------------
  // Ayanamsa: getAyanamsaEx (composite — needs sidereal config)
  // -----------------------------------------------------------------------

  group('getAyanamsaEx', () {
    test('Lahiri at J2000 (Moshier)', () {
      final sidEph = Ephemeris(
        const EphemerisConfig(siderealMode: SiderealMode.lahiri),
      );
      try {
        const jd = JdTt(2451545.0);
        final actual = sidEph.getAyanamsaEx(jd, CalcFlags.none);
        final expected = oracle.getAyanamsaEx(jd.value, 0, swe.seSidmLahiri);
        expectAgreement(
          'ayanamsa',
          actual.ayanamsa,
          expected,
          AgreementClass.positional,
        );
      } finally {
        sidEph.close();
      }
    });

    test('FaganBradley at arbitrary date (Moshier)', () {
      final sidEph = Ephemeris(
        const EphemerisConfig(siderealMode: SiderealMode.faganBradley),
      );
      try {
        const jd = JdTt(2460000.5);
        final actual = sidEph.getAyanamsaEx(jd, CalcFlags.none);
        final expected = oracle.getAyanamsaEx(
          jd.value,
          0,
          swe.seSidmFaganBradley,
        );
        expectAgreement(
          'ayanamsa',
          actual.ayanamsa,
          expected,
          AgreementClass.positional,
        );
      } finally {
        sidEph.close();
      }
    });
  });

  // -----------------------------------------------------------------------
  // Ayanamsa: getAyanamsaExWithConfig (per-call sidereal override)
  // -----------------------------------------------------------------------

  group('getAyanamsaExWithConfig', () {
    test('user-defined sidereal mode', () {
      const jd = JdTt(2451545.0);
      const config = EphemerisConfig(siderealMode: SiderealMode.lahiri);
      final actual = eph.getAyanamsaExWithConfig(jd, CalcFlags.none, config);
      final expected = oracle.getAyanamsaEx(jd.value, 0, swe.seSidmLahiri);
      expectAgreement(
        'ayanamsa',
        actual.ayanamsa,
        expected,
        AgreementClass.positional,
      );
    });
  });

  // -----------------------------------------------------------------------
  // Ayanamsa: getAyanamsaUt
  // -----------------------------------------------------------------------

  group('getAyanamsaUt', () {
    test('Lahiri at J2000 UT (Moshier)', () {
      final sidEph = Ephemeris(
        const EphemerisConfig(siderealMode: SiderealMode.lahiri),
      );
      try {
        final actual = sidEph.getAyanamsaUt(j2000Ut, CalcFlags.none);
        final expected = oracle.getAyanamsaUt(
          j2000Ut.value,
          0,
          swe.seSidmLahiri,
        );
        expectAgreement(
          'ayanamsa',
          actual.ayanamsa,
          expected,
          AgreementClass.positional,
        );
      } finally {
        sidEph.close();
      }
    });
  });

  // -----------------------------------------------------------------------
  // Ayanamsa: getAyanamsa (legacy, no flags)
  // -----------------------------------------------------------------------

  group('getAyanamsa', () {
    test('Lahiri at J2000 (Moshier)', () {
      final sidEph = Ephemeris(
        const EphemerisConfig(siderealMode: SiderealMode.lahiri),
      );
      try {
        const jd = JdTt(2451545.0);
        final actual = sidEph.getAyanamsa(jd);
        final expected = oracle.getAyanamsa(jd.value, swe.seSidmLahiri);
        expectAgreement(
          'ayanamsa',
          actual,
          expected,
          AgreementClass.positional,
        );
      } finally {
        sidEph.close();
      }
    });
  });

  // -----------------------------------------------------------------------
  // getAyanamsaName (free function)
  // -----------------------------------------------------------------------

  group('getAyanamsaName', () {
    test('Lahiri', () {
      final actual = getAyanamsaName(SiderealMode.lahiri);
      final expected = oracle.getAyanamsaName(swe.seSidmLahiri);
      expect(actual, equals(expected));
    });

    test('FaganBradley', () {
      final actual = getAyanamsaName(SiderealMode.faganBradley);
      final expected = oracle.getAyanamsaName(swe.seSidmFaganBradley);
      expect(actual, equals(expected));
    });
  });

  // -----------------------------------------------------------------------
  // Gauquelin sector
  // -----------------------------------------------------------------------

  group('gauquelinSector', () {
    test('Sun geometric sector (method=0) at Berlin', () {
      final actual = eph.gauquelinSector(
        j2000Ut,
        Body.sun,
        CalcFlags.none,
        0, // geometric (rise/set)
        berlinLon,
        berlinLat,
        0, // altitude
      );
      final expected = oracle.gauquelinSector(
        j2000Ut.value,
        swe.seSun,
        0,
        0,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      expectAgreement(
        'gauquelinSector',
        actual,
        expected,
        AgreementClass.positional,
      );
    });
  });

  group('gauquelinSectorGeometric', () {
    test('Sun geometric (method=0) at Berlin', () {
      final actual = eph.gauquelinSectorGeometric(
        j2000Ut,
        Body.sun,
        CalcFlags.none,
        0,
        berlinLon,
        berlinLat,
      );
      final expected = oracle.gauquelinSector(
        j2000Ut.value,
        swe.seSun,
        0,
        0,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      expectAgreement(
        'gauquelinSectorGeometric',
        actual,
        expected,
        AgreementClass.positional,
      );
    });

    test('Sun geometric (method=1, no ecliptic lat) at Berlin', () {
      final actual = eph.gauquelinSectorGeometric(
        j2000Ut,
        Body.sun,
        CalcFlags.none,
        1,
        berlinLon,
        berlinLat,
      );
      final expected = oracle.gauquelinSector(
        j2000Ut.value,
        swe.seSun,
        0,
        1,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      expectAgreement(
        'gauquelinSectorGeometric',
        actual,
        expected,
        AgreementClass.positional,
      );
    });
  });
}
