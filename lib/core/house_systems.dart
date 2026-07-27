// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'persistence.dart';

/// Known house system codes and names.
class HouseSystemDef {
  const HouseSystemDef(this.code, this.label);
  final int code; // ASCII char code
  final String label;

  String get char => String.fromCharCode(code);
}

final houseSystems = <HouseSystemDef>[
  const HouseSystemDef(0x50, 'Placidus'), // P
  const HouseSystemDef(0x4B, 'Koch'), // K
  const HouseSystemDef(0x4F, 'Porphyry'), // O
  const HouseSystemDef(0x52, 'Regiomontanus'), // R
  const HouseSystemDef(0x43, 'Campanus'), // C
  const HouseSystemDef(0x45, 'Equal (Asc)'), // E
  const HouseSystemDef(0x57, 'Whole Sign'), // W
  const HouseSystemDef(0x41, 'Equal (MC)'), // A
  const HouseSystemDef(0x42, 'Alcabitius'), // B
  const HouseSystemDef(0x4D, 'Morinus'), // M
  const HouseSystemDef(0x55, 'Krusinski'), // U
  const HouseSystemDef(0x48, 'Azimuthal/Horizontal'), // H
  const HouseSystemDef(0x56, 'Vehlow Equal'), // V
  const HouseSystemDef(0x58, 'Meridian (Axial)'), // X
  const HouseSystemDef(0x47, 'Gauquelin (36)'), // G
  const HouseSystemDef(0x54, 'Polich/Page'), // T
  const HouseSystemDef(0x44, 'Equal (MC, desc)'), // D
  const HouseSystemDef(0x4E, 'Equal/1=Aries'), // N
  const HouseSystemDef(0x59, 'APC Houses'), // Y
  const HouseSystemDef(0x46, 'Carter Poli-Equatorial'), // F
  const HouseSystemDef(0x49, 'Sunshine (Treindl)'), // I
  const HouseSystemDef(0x69, 'Sunshine (Makransky)'), // i
  const HouseSystemDef(0x4C, 'Pullen SD'), // L
  const HouseSystemDef(0x51, 'Pullen SR'), // Q
];

/// The single app-wide house system (persisted).
///
/// One source of truth so the Houses tab and the body tabs (which report each
/// body's house position, swe-dashboard/58) cannot disagree.
final selectedHouseSystemProvider = StateProvider<int>((ref) {
  return ref.read(persistenceProvider).loadHouseSystem();
});
