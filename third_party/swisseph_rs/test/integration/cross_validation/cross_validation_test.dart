// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';
import 'dart:io';

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

const double _eps = 1e-7;
const double _epsLoose = 1e-4;
const double _epsRiseSet = 1e-3;
const double _epsEquatorial = 1e-4;

// Moshier osculating node speed: documented swisseph-rs boundary artifact
// (binding-patterns.md), tolerance 5e-6°/day.
const double _epsMoshierNodeSpeed = 5e-6;

// Moshier osculating node position: documented swisseph-rs boundary artifact
// (binding-patterns.md), tolerance 5e-5°.
const double _epsMoshierNodePos = 5e-5;

// swetest text output sometimes truncates to ≤5 decimal places; reference
// values with fewer significant digits need proportionally wider tolerance.
double _epsTrunc(num ref) {
  if (ref.toDouble() == 0) return _eps;
  final s = ref.toString();
  if (s.contains('e') || s.contains('E')) return _eps;
  if (!s.contains('.')) return _eps;
  final decLen = s.split('.')[1].length;
  if (decLen <= 5) return 1e-4;
  if (decLen <= 6) return 1e-5;
  return _eps;
}

const _trueNodeId = 11;
const _meanNodeId = 10;

double _calcTol(int bodyId, String field, num ref) {
  if (bodyId == _trueNodeId || bodyId == _meanNodeId) {
    if (field.contains('speed')) return _epsMoshierNodeSpeed;
    if (field == 'longitude' || field == 'latitude') return _epsMoshierNodePos;
  }
  return _epsTrunc(ref);
}

const _trueAyanamsas = {27, 28, 29, 30, 35, 36};

late Map<String, dynamic> _ref;
late Ephemeris _eph;

SiderealMode _sidModeFromId(int id) =>
    SiderealMode.values.firstWhere((m) => m.value == id);

HouseSystem _hsysFromCode(int code) {
  final hs = HouseSystem.fromCharCode(code);
  if (hs == null) throw ArgumentError('Unknown house system code: $code');
  return hs;
}

