// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Counterpart: swisseph::types::HouseSystem
enum HouseSystem {
  /// Counterpart: swisseph::types::HouseSystem::Equal
  equal(0x41),

  /// Counterpart: swisseph::types::HouseSystem::Alcabitius
  alcabitius(0x42),

  /// Counterpart: swisseph::types::HouseSystem::Campanus
  campanus(0x43),

  /// Counterpart: swisseph::types::HouseSystem::EqualMC
  equalMC(0x44),

  /// Counterpart: swisseph::types::HouseSystem::Carter
  carter(0x46),

  /// Counterpart: swisseph::types::HouseSystem::Gauquelin
  gauquelin(0x47),

  /// Counterpart: swisseph::types::HouseSystem::Horizon
  horizon(0x48),

  /// Counterpart: swisseph::types::HouseSystem::Sunshine
  sunshine(0x49),

  /// Counterpart: swisseph::types::HouseSystem::SunshineAlt
  sunshineAlt(0x69),

  /// Counterpart: swisseph::types::HouseSystem::SavardA
  savardA(0x4A),

  /// Counterpart: swisseph::types::HouseSystem::Koch
  koch(0x4B),

  /// Counterpart: swisseph::types::HouseSystem::PullenSD
  pullenSD(0x4C),

  /// Counterpart: swisseph::types::HouseSystem::Morinus
  morinus(0x4D),

  /// Counterpart: swisseph::types::HouseSystem::EqualAries
  equalAries(0x4E),

  /// Counterpart: swisseph::types::HouseSystem::Porphyry
  porphyry(0x4F),

  /// Counterpart: swisseph::types::HouseSystem::Placidus
  placidus(0x50),

  /// Counterpart: swisseph::types::HouseSystem::PullenSR
  pullenSR(0x51),

  /// Counterpart: swisseph::types::HouseSystem::Regiomontanus
  regiomontanus(0x52),

  /// Counterpart: swisseph::types::HouseSystem::Sripati
  sripati(0x53),

  /// Counterpart: swisseph::types::HouseSystem::PolichPage
  polichPage(0x54),

  /// Counterpart: swisseph::types::HouseSystem::KrusinskiPisaGoelzer
  krusinskiPisaGoelzer(0x55),

  /// Counterpart: swisseph::types::HouseSystem::Vehlow
  vehlow(0x56),

  /// Counterpart: swisseph::types::HouseSystem::WholeSign
  wholeSign(0x57),

  /// Counterpart: swisseph::types::HouseSystem::Meridian
  meridian(0x58),

  /// Counterpart: swisseph::types::HouseSystem::APC
  apc(0x59);

  /// Counterpart: swisseph::types::HouseSystem::to_char
  final int charCode;
  const HouseSystem(this.charCode);

  static final _byCharCode = {for (final v in values) v.charCode: v};

  /// Counterpart: swisseph::types::HouseSystem (`TryFrom<u8>`)
  static HouseSystem? fromCharCode(int code) {
    if (code == 0x45) return equal; // 'E' alias
    return _byCharCode[code];
  }
}

/// Counterpart: swisseph::heliacal::HeliacalEventType
enum HeliacalEventType {
  /// Counterpart: swisseph::heliacal::HeliacalEventType::MorningFirst
  morningFirst(1),

  /// Counterpart: swisseph::heliacal::HeliacalEventType::EveningLast
  eveningLast(2),

  /// Counterpart: swisseph::heliacal::HeliacalEventType::EveningFirst
  eveningFirst(3),

  /// Counterpart: swisseph::heliacal::HeliacalEventType::MorningLast
  morningLast(4),

  /// Counterpart: swisseph::heliacal::HeliacalEventType::AcronymchalRising
  acronychalRising(5),

  /// Counterpart: swisseph::heliacal::HeliacalEventType::AcronymchalSetting
  acronychalSetting(6);

  final int value;
  const HeliacalEventType(this.value);
}

/// Counterpart: swisseph::azalt::RefracDir
enum RefracDir {
  /// Counterpart: swisseph::azalt::RefracDir::TrueToApp
  trueToApp(0),

  /// Counterpart: swisseph::azalt::RefracDir::AppToTrue
  appToTrue(1);

  final int value;
  const RefracDir(this.value);
}

/// Counterpart: swisseph::azalt::AzAltDir
enum AzAltDir {
  /// Counterpart: swisseph::azalt::AzAltDir::EclToHor
  eclToHor(0),

  /// Counterpart: swisseph::azalt::AzAltDir::EquToHor
  equToHor(1);

  final int value;
  const AzAltDir(this.value);
}

/// Counterpart: swisseph::azalt::HorDir
enum HorDir {
  /// Counterpart: swisseph::azalt::HorDir::HorToEcl
  horToEcl(0),

  /// Counterpart: swisseph::azalt::HorDir::HorToEqu
  horToEqu(1);

  final int value;
  const HorDir(this.value);
}

/// Counterpart: swisseph::types::FileDataKind
enum FileDataKind {
  /// Counterpart: swisseph::types::FileDataKind::Planet
  planet(0),

  /// Counterpart: swisseph::types::FileDataKind::Moon
  moon(1),

  /// Counterpart: swisseph::types::FileDataKind::MainAsteroid
  mainAsteroid(2),

  /// Counterpart: swisseph::types::FileDataKind::Asteroid
  asteroid(3),

  /// Counterpart: swisseph::types::FileDataKind::PlanetMoon
  planetMoon(4);

  final int value;
  const FileDataKind(this.value);
}
