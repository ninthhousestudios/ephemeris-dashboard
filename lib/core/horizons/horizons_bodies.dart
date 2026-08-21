// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

// A curated catalogue of Horizons COMMAND targets for the body picker.
//
// Horizons computes ONE target per request (COMMAND is a single body), and the
// app Context carries no body — bodies are a per-tab selection for engine
// config, never part of the Moment/location Context that Load-from-Context
// reads. So the target is chosen here, by picker, not mapped from the Context.
//
// Major bodies use their bare NAIF id; small bodies use the `<number>;` form —
// the trailing ';' forces Horizons' small-body search, so '1;' resolves to
// Ceres rather than the Mercury barycenter (id 1). Comets are intentionally
// omitted: their designations collide and disambiguate (apparitions, fragments)
// so they belong in the free-text target field, not a one-click picker.

import '../body_catalog.dart';

/// One pickable Horizons target: a display label and its COMMAND string.
class HorizonsBody {
  const HorizonsBody(this.label, this.command);

  final String label;

  /// The exact COMMAND value (e.g. `499`, `301`, `2060;`).
  final String command;
}

/// A named section in the picker.
class HorizonsBodyGroup {
  const HorizonsBodyGroup(this.label, this.bodies);

  final String label;
  final List<HorizonsBody> bodies;
}

const _majors = <HorizonsBody>[
  HorizonsBody('Sun', '10'),
  HorizonsBody('Moon', '301'),
  HorizonsBody('Mercury', '199'),
  HorizonsBody('Venus', '299'),
  HorizonsBody('Earth', '399'),
  HorizonsBody('Mars', '499'),
  HorizonsBody('Jupiter', '599'),
  HorizonsBody('Saturn', '699'),
  HorizonsBody('Uranus', '799'),
  HorizonsBody('Neptune', '899'),
  HorizonsBody('Pluto', '999'),
];

const _barycenters = <HorizonsBody>[
  HorizonsBody('Solar System barycenter', '0'),
  HorizonsBody('Mercury barycenter', '1'),
  HorizonsBody('Venus barycenter', '2'),
  HorizonsBody('Earth-Moon barycenter', '3'),
  HorizonsBody('Mars barycenter', '4'),
  HorizonsBody('Jupiter barycenter', '5'),
  HorizonsBody('Saturn barycenter', '6'),
  HorizonsBody('Uranus barycenter', '7'),
  HorizonsBody('Neptune barycenter', '8'),
  HorizonsBody('Pluto barycenter', '9'),
];

/// Numbered small bodies from the shared [BodyCatalog.namedAsteroids] map,
/// rendered as `<mpc>;` COMMANDs. Reuses the single catalogue so the picker and
/// the SE-side body lists never drift.
final _minors = <HorizonsBody>[
  for (final entry in BodyCatalog.namedAsteroids.entries)
    HorizonsBody(entry.value, '${entry.key};'),
];

/// The picker's sections, in display order.
final horizonsBodyGroups = <HorizonsBodyGroup>[
  const HorizonsBodyGroup('Planets & luminaries', _majors),
  const HorizonsBodyGroup('Barycenters', _barycenters),
  HorizonsBodyGroup('Minor bodies', _minors),
];

/// Every pickable body, flattened.
final horizonsBodies = <HorizonsBody>[
  for (final group in horizonsBodyGroups) ...group.bodies,
];