void main() {
  setUpAll(() {
    final file = File('test/integration/cross_validation/reference_data.json');
    if (!file.existsSync()) {
      throw StateError('reference_data.json not found');
    }
    _ref = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    _eph = Ephemeris(const EphemerisConfig());
  });

  tearDownAll(() {
    _eph.close();
  });

  // ── 1. Julian Day conversion ──────────────────────────────────────────

  group('julday', () {
    test('all date → JD conversions match', () {
      final entries = _ref['julday'] as List;
      for (final entry in entries) {
        final input = entry['input'];
        final expectedJd = (entry['jd'] as num).toDouble();
        final jd = julday(
          input['year'] as int,
          input['month'] as int,
          input['day'] as int,
          (input['hour'] as num).toDouble(),
          CalendarType.gregorian,
        );
        expect(
          jd.value,
          closeTo(expectedJd, _eps),
          reason:
              'julday(${input['year']}-${input['month']}-${input['day']} '
              '${input['hour']}h)',
        );
      }
    });

    test('all JD → date roundtrips match', () {
      final entries = _ref['julday'] as List;
      for (final entry in entries) {
        final jd = (entry['jd'] as num).toDouble();
        final expected = entry['revjul'];
        final result = revjul(jd, CalendarType.gregorian);
        expect(
          result.year,
          equals(expected['year']),
          reason: 'revjul($jd).year',
        );
        expect(
          result.month,
          equals(expected['month']),
          reason: 'revjul($jd).month',
        );
        expect(result.day, equals(expected['day']), reason: 'revjul($jd).day');
        expect(
          result.hour,
          closeTo((expected['hour'] as num).toDouble(), 1e-6),
          reason: 'revjul($jd).hour',
        );
      }
    });
  });

  // ── 2. Planetary positions — Moshier (tropical) ──────────────────────

  group('planet positions (Moshier, tropical)', () {
    test('all planet/date combinations match', () {
      final entries = _ref['planet_positions_moshier'] as List;
      var tested = 0;
      for (final e in entries) {
        final entry = e as Map<String, dynamic>;
        if (entry.containsKey('error')) continue;
        final jd = JdUt1((entry['jd'] as num).toDouble());
        final bodyId = entry['body'] as int;
        final body = Body.fromRawId(bodyId);
        final name = entry['body_name'] as String;

        final result = _eph.calcUt(jd, body, CalcFlags.speed);

        for (final (field, actual) in [
          ('longitude', result.longitude),
          ('latitude', result.latitude),
          ('distance', result.distance),
          ('longitude_speed', result.longitudeSpeed),
          ('latitude_speed', result.latitudeSpeed),
          ('distance_speed', result.distanceSpeed),
        ]) {
          final ref = entry[field] as num;
          expect(
            actual,
            closeTo(ref.toDouble(), _calcTol(bodyId, field, ref)),
            reason: '$name $field at JD=${jd.value}',
          );
        }
        tested++;
      }
      expect(tested, greaterThan(80));
    });
  });

  // ── 3. Sidereal positions — multiple ayanamsas ────────────────────────

  group('sidereal positions', () {
    test('all sidereal planet/ayanamsa combinations match', () {
      final entries = _ref['sidereal_positions'] as List;
      var tested = 0;
      for (final entry in entries) {
        final jd = JdUt1((entry['jd'] as num).toDouble());
        final sidId = entry['ayanamsa_id'] as int;
        final sidName = entry['ayanamsa_name'] as String;
        final body = Body.fromRawId(entry['body'] as int);
        final bodyName = entry['body_name'] as String;

        final config = EphemerisConfig(siderealMode: _sidModeFromId(sidId));
        final result = _eph.calcUtWithConfig(
          jd,
          body,
          CalcFlags.speed | CalcFlags.sidereal,
          config,
        );

        expect(
          result.longitude,
          closeTo((entry['longitude'] as num).toDouble(), _eps),
          reason: '$bodyName sidereal ($sidName) lon at JD=${jd.value}',
        );
        expect(
          result.latitude,
          closeTo((entry['latitude'] as num).toDouble(), _eps),
          reason: '$bodyName sidereal ($sidName) lat at JD=${jd.value}',
        );
        tested++;
      }
      expect(tested, equals(56));
    });
  });

  // ── 4. Ayanamsa values ────────────────────────────────────────────────

  group('ayanamsa values', () {
    test('all ayanamsa/date combinations match', () {
      final entries = _ref['ayanamsa_values'] as List;
      var tested = 0;
      for (final entry in entries) {
        final jd = JdUt1((entry['jd'] as num).toDouble());
        final sidId = entry['ayanamsa_id'] as int;
        final sidName = entry['ayanamsa_name'] as String;
        final expected = (entry['value'] as num).toDouble();

        final config = EphemerisConfig(siderealMode: _sidModeFromId(sidId));
        final eph = Ephemeris(config);
        try {
          final (:ayanamsa, flagsUsed: _) = eph.getAyanamsaUt(
            jd,
            CalcFlags.none,
          );
          final tol = _trueAyanamsas.contains(sidId) ? _epsLoose : _eps;
          expect(
            ayanamsa,
            closeTo(expected, tol),
            reason: '$sidName (id=$sidId) ayanamsa at JD=${jd.value}',
          );
        } finally {
          eph.close();
        }
        tested++;
      }
      expect(tested, equals(98));
    });
  });

  // ── 5. Ayanamsa names ────────────────────────────────────────────────

  group('ayanamsa names', () {
    test('all ayanamsa names match', () {
      final entries = _ref['ayanamsa_names'] as List;
      for (final entry in entries) {
        final sidId = entry['id'] as int;
        final expected = entry['swe_name'] as String;
        final name = getAyanamsaName(_sidModeFromId(sidId));
        expect(name, equals(expected), reason: 'ayanamsa name for id=$sidId');
      }
    });
  });

  // ── 6. House cusps — multiple systems × locations × dates ─────────────

  group('house cusps', () {
    test('all house system/location/date combinations match', () {
      final entries = _ref['house_cusps'] as List;
      var tested = 0;
      for (final e in entries) {
        final entry = e as Map<String, dynamic>;
        if (entry.containsKey('error')) continue;

        final jd = JdUt1((entry['jd'] as num).toDouble());
        final loc = entry['location'];
        final lat = (loc['lat'] as num).toDouble();
        final lon = (loc['lon'] as num).toDouble();
        final locName = loc['name'] as String;
        final hsysCode = entry['hsys_code'] as int;
        final hsysName = entry['hsys_name'] as String;
        final expectedCusps = (entry['cusps'] as List).cast<num>();
        final expectedAscmc = (entry['ascmc'] as List).cast<num>();

        final result = _eph.houses(jd, lat, lon, _hsysFromCode(hsysCode));
        final label = '$hsysName at $locName, JD=${jd.value}';

        for (var i = 0; i < expectedCusps.length && i < 12; i++) {
          expect(
            result.cusps[i + 1],
            closeTo(expectedCusps[i].toDouble(), _eps),
            reason: '$label cusp ${i + 1}',
          );
        }

        expect(
          result.ascmc.ascendant,
          closeTo(expectedAscmc[0].toDouble(), _eps),
          reason: '$label ascendant',
        );
        expect(
          result.ascmc.mc,
          closeTo(expectedAscmc[1].toDouble(), _eps),
          reason: '$label MC',
        );
        expect(
          result.ascmc.armc,
          closeTo(expectedAscmc[2].toDouble(), _eps),
          reason: '$label ARMC',
        );
        expect(
          result.ascmc.vertex,
          closeTo(expectedAscmc[3].toDouble(), _eps),
          reason: '$label vertex',
        );
        expect(
          result.ascmc.equatorialAscendant,
          closeTo(expectedAscmc[4].toDouble(), _eps),
          reason: '$label equatorial ascendant',
        );
        expect(
          result.ascmc.coascendantKoch,
          closeTo(expectedAscmc[5].toDouble(), _eps),
          reason: '$label coasc Koch',
        );
        expect(
          result.ascmc.coascendantMunkasey,
          closeTo(expectedAscmc[6].toDouble(), _eps),
          reason: '$label coasc Munkasey',
        );
        expect(
          result.ascmc.polarAscendant,
          closeTo(expectedAscmc[7].toDouble(), _eps),
          reason: '$label polar ascendant',
        );

        tested++;
      }
      expect(tested, greaterThan(140));
    });
  });

  // ── 7. House system names ─────────────────────────────────────────────

  group('house names', () {
    test('all house system names match', () {
      final entries = _ref['house_names'] as List;
      for (final entry in entries) {
        final code = entry['code'] as int;
        final expected = entry['swe_name'] as String;
        final name = houseName(_hsysFromCode(code));
        expect(
          name,
          equals(expected),
          reason: 'house name for ${entry['char']}',
        );
      }
    });
  });

  // ── 8. Planet names ───────────────────────────────────────────────────

  group('planet names', () {
    test('all planet names match', () {
      final entries = _ref['planet_names'] as List;
      for (final entry in entries) {
        final pid = entry['id'] as int;
        final expected = entry['swe_name'] as String;
        final name = _eph.getPlanetName(Body.fromRawId(pid));
        expect(name, equals(expected), reason: 'planet name for id=$pid');
      }
    });
  });

  // ── 9. Rise/set times ────────────────────────────────────────────────

  group('rise/set times', () {
    test('all rise/set events match', () {
      final entries = _ref['rise_set'] as List;
      var tested = 0;
      for (final e in entries) {
        final entry = e as Map<String, dynamic>;
        if (entry.containsKey('error')) continue;

        final jd = JdUt1((entry['jd'] as num).toDouble());
        final body = Body.fromRawId(entry['body'] as int);
        final bodyName = entry['body_name'] as String;
        final eventName = entry['event'] as String;
        final flag = RiseSetFlags(entry['flag'] as int);
        final loc = entry['location'];
        final lat = (loc['lat'] as num).toDouble();
        final lon = (loc['lon'] as num).toDouble();
        final alt = (loc['alt'] as num).toDouble();
        final locName = loc['name'] as String;
        final expectedJd = (entry['transit_jd'] as num).toDouble();

        final result = _eph.riseTrans(
          jd,
          body,
          CalcFlags.none,
          flag,
          geolon: lon,
          geolat: lat,
          geoalt: alt,
          atpress: 1013.25,
          attemp: 15.0,
        );

        expect(
          result.time,
          closeTo(expectedJd, _epsRiseSet),
          reason: '$bodyName $eventName at $locName, JD=${jd.value}',
        );
        tested++;
      }
      expect(tested, greaterThan(20));
    });
  });

  // ── 10. Topocentric positions ─────────────────────────────────────────

  group('topocentric positions', () {
    test('all topocentric Sun/Moon positions match', () {
      final entries = _ref['topocentric'] as List;
      var tested = 0;
      for (final entry in entries) {
        final jd = JdUt1((entry['jd'] as num).toDouble());
        final body = Body.fromRawId(entry['body'] as int);
        final bodyName = entry['body_name'] as String;
        final loc = entry['location'];
        final lat = (loc['lat'] as num).toDouble();
        final lon = (loc['lon'] as num).toDouble();
        final alt = (loc['alt'] as num).toDouble();
        final locName = loc['name'] as String;

        final config = EphemerisConfig(
          topographic: TopoPosition(
            longitude: lon,
            latitude: lat,
            altitude: alt,
          ),
        );
        final result = _eph.calcUtWithConfig(
          jd,
          body,
          CalcFlags.speed | CalcFlags.topoctr,
          config,
        );

        expect(
          result.longitude,
          closeTo((entry['longitude'] as num).toDouble(), _eps),
          reason: '$bodyName topocentric lon at $locName',
        );
        expect(
          result.latitude,
          closeTo((entry['latitude'] as num).toDouble(), _eps),
          reason: '$bodyName topocentric lat at $locName',
        );
        expect(
          result.distance,
          closeTo((entry['distance'] as num).toDouble(), _eps),
          reason: '$bodyName topocentric dist at $locName',
        );
        tested++;
      }
      expect(tested, equals(8));
    });
  });

  // ── 11. Equatorial coordinates ────────────────────────────────────────

  group('equatorial coordinates', () {
    test('all classical planet RA/Dec values match', () {
      final entries = _ref['equatorial'] as List;
      for (final entry in entries) {
        final jd = JdUt1((entry['jd'] as num).toDouble());
        final body = Body.fromRawId(entry['body'] as int);
        final bodyName = entry['body_name'] as String;

        final result = _eph.calcUt(
          jd,
          body,
          CalcFlags.speed | CalcFlags.equatorial,
        );

        expect(
          result.longitude,
          closeTo((entry['right_ascension'] as num).toDouble(), _epsEquatorial),
          reason: '$bodyName RA',
        );
        expect(
          result.latitude,
          closeTo((entry['declination'] as num).toDouble(), _epsEquatorial),
          reason: '$bodyName Dec',
        );
        expect(
          result.distance,
          closeTo((entry['distance'] as num).toDouble(), _eps),
          reason: '$bodyName equatorial dist',
        );
      }
    });
  });

  // ── 12. getAyanamsaEx ─────────────────────────────────────────────────

  group('getAyanamsaEx', () {
    test('ayanamsa values via getAyanamsaEx match', () {
      final entries = _ref['ayanamsa_ex'] as List;
      for (final entry in entries) {
        final jd = (entry['jd'] as num).toDouble();
        final sidId = entry['ayanamsa_id'] as int;
        final expected = (entry['value'] as num).toDouble();

        final tol = _trueAyanamsas.contains(sidId) ? _epsLoose : _eps;
        final config = EphemerisConfig(siderealMode: _sidModeFromId(sidId));

        final (:ayanamsa, flagsUsed: _) = _eph.getAyanamsaExWithConfig(
          JdTt(jd),
          CalcFlags.none,
          config,
        );

        expect(
          ayanamsa,
          closeTo(expected, tol),
          reason: 'getAyanamsaEx(sidId=$sidId) at JD=$jd',
        );
      }
    });
  });

  // ── 13. Coverage summary ──────────────────────────────────────────────

  group('coverage summary', () {
    test('reference data has expected section counts', () {
      expect((_ref['julday'] as List).length, equals(7));
      expect((_ref['planet_positions_moshier'] as List).length, equals(91));
      expect((_ref['sidereal_positions'] as List).length, equals(56));
      expect((_ref['ayanamsa_values'] as List).length, equals(98));
      expect((_ref['ayanamsa_names'] as List).length, equals(14));
      expect((_ref['house_cusps'] as List).length, equals(154));
      expect((_ref['house_names'] as List).length, equals(11));
      expect((_ref['planet_names'] as List).length, equals(13));
      expect((_ref['rise_set'] as List).length, greaterThanOrEqualTo(25));
      expect((_ref['topocentric'] as List).length, equals(8));
      expect((_ref['equatorial'] as List).length, equals(7));
      expect((_ref['ayanamsa_ex'] as List).length, equals(4));
    });
  });
}
