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
const coordGroup = FlagGroup(
  label: 'Coordinates',
  members: [
    FlagDef(
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

/// Independent composable toggles (shown as a flat row, not a labeled group).
final flagToggles = [
  const FlagDef(
    label: 'Speed',
    value: seFlgSpeed,
    tooltip: 'Include speed (daily motion) in output',
  ),
  const FlagDef(
    label: 'ICRS',
    value: seFlgIcrs,
    tooltip:
        'Reference output to the ICRS (the fixed radio-source frame) instead '
        'of the dynamical J2000 equinox — a constant ~17 mas frame-bias '
        'rotation. Only matters at sub-arcsecond precision.',
  ),
];

/// Position-correction toggles — each peels one refinement off the default
/// apparent position (where you would actually see the body), moving it toward
/// the geometric position. Shown together under a "Corrections" label.
final positionCorrectionToggles = [
  const FlagDef(
    label: 'True Pos',
    value: seFlgTruePos,
    tooltip:
        'True geometric position: removes light-time (retardation). The body '
        'where it actually is at t, not where its light shows it. Carries no '
        'aberration or deflection either.',
  ),
  const FlagDef(
    label: 'No Aberr',
    value: seFlgNoAberr,
    tooltip:
        "Removes annual aberration — the ~20″ apparent shift from Earth's "
        'orbital velocity.',
  ),
  const FlagDef(
    label: 'No Grav',
    value: seFlgNoGdefl,
    tooltip:
        'Removes gravitational light-deflection by the Sun (<1.8″, only '
        'appreciable near the solar limb).',
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
