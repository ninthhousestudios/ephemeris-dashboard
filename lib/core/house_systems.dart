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
  HouseSystemDef(0x50, 'Placidus'), // P
  HouseSystemDef(0x4B, 'Koch'), // K
  HouseSystemDef(0x4F, 'Porphyry'), // O
  HouseSystemDef(0x52, 'Regiomontanus'), // R
  HouseSystemDef(0x43, 'Campanus'), // C
  HouseSystemDef(0x45, 'Equal (Asc)'), // E
  HouseSystemDef(0x57, 'Whole Sign'), // W
  HouseSystemDef(0x41, 'Equal (MC)'), // A
  HouseSystemDef(0x42, 'Alcabitius'), // B
  HouseSystemDef(0x4D, 'Morinus'), // M
  HouseSystemDef(0x55, 'Krusinski'), // U
  HouseSystemDef(0x48, 'Azimuthal/Horizontal'), // H
  HouseSystemDef(0x56, 'Vehlow Equal'), // V
  HouseSystemDef(0x58, 'Meridian (Axial)'), // X
  HouseSystemDef(0x47, 'Gauquelin (36)'), // G
  HouseSystemDef(0x54, 'Polich/Page'), // T
  HouseSystemDef(0x44, 'Equal (MC, desc)'), // D
  HouseSystemDef(0x4E, 'Equal/1=Aries'), // N
  HouseSystemDef(0x59, 'APC Houses'), // Y
  HouseSystemDef(0x46, 'Carter Poli-Equatorial'), // F
  HouseSystemDef(0x49, 'Sunshine (Treindl)'), // I
  HouseSystemDef(0x69, 'Sunshine (Makransky)'), // i
  HouseSystemDef(0x4C, 'Pullen SD'), // L
  HouseSystemDef(0x51, 'Pullen SR'), // Q
];

/// The single app-wide house system (persisted).
///
/// One source of truth so the Houses tab and the body tabs (which report each
/// body's house position, swe-dashboard/58) cannot disagree.
final selectedHouseSystemProvider = StateProvider<int>((ref) {
  return ref.read(persistenceProvider).loadHouseSystem();
});
