// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:swisseph_rs/swisseph_rs.dart';

void main() {
  // Create an engine with default (Moshier) ephemeris.
  // For higher precision, pass ephePath pointing to Swiss Ephemeris data files.
  final eph = Ephemeris(const EphemerisConfig());

  // J2000.0
  const j2000 = JdUt1(2451545.0);

  // Planetary positions
  for (final body in [
    Body.sun,
    Body.moon,
    Body.mercury,
    Body.venus,
    Body.mars,
  ]) {
    final r = eph.calcUt(j2000, body, CalcFlags.speed);
    print(
      '${eph.getPlanetName(body)}: '
      '${r.longitude.toStringAsFixed(4)} '
      '(${r.longitudeSpeed.toStringAsFixed(4)} deg/day)',
    );
  }

  // Sidereal position (Lahiri ayanamsa)
  const sidConfig = EphemerisConfig(siderealMode: SiderealMode.lahiri);
  final sidSun = eph.calcUtWithConfig(
    j2000,
    Body.sun,
    CalcFlags.speed | CalcFlags.sidereal,
    sidConfig,
  );
  print('\nSun (Lahiri sidereal): ${sidSun.longitude.toStringAsFixed(4)}');

  // Houses
  final houses = eph.houses(j2000, 28.6139, 77.2090, HouseSystem.placidus);
  print('\nPlacidus houses for Delhi:');
  print('  Ascendant: ${houses.ascmc.ascendant.toStringAsFixed(4)}');
  print('  MC: ${houses.ascmc.mc.toStringAsFixed(4)}');
  for (var i = 0; i < houses.cusps.length; i++) {
    print('  House ${i + 1}: ${houses.cusps[i].toStringAsFixed(4)}');
  }

  // Date conversion
  final jd = julday(2024, 3, 20, 12.0, CalendarType.gregorian);
  print('\n2024-03-20 12:00 UT = JD ${jd.value}');

  final rev = revjul(jd.value, CalendarType.gregorian);
  print('Back to calendar: ${rev.year}-${rev.month}-${rev.day} ${rev.hour}h');

  eph.close();
}
