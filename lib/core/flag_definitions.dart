// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'swe_constants.dart';

/// Metadata for a single flag toggle or group member.
class FlagDef {
  const FlagDef({required this.label, required this.value, this.tooltip = ''});

  final String label;
  final int value;
  final String tooltip;
}

/// A mutually exclusive group — only one member can be active at a time.
/// The first member is the default.
class FlagGroup {
  const FlagGroup({required this.label, required this.members});

  final String label;
  final List<FlagDef> members;

  int get defaultValue => members.first.value;
}

/// Coordinate system group — mutually exclusive.
final coordGroup = FlagGroup(
  label: 'Coordinates',
  members: [
    const FlagDef(
      label: 'Ecliptic',
      value: 0, // default — no flag bit needed
      tooltip: 'Ecliptic longitude/latitude (default)',
    ),
    FlagDef(
      label: 'Equatorial',
      value: seFlgEquatorial,
      tooltip: 'Right ascension / declination',
    ),
    FlagDef(
      label: 'XYZ',
      value: seFlgXyz,
      tooltip: 'Cartesian X/Y/Z coordinates',
    ),
  ],
);

/// Independent composable toggles.
final flagToggles = [
  FlagDef(
    label: 'Speed',
    value: seFlgSpeed,
    tooltip: 'Include speed (daily motion) in output',
  ),
  FlagDef(
    label: 'True Pos',
    value: seFlgTruePos,
    tooltip: 'True geometric position (no aberration/deflection)',
  ),
  FlagDef(
    label: 'No Aberr',
    value: seFlgNoAberr,
    tooltip: 'No annual aberration correction',
  ),
  FlagDef(
    label: 'No Grav',
    value: seFlgNoGdefl,
    tooltip: 'No gravitational light deflection',
  ),
  FlagDef(
    label: 'Radians',
    value: seFlgRadians,
    tooltip: 'Output in radians instead of degrees',
  ),
  FlagDef(
    label: 'ICRS',
    value: seFlgIcrs,
    tooltip: 'ICRS (International Celestial Reference System)',
  ),
];

/// Flags that are auto-locked by context bar settings.
/// These should NOT appear as user toggles — they are managed automatically.
const autoManagedFlags = {
  seFlgSidereal, // locked by ZodiacRef.sidereal
  seFlgTopoCtr, // locked by Origin.topocentric
  seFlgHelCtr, // locked by Origin.heliocentric
  seFlgBaryCtr, // locked by Origin.barycentric
  seFlgNoNut, // locked by EqRef.meanEquinoxOfDate
  seFlgJ2000, // locked by EqRef.meanEquinoxJ2000
  seFlgJplEph, // locked by EpheSource.jpl
  seFlgSwiEph, // locked by EpheSource.swissEph
  seFlgMosEph, // locked by EpheSource.moshier
};
