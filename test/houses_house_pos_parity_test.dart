// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Parity of the Houses tab's per-body house position against `swetest`.
///
/// Reference: swetest 2.10.03 over this repo's own `assets/ephe`, captured with
///
/// ```
/// swetest -edir./assets/ephe -p0123456789 -b1.1.2026 -ut0:00 -house13.4,52.5,P -fPj -head
/// ```
///
/// The `j` column is `swe_house_pos`' raw value (1.0–12.999999): integer part
/// the house number, fraction the position within it. `swisseph_rs` reproduces
/// swetest to printed precision; the tolerance below is that rounding plus the
/// small swisseph_rs-vs-C body-position gap (swe-dashboard/62) mapped through
/// 30° per house.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;
import 'package:swe_dashboard/core/ephemeris/rust_eph.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/tabs/houses/houses_provider.dart';

/// 1 Jan 2026, 00:00 UT.
const double _jd20260101 = 2461041.5;

const double _geolat = 52.5;
const double _geolon = 13.4;
const int _placidus = 0x50;

/// swetest `-fPj` house-number values, Sun … Pluto (`-p0123456789` order).
const _swetestHousePos = <double>[
  3.6950070, // Sun
  8.8457028, // Moon
  3.3893769, // Mercury
  3.6631835, // Venus
  3.7554866, // Mars
  9.9768874, // Jupiter
  6.0059091, // Saturn
  8.5108452, // Uranus
  6.1562018, // Neptune
  4.2872889, // Pluto
];

/// 1° of house is 1/30 in `j`; the worst body-position gap is ~3e-4°, so this
/// bounds the mapped `j` error with headroom.
const double _tol = 1e-4;

void main() {
  late RustEph eph;

  setUp(() {
    eph = RustEph(
      const rs.EphemerisConfig(
        ephemerisSource: rs.EphemerisSource.swiss,
        ephePath: 'assets/ephe',
      ),
    );
  });

  tearDown(() => eph.close());

  test('house position per body matches swetest -house13.4,52.5,P -fPj', () {
    final result = computeHouses(
      eph,
      jdUt: _jd20260101,
      lat: _geolat,
      lon: _geolon,
      hsys: _placidus,
      hsysName: 'Placidus',
      bodies: houseBodies,
      iflag: seFlgSwiEph,
      getName: (body) => 'Body $body',
    );

    expect(result.bodyPositions, hasLength(houseBodies.length));

    for (var i = 0; i < houseBodies.length; i++) {
      final b = result.bodyPositions[i];
      expect(b.bodyId, houseBodies[i], reason: 'body $i id');
      expect(b.errorMessage, isNull, reason: 'body ${houseBodies[i]}');
      expect(
        b.housePos,
        closeTo(_swetestHousePos[i], _tol),
        reason: 'body ${houseBodies[i]} house position',
      );
      // House number and degrees are pure derivations of the same value.
      expect(b.houseNumber, _swetestHousePos[i].floor());
      expect(
        b.positionDegrees,
        closeTo((_swetestHousePos[i] - 1) * 30, 30 * _tol),
      );
    }
  });
}
