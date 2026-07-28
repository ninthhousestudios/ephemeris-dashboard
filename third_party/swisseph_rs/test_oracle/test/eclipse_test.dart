// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io' show Platform;

import 'package:swisseph/swisseph.dart' as swe;
import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

import 'src/agreement.dart';
import 'src/oracle.dart';

// Search-class tolerance for iterative eclipse event-finding (~0.09 s).
const _searchTolerance = 1e-6;

void main() {
  late Ephemeris eph;
  late Oracle oracle;

  // J2000 epoch as JD UT — search start for finding eclipses.
  const j2000Ut = JdUt1(2451545.0);

  // Berlin: 52.52N, 13.41E
  const berlinLat = 52.52;
  const berlinLon = 13.41;

  setUpAll(() {
    eph = Ephemeris(const EphemerisConfig());
    oracle = Oracle();
  });

  tearDownAll(() {
    eph.close();
    oracle.close();
  });

  // -----------------------------------------------------------------------
  // Solar eclipses (task /30)
  // -----------------------------------------------------------------------

  group('solEclipseWhenGlob', () {
    test('forward search — all time fields', () {
      final actual = eph.solEclipseWhenGlob(j2000Ut, CalcFlags.none);
      final expected = oracle.solEclipseWhenGlob(j2000Ut.value, 0);

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeRaConjunction',
        actual.timeRaConjunction,
        expected.localNoon,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeBegin',
        actual.timeBegin,
        expected.begin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeEnd',
        actual.timeEnd,
        expected.end,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeTotalityBegin',
        actual.timeTotalityBegin,
        expected.totalityBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeTotalityEnd',
        actual.timeTotalityEnd,
        expected.totalityEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeCenterlineBegin',
        actual.timeCenterlineBegin,
        expected.centerLineBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeCenterlineEnd',
        actual.timeCenterlineEnd,
        expected.centerLineEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('backward search', () {
      final actual = eph.solEclipseWhenGlob(
        j2000Ut,
        CalcFlags.none,
        backward: true,
      );
      final expected = oracle.solEclipseWhenGlob(
        j2000Ut.value,
        0,
        backward: true,
      );

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('filtered by total — exact flags match', () {
      final actual = eph.solEclipseWhenGlob(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.total,
      );
      final expected = oracle.solEclipseWhenGlob(
        j2000Ut.value,
        0,
        eclType: swe.seEclTotal,
      );

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.contains(EclipseFlags.total), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });
  });

  group('solEclipseWhenLoc', () {
    test('forward search — all time and attr fields', () {
      final actual = eph.solEclipseWhenLoc(
        j2000Ut,
        CalcFlags.none,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      final expected = oracle.solEclipseWhenLoc(
        j2000Ut.value,
        0,
        geolon: berlinLon,
        geolat: berlinLat,
      );

      // All tret[] time fields.
      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeFirstContact',
        actual.timeFirstContact,
        expected.firstContact,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeSecondContact',
        actual.timeSecondContact,
        expected.secondContact,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeThirdContact',
        actual.timeThirdContact,
        expected.thirdContact,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeFourthContact',
        actual.timeFourthContact,
        expected.fourthContact,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeSunrise',
        actual.timeSunrise,
        expected.sunrise,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeSunset',
        actual.timeSunset,
        expected.sunset,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));

      // All embedded EclipseHow attr[] fields.
      expectAgreement(
        'attr.magnitude',
        actual.attr.magnitude,
        expected.magnitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.diameterRatio',
        actual.attr.diameterRatio,
        expected.diameterRatio,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.obscuration',
        actual.attr.obscuration,
        expected.obscuration,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.coreDiameterKm',
        actual.attr.coreDiameterKm,
        expected.coreShadowKm,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.azimuth',
        actual.attr.azimuth,
        expected.sunAzimuth,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.trueAltitude',
        actual.attr.trueAltitude,
        expected.sunTrueAltitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.apparentAltitude',
        actual.attr.apparentAltitude,
        expected.sunApparentAltitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.elongation',
        actual.attr.elongation,
        expected.moonSunAngle,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.nasaMagnitude',
        actual.attr.nasaMagnitude,
        expected.magnitudeNasa,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.sarosSeries',
        actual.attr.sarosSeries,
        expected.sarosSeries,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.sarosMember',
        actual.attr.sarosMember,
        expected.sarosMember,
        AgreementClass.positional,
      );
    });
  });

  group('solEclipseWhere', () {
    test('geography and geometry at time of global eclipse', () {
      final glob = eph.solEclipseWhenGlob(j2000Ut, CalcFlags.none);
      final actual = eph.solEclipseWhere(
        JdUt1(glob.timeMaximum),
        CalcFlags.none,
      );
      final expected = oracle.solEclipseWhere(glob.timeMaximum, 0);

      // geopos[0..1] — oracle exposes these.
      expectAgreement(
        'centralLongitude',
        actual.centralLongitude,
        expected.geolon,
        AgreementClass.positional,
      );
      expectAgreement(
        'centralLatitude',
        actual.centralLatitude,
        expected.geolat,
        AgreementClass.positional,
      );
      expect(actual.flags.value, equals(expected.returnFlag));

      // geopos[2..8] — oracle doesn't expose; verify finite + self-consistent.
      expect(actual.coreDiameterKm.isFinite, isTrue);
      expect(actual.penumbraDiameterKm.isFinite, isTrue);
      expect(actual.shadowAxisDistanceKm.isFinite, isTrue);
      expect(actual.umbraDiameterFundamentalKm.isFinite, isTrue);
      expect(actual.penumbraDiameterFundamentalKm.isFinite, isTrue);
      expect(actual.cosUmbraHalfAngle.isFinite, isTrue);
      expect(actual.cosPenumbraHalfAngle.isFinite, isTrue);
      // Penumbra always wider than umbra in fundamental plane.
      expect(
        actual.penumbraDiameterFundamentalKm.abs(),
        greaterThanOrEqualTo(actual.umbraDiameterFundamentalKm.abs()),
      );
    });
  });

  group('solEclipseHow', () {
    test('all attr fields at eclipse location and time', () {
      final glob = eph.solEclipseWhenGlob(j2000Ut, CalcFlags.none);
      final where = eph.solEclipseWhere(
        JdUt1(glob.timeMaximum),
        CalcFlags.none,
      );

      final actual = eph.solEclipseHow(
        JdUt1(glob.timeMaximum),
        CalcFlags.none,
        geolon: where.centralLongitude,
        geolat: where.centralLatitude,
      );
      final expected = oracle.solEclipseHow(
        glob.timeMaximum,
        0,
        geolon: where.centralLongitude,
        geolat: where.centralLatitude,
      );

      expectAgreement(
        'magnitude',
        actual.magnitude,
        expected.magnitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'diameterRatio',
        actual.diameterRatio,
        expected.diameterRatio,
        AgreementClass.positional,
      );
      expectAgreement(
        'obscuration',
        actual.obscuration,
        expected.obscuration,
        AgreementClass.positional,
      );
      expectAgreement(
        'coreDiameterKm',
        actual.coreDiameterKm,
        expected.coreShadowKm,
        AgreementClass.positional,
      );
      expectAgreement(
        'azimuth',
        actual.azimuth,
        expected.sunAzimuth,
        AgreementClass.positional,
      );
      expectAgreement(
        'trueAltitude',
        actual.trueAltitude,
        expected.sunTrueAltitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'apparentAltitude',
        actual.apparentAltitude,
        expected.sunApparentAltitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'elongation',
        actual.elongation,
        expected.moonSunAngle,
        AgreementClass.positional,
      );
      expectAgreement(
        'nasaMagnitude',
        actual.nasaMagnitude,
        expected.magnitudeNasa,
        AgreementClass.positional,
      );
      expectAgreement(
        'sarosSeries',
        actual.sarosSeries,
        expected.sarosSeries,
        AgreementClass.positional,
      );
      expectAgreement(
        'sarosMember',
        actual.sarosMember,
        expected.sarosMember,
        AgreementClass.positional,
      );
      expect(actual.flags.value, equals(expected.returnFlag));
    });
  });

  // -----------------------------------------------------------------------
  // Lunar eclipses (task /31)
  // -----------------------------------------------------------------------

  group('lunEclipseWhen', () {
    test('forward search — all time fields', () {
      final actual = eph.lunEclipseWhen(j2000Ut, CalcFlags.none);
      final expected = oracle.lunEclipseWhen(j2000Ut.value, 0);

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timePartialBegin',
        actual.timePartialBegin,
        expected.partialBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timePartialEnd',
        actual.timePartialEnd,
        expected.partialEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeTotalityBegin',
        actual.timeTotalityBegin,
        expected.totalityBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeTotalityEnd',
        actual.timeTotalityEnd,
        expected.totalityEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timePenumbralBegin',
        actual.timePenumbralBegin,
        expected.penumbralBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timePenumbralEnd',
        actual.timePenumbralEnd,
        expected.penumbralEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('backward search', () {
      final actual = eph.lunEclipseWhen(
        j2000Ut,
        CalcFlags.none,
        backward: true,
      );
      final expected = oracle.lunEclipseWhen(j2000Ut.value, 0, backward: true);

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('filtered by total — exact flags', () {
      final actual = eph.lunEclipseWhen(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.total,
      );
      final expected = oracle.lunEclipseWhen(
        j2000Ut.value,
        0,
        eclType: swe.seEclTotal,
      );

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.contains(EclipseFlags.total), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('filtered by penumbral — exact flags', () {
      final actual = eph.lunEclipseWhen(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.penumbral,
      );
      final expected = oracle.lunEclipseWhen(
        j2000Ut.value,
        0,
        eclType: swe.seEclPenumbral,
      );

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.contains(EclipseFlags.penumbral), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });
  });

  group('lunEclipseWhenLoc', () {
    test('forward search — all time and attr fields', () {
      final actual = eph.lunEclipseWhenLoc(
        j2000Ut,
        CalcFlags.none,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      final expected = oracle.lunEclipseWhenLoc(
        j2000Ut.value,
        0,
        geolon: berlinLon,
        geolat: berlinLat,
      );

      // All tret[] time fields.
      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timePartialBegin',
        actual.timePartialBegin,
        expected.partialBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timePartialEnd',
        actual.timePartialEnd,
        expected.partialEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeTotalityBegin',
        actual.timeTotalityBegin,
        expected.totalityBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeTotalityEnd',
        actual.timeTotalityEnd,
        expected.totalityEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timePenumbralBegin',
        actual.timePenumbralBegin,
        expected.penumbralBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timePenumbralEnd',
        actual.timePenumbralEnd,
        expected.penumbralEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeMoonrise',
        actual.timeMoonrise,
        expected.moonrise,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeMoonset',
        actual.timeMoonset,
        expected.moonset,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));

      // Embedded LunarEclipseHow attr[] fields.
      expectAgreement(
        'attr.umbralMagnitude',
        actual.attr.umbralMagnitude,
        expected.umbralMagnitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.penumbralMagnitude',
        actual.attr.penumbralMagnitude,
        expected.penumbralMagnitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.azimuth',
        actual.attr.azimuth,
        expected.moonAzimuth,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.trueAltitude',
        actual.attr.trueAltitude,
        expected.moonTrueAltitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.apparentAltitude',
        actual.attr.apparentAltitude,
        expected.moonApparentAltitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.distanceFromOpposition',
        actual.attr.distanceFromOpposition,
        expected.moonOppositionAngle,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.sarosSeries',
        actual.attr.sarosSeries,
        expected.sarosSeries,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.sarosMember',
        actual.attr.sarosMember,
        expected.sarosMember,
        AgreementClass.positional,
      );
    });
  });

  group('lunEclipseHow', () {
    test('all attr fields at eclipse time and location', () {
      final glob = eph.lunEclipseWhen(j2000Ut, CalcFlags.none);

      final actual = eph.lunEclipseHow(
        JdUt1(glob.timeMaximum),
        CalcFlags.none,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      final expected = oracle.lunEclipseHow(
        glob.timeMaximum,
        0,
        geolon: berlinLon,
        geolat: berlinLat,
      );

      expectAgreement(
        'umbralMagnitude',
        actual.umbralMagnitude,
        expected.umbralMagnitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'penumbralMagnitude',
        actual.penumbralMagnitude,
        expected.penumbralMagnitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'azimuth',
        actual.azimuth,
        expected.moonAzimuth,
        AgreementClass.positional,
      );
      expectAgreement(
        'trueAltitude',
        actual.trueAltitude,
        expected.moonTrueAltitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'apparentAltitude',
        actual.apparentAltitude,
        expected.moonApparentAltitude,
        AgreementClass.positional,
      );
      expectAgreement(
        'distanceFromOpposition',
        actual.distanceFromOpposition,
        expected.moonOppositionAngle,
        AgreementClass.positional,
      );
      expectAgreement(
        'sarosSeries',
        actual.sarosSeries,
        expected.sarosSeries,
        AgreementClass.positional,
      );
      expectAgreement(
        'sarosMember',
        actual.sarosMember,
        expected.sarosMember,
        AgreementClass.positional,
      );
      expect(actual.flags.value, equals(expected.returnFlag));
    });
  });

  // -----------------------------------------------------------------------
  // Occultations (task /31)
  // -----------------------------------------------------------------------

  group('lunOccultWhenGlob', () {
    test('Venus forward search — all time fields', () {
      final actual = eph.lunOccultWhenGlob(j2000Ut, Body.venus, CalcFlags.none);
      final expected = oracle.lunOccultWhenGlob(
        j2000Ut.value,
        Body.venus.rawValue,
        0,
      );

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeRaConjunction',
        actual.timeRaConjunction,
        expected.localNoon,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeBegin',
        actual.timeBegin,
        expected.begin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeEnd',
        actual.timeEnd,
        expected.end,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeTotalityBegin',
        actual.timeTotalityBegin,
        expected.totalityBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeTotalityEnd',
        actual.timeTotalityEnd,
        expected.totalityEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeCenterlineBegin',
        actual.timeCenterlineBegin,
        expected.centerLineBegin,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeCenterlineEnd',
        actual.timeCenterlineEnd,
        expected.centerLineEnd,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('backward search', () {
      final actual = eph.lunOccultWhenGlob(
        j2000Ut,
        Body.venus,
        CalcFlags.none,
        backward: true,
      );
      final expected = oracle.lunOccultWhenGlob(
        j2000Ut.value,
        Body.venus.rawValue,
        0,
        backward: true,
      );

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));
    });
  });

  group('lunOccultWhenLoc', () {
    test('Venus occultation — all time and attr fields', () {
      final actual = eph.lunOccultWhenLoc(
        j2000Ut,
        Body.venus,
        CalcFlags.none,
        geolon: berlinLon,
        geolat: berlinLat,
      );
      final expected = oracle.lunOccultWhenLoc(
        j2000Ut.value,
        Body.venus.rawValue,
        0,
        geolon: berlinLon,
        geolat: berlinLat,
      );

      // All tret[] time fields.
      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeFirstContact',
        actual.timeFirstContact,
        expected.firstContact,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeSecondContact',
        actual.timeSecondContact,
        expected.secondContact,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeThirdContact',
        actual.timeThirdContact,
        expected.thirdContact,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expectAgreement(
        'timeFourthContact',
        actual.timeFourthContact,
        expected.fourthContact,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));

      // Occultation attr values are computed at the search-found event time;
      // search-class time uncertainty propagates into all geometry fields.
      const occAttrCls = AgreementClass.boundary;
      const occAttrTol = 1e-6;
      const occAttrArt = 'search-derived occultation geometry';
      expectAgreement(
        'attr.magnitude',
        actual.attr.magnitude,
        expected.magnitude,
        occAttrCls,
        tolerance: occAttrTol,
        boundaryArtifact: occAttrArt,
      );
      expectAgreement(
        'attr.diameterRatio',
        actual.attr.diameterRatio,
        expected.diameterRatio,
        occAttrCls,
        tolerance: occAttrTol,
        boundaryArtifact: occAttrArt,
      );
      expectAgreement(
        'attr.obscuration',
        actual.attr.obscuration,
        expected.obscuration,
        occAttrCls,
        tolerance: occAttrTol,
        boundaryArtifact: occAttrArt,
      );
      expectAgreement(
        'attr.azimuth',
        actual.attr.azimuth,
        expected.sunAzimuth,
        occAttrCls,
        tolerance: occAttrTol,
        boundaryArtifact: occAttrArt,
      );
      expectAgreement(
        'attr.trueAltitude',
        actual.attr.trueAltitude,
        expected.sunTrueAltitude,
        occAttrCls,
        tolerance: occAttrTol,
        boundaryArtifact: occAttrArt,
      );
      expectAgreement(
        'attr.sarosSeries',
        actual.attr.sarosSeries,
        expected.sarosSeries,
        AgreementClass.positional,
      );
      expectAgreement(
        'attr.sarosMember',
        actual.attr.sarosMember,
        expected.sarosMember,
        AgreementClass.positional,
      );
    });
  });

  group('lunOccultWhere', () {
    test('geography at time of Venus occultation', () {
      final glob = eph.lunOccultWhenGlob(j2000Ut, Body.venus, CalcFlags.none);
      final actual = eph.lunOccultWhere(
        JdUt1(glob.timeMaximum),
        Body.venus,
        CalcFlags.none,
      );
      final expected = oracle.lunOccultWhere(
        glob.timeMaximum,
        Body.venus.rawValue,
        0,
      );

      expectAgreement(
        'centralLongitude',
        actual.centralLongitude,
        expected.geolon,
        AgreementClass.positional,
      );
      expectAgreement(
        'centralLatitude',
        actual.centralLatitude,
        expected.geolat,
        AgreementClass.positional,
      );
      expect(actual.flags.value, equals(expected.returnFlag));

      expect(actual.coreDiameterKm.isFinite, isTrue);
      expect(actual.penumbraDiameterKm.isFinite, isTrue);
      expect(actual.shadowAxisDistanceKm.isFinite, isTrue);
      expect(actual.umbraDiameterFundamentalKm.isFinite, isTrue);
      expect(actual.penumbraDiameterFundamentalKm.isFinite, isTrue);
      expect(actual.cosUmbraHalfAngle.isFinite, isTrue);
      expect(actual.cosPenumbraHalfAngle.isFinite, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  // Fixed-star occultation (requires sefstars.txt)
  // -----------------------------------------------------------------------

  group('fixed-star occultation', () {
    test('Regulus occultation via starname', () {
      final ephePath = Platform.environment['SWE_EPHE_PATH'];
      if (ephePath == null) {
        markTestSkipped('SWE_EPHE_PATH not set');
        return;
      }
      final swissEph = Ephemeris(
        EphemerisConfig(
          ephemerisSource: EphemerisSource.swiss,
          ephePath: ephePath,
        ),
      );
      addTearDown(swissEph.close);

      final oracleStar = Oracle(ephePath: ephePath);
      addTearDown(oracleStar.close);

      final actual = swissEph.lunOccultWhenGlob(
        j2000Ut,
        Body.sun,
        CalcFlags.swiEph,
        starname: 'Regulus',
      );
      final expected = oracleStar.lunOccultWhenGlob(
        j2000Ut.value,
        0,
        swe.seFlgSwiEph,
        starname: 'Regulus',
      );

      expectAgreement(
        'timeMaximum',
        actual.timeMaximum,
        expected.maxEclipse,
        AgreementClass.search,
        tolerance: _searchTolerance,
      );
      expect(actual.flags.value, equals(expected.returnFlag));
    });
  });

  // -----------------------------------------------------------------------
  // Bitmask semantics — exact flag match against oracle
  // -----------------------------------------------------------------------

  group('eclipse type bitmask semantics', () {
    test('solar: total eclipse flags match oracle exactly', () {
      final actual = eph.solEclipseWhenGlob(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.total,
      );
      final expected = oracle.solEclipseWhenGlob(
        j2000Ut.value,
        0,
        eclType: swe.seEclTotal,
      );
      expect(actual.flags.contains(EclipseFlags.total), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('solar: annular eclipse flags match oracle exactly', () {
      final actual = eph.solEclipseWhenGlob(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.annular,
      );
      final expected = oracle.solEclipseWhenGlob(
        j2000Ut.value,
        0,
        eclType: swe.seEclAnnular,
      );
      expect(actual.flags.contains(EclipseFlags.annular), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('solar: partial eclipse flags match oracle exactly', () {
      final actual = eph.solEclipseWhenGlob(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.partial,
      );
      final expected = oracle.solEclipseWhenGlob(
        j2000Ut.value,
        0,
        eclType: swe.seEclPartial,
      );
      expect(actual.flags.contains(EclipseFlags.partial), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('solar: hybrid eclipse flags match oracle exactly', () {
      final actual = eph.solEclipseWhenGlob(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.hybrid,
      );
      final expected = oracle.solEclipseWhenGlob(
        j2000Ut.value,
        0,
        eclType: swe.seEclHybrid,
      );
      expect(actual.flags.contains(EclipseFlags.hybrid), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('lunar: total eclipse flags match oracle exactly', () {
      final actual = eph.lunEclipseWhen(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.total,
      );
      final expected = oracle.lunEclipseWhen(
        j2000Ut.value,
        0,
        eclType: swe.seEclTotal,
      );
      expect(actual.flags.contains(EclipseFlags.total), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('lunar: partial eclipse flags match oracle exactly', () {
      final actual = eph.lunEclipseWhen(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.partial,
      );
      final expected = oracle.lunEclipseWhen(
        j2000Ut.value,
        0,
        eclType: swe.seEclPartial,
      );
      expect(actual.flags.contains(EclipseFlags.partial), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });

    test('lunar: penumbral eclipse flags match oracle exactly', () {
      final actual = eph.lunEclipseWhen(
        j2000Ut,
        CalcFlags.none,
        eclType: EclipseFlags.penumbral,
      );
      final expected = oracle.lunEclipseWhen(
        j2000Ut.value,
        0,
        eclType: swe.seEclPenumbral,
      );
      expect(actual.flags.contains(EclipseFlags.penumbral), isTrue);
      expect(actual.flags.value, equals(expected.returnFlag));
    });
  });
}
