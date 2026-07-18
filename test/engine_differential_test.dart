// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph/swisseph.dart' as legacy;
import 'package:swisseph_rs/swisseph_rs.dart' as rs;

void main() {
  late legacy.SwissEph swe;
  late rs.Ephemeris eph;

  setUpAll(() {
    swe = legacy.SwissEph.find();
    eph = rs.Ephemeris(const rs.EphemerisConfig());
  });

  tearDownAll(() {
    eph.close();
  });

  test('calcUt Sun @ J2000 matches within 1e-9', () {
    const jd = 2451545.0; // J2000.0
    const flags = legacy.seFlgSpeed;

    final old = swe.calcUt(jd, legacy.seSun, flags);
    final neu = eph.calcUt(
      const rs.JdUt1(jd),
      rs.Body.sun,
      const rs.CalcFlags(flags),
    );

    expect(neu.longitude, closeTo(old.longitude, 1e-9));
    expect(neu.latitude, closeTo(old.latitude, 1e-9));
    expect(neu.distance, closeTo(old.distance, 1e-9));
    expect(neu.longitudeSpeed, closeTo(old.longitudeSpeed, 1e-9));
    expect(neu.latitudeSpeed, closeTo(old.latitudeSpeed, 1e-9));
    expect(neu.distanceSpeed, closeTo(old.distanceSpeed, 1e-9));
  });
}
