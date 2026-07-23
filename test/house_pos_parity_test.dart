// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Parity of the Ephemeris seam's `housePos` against `swetest`.
///
/// House position is a per-body quantity (which house a body falls in), so it
/// belongs on the body tabs — Planets, Other Bodies, Stars — not the Houses
/// cusps surface (swe-dashboard/58). This test pins the seam method itself, so
/// whichever tab consumes it inherits a trusted binding.
///
/// Reference: swetest 2.10.03 over this repo's own `assets/ephe`:
///
/// ```
/// swetest -edir./assets/ephe -p0123456789 -b1.1.2026 -ut0:00 -house13.4,52.5,P -fPj -head
/// ```
///
/// The recipe (what a consuming tab must do): armc comes from a `houses` call
/// (`ascmc[2]`), eps is the true obliquity from `calcUt(seEclNut).longitude`,
/// and body lon/lat are tropical — `housePos` is handle-free and cannot honour
/// a sidereal engine config, and swetest's `-fGgj` is tropical.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;
import 'package:swe_dashboard/core/ephemeris/rust_eph.dart';
import 'package:swe_dashboard/core/swe_constants.dart';

/// 1 Jan 2026, 00:00 UT.
const double _jd = 2461041.5;
const double _geolat = 52.5;
const double _geolon = 13.4;
const int _placidus = 0x50;

/// Sun … Pluto, swetest `-p0123456789` order.
const _bodies = [
  seSun,
  seMoon,
  seMercury,
  seVenus,
  seMars,
  seJupiter,
  seSaturn,
  seUranus,
  seNeptune,
  sePluto,
];

/// swetest `-fPj` house-number values (the raw `swe_house_pos` result).
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

/// 1° of house maps to 1/30 in the returned value; the worst body-position gap
/// (swe-dashboard/62) is ~3e-4°, so this bounds the mapped error with headroom.
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

  test('housePos matches swetest -house13.4,52.5,P -fPj', () {
    final houses = eph.houses(_jd, _geolat, _geolon, _placidus);
    final armc = houses.ascmc[2];
    final eps = eph.calcUt(_jd, seEclNut, seFlgSwiEph).longitude;

    for (var i = 0; i < _bodies.length; i++) {
      final pos = eph.calcUt(_jd, _bodies[i], seFlgSwiEph);
      final hp = eph.housePos(
        armc,
        _geolat,
        eps,
        _placidus,
        pos.longitude,
        pos.latitude,
      );
      expect(
        hp,
        closeTo(_swetestHousePos[i], _tol),
        reason: 'body ${_bodies[i]} house position',
      );
    }
  });
}
