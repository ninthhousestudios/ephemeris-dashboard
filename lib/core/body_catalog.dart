// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'swe_constants.dart';
import 'ephe/catalog.dart';

/// A named body list a picker offers as one chip group.
class BodyPreset {
  const BodyPreset(this.label, this.bodies);

  final String label;
  final List<int> bodies;
}

/// The app's body vocabulary: which SE body ids exist as pickable groups, and
/// what to call them.
///
/// One home for lists that were copied across five tab files and had drifted:
/// `defaultBodies`/`extraBodies`/`uranianBodies` (planets_provider, imported
/// cross-tab by differential), the private `_standardBodies`/`_outerBodies`/
/// `_uranianBodies` (phenomena), `_defaultBodies`/`_extraBodies` (nodes), the
/// two near-identical named-asteroid maps, and two byte-identical `_bodyLabel`
/// functions (swe-dashboard/85).
///
/// The groups are *content*, not tab layout — a tab composes the rows it wants
/// (`[...BodyCatalog.classical, ...BodyCatalog.outers]`). That is what lets
/// Phenomena omit the lunar points and Nodes omit the Uranian bodies without
/// either of them owning its own copy of the classical seven.
abstract final class BodyCatalog {
  /// Sun through Saturn.
  static const classical = <int>[
    seSun,
    seMoon,
    seMercury,
    seVenus,
    seMars,
    seJupiter,
    seSaturn,
  ];

  /// Uranus, Neptune, Pluto.
  static const outers = <int>[seUranus, seNeptune, sePluto];

  /// Lunar nodes and apsides (Lilith variants).
  static const lunarPoints = <int>[
    seMeanNode,
    seTrueNode,
    seMeanApog,
    seOscuApog,
  ];

  /// Interpolated lunar apogee/perigee — a separate group from [lunarPoints]
  /// because the tabs that offer the mean/true pair do not all offer these.
  static const interpolatedPoints = <int>[seIntpApog, seIntpPerg];

  /// Centaurs and the main-belt minor planets that have their own SE ids.
  static const centaursAndMinors = <int>[
    seChiron,
    sePholus,
    seCeres,
    sePallas,
    seJuno,
    seVesta,
  ];

  /// Uranian / Hamburg School fictitious bodies.
  static const uranian = <int>[
    seCupido,
    seHades,
    seZeus,
    seKronos,
    seApollon,
    seAdmetos,
    seVulkanus,
    sePoseidon,
  ];

  /// Everything the Planets tab shows without progressive disclosure, and the
  /// `Full` preset.
  static const full = <int>[...classical, ...outers, ...lunarPoints];

  /// Quick-selection presets over [full].
  static const presets = <BodyPreset>[
    BodyPreset('Classical', classical),
    BodyPreset('Full', full),
    BodyPreset('Outers', outers),
    BodyPreset('Nodes', lunarPoints),
  ];

  /// Common named asteroids by MPC number; body id is `seAstOffset + mpc`.
  ///
  /// Numeric order. Ceres/Pallas/Juno/Vesta/Chiron/Pholus also have their own
  /// SE ids (see [centaursAndMinors]) — the MPC route reads the asteroid file
  /// instead, which is a different calculation, so both entries are real.
  static const namedAsteroids = <int, String>{
    1: 'Ceres',
    2: 'Pallas',
    3: 'Juno',
    4: 'Vesta',
    5: 'Astraea',
    6: 'Hebe',
    7: 'Iris',
    8: 'Flora',
    9: 'Metis',
    10: 'Hygiea',
    16: 'Psyche',
    433: 'Eros',
    1221: 'Amor',
    2060: 'Chiron',
    5145: 'Pholus',
    7066: 'Nessus',
    50000: 'Quaoar',
    90377: 'Sedna',
    90482: 'Orcus',
    136108: 'Haumea',
    136199: 'Eris',
    136472: 'Makemake',
    225088: 'Gonggong',
  };

  /// Named comets by pseudo-MPC number, derived from the Ephemeris Source
  /// catalog. Same `seAstOffset + n` id space as [namedAsteroids].
  static final namedComets = <int, String>{
    for (final (mpc, name) in cometSeed) mpc: name,
  };

  /// Short chip labels for the bodies with their own SE id.
  static const names = <int, String>{
    seSun: 'Sun',
    seMoon: 'Moon',
    seMercury: 'Mercury',
    seVenus: 'Venus',
    seMars: 'Mars',
    seJupiter: 'Jupiter',
    seSaturn: 'Saturn',
    seUranus: 'Uranus',
    seNeptune: 'Neptune',
    sePluto: 'Pluto',
    seMeanNode: 'M.Node',
    seTrueNode: 'T.Node',
    seMeanApog: 'M.Lilith',
    seOscuApog: 'O.Lilith',
    seEarth: 'Earth',
    seChiron: 'Chiron',
    sePholus: 'Pholus',
    seCeres: 'Ceres',
    sePallas: 'Pallas',
    seJuno: 'Juno',
    seVesta: 'Vesta',
    seIntpApog: 'I.Apogee',
    seIntpPerg: 'I.Perigee',
    seCupido: 'Cupido',
    seHades: 'Hades',
    seZeus: 'Zeus',
    seKronos: 'Kronos',
    seApollon: 'Apollon',
    seAdmetos: 'Admetos',
    seVulkanus: 'Vulkanus',
    sePoseidon: 'Poseidon',
  };

  /// Short label for a body constant. Falls back to `#<mpc>` for a numbered
  /// asteroid and `Body <id>` for anything else, so a picker never renders an
  /// empty chip for an id the catalog has not named.
  static String labelFor(int body) {
    final name = names[body];
    if (name != null) return name;
    if (body >= seAstOffset) {
      final mpc = body - seAstOffset;
      return namedComets[mpc] ?? namedAsteroids[mpc] ?? '#$mpc';
    }
    return 'Body $body';
  }
}
