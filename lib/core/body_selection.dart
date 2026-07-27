// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'swe_constants.dart';
import 'body_catalog.dart';
import 'ephe/catalog.dart';
import 'ephe/scanner.dart';
import 'ephe/types.dart';

/// Every body selection in the app, declared in core.
///
/// The engine config must declare which asteroid / planet-moon Ephemeris
/// Source files it will read — `swisseph_rs` fails engine creation if a
/// declared file is missing, and returns nothing for a body whose file was
/// never declared. So *something* has to know the full set of selected bodies.
///
/// This used to be a list of tab providers imported by core, which put core
/// downstream of `lib/tabs/` and closed a 17-file import cycle (core → tabs →
/// core, via run_tab_calc → runner). Relocating that import would not have
/// fixed the real defect: a new body-selecting tab that forgot to register
/// itself silently produced a broken engine config.
///
/// So ownership is inverted rather than the import. Core *defines* the
/// selections; a tab consumes one by naming its enum value. A tab cannot own a
/// selection core does not see, because there is nowhere else to declare one —
/// which is what makes [selectedAsteroidMpcProvider] and
/// [selectedPlanetMoonIdsProvider] automatically correct for a tab added later
/// (swe-dashboard/85).
///
/// The value is uniformly `List<int>` of SE body ids so the aggregation can
/// fold over the whole registry; a single-body role (Nodes, Crossings,
/// Differential A/B, the Eclipses occultation planet) is a one-element list,
/// read back as a scalar through [singleBodyProvider].
///
/// **Deliberately outside the registry**: the Stars tab's `List<String>` star
/// names, the Eclipses occultation *star* name, and the Heliacal targets.
/// Those are names, not body ids, and they declare no Ephemeris Source files —
/// forcing them in would buy nothing and distort the type.
enum BodySelection {
  /// Planets tab body chips.
  planetsBodies('planets', 'bodies', BodyCatalog.classical),

  /// Other Bodies tab: moons, asteroids, comets. Empty until the user picks.
  otherBodies('otherBodies', 'bodies', <int>[]),

  /// Phenomena tab body chips.
  phenomenaBodies('phenomena', 'bodies', BodyCatalog.classical),

  /// Planetocentric tab: the target bodies observed from the center.
  planetocentricBodies('planetocentric', 'bodies', <int>[
    seMoon,
    seMercury,
    seVenus,
    seEarth,
    seMars,
    seJupiter,
    seSaturn,
  ]),

  /// Planetocentric tab: the center body (the observer).
  planetocentricCenter('planetocentric', 'center', <int>[seSun]),

  /// Nodes & Apsides tab: the single body whose nodes are computed.
  nodesApsidesBody('nodesApsides', 'body', <int>[seMoon]),

  /// Crossings tab: the body used for a heliocentric crossing.
  crossingsHelioBody('crossings', 'helioBody', <int>[seMars]),

  /// Differential tab: body A of the pair.
  differentialBodyA('differential', 'bodyA', <int>[seSun]),

  /// Differential tab: body B of the pair.
  differentialBodyB('differential', 'bodyB', <int>[seMoon]),

  /// Eclipses tab: the occulting/occulted planet (consulted only in
  /// occultation mode, but it declares its file either way).
  eclipsesOccultPlanet('eclipses', 'occultPlanet', <int>[seVenus]);

  const BodySelection(this.tab, this.role, this.initial);

  /// Which tab owns this selection.
  final String tab;

  /// Which role within that tab — several tabs hold more than one selection,
  /// so the tab alone is not an identity.
  final String role;

  /// The selection's value at startup. Body selections are not persisted.
  final List<int> initial;

  /// Stable `(tab, role)` id, for debugging and test failure messages.
  String get id => '$tab.$role';
}

/// The edit surface of one body selection.
///
/// The toggle/add/remove logic lived as a near-identical private method in six
/// tab files; a selection owns it now, so a picker is a chip row and nothing
/// else.
class BodySelectionNotifier extends StateNotifier<List<int>> {
  BodySelectionNotifier(this.selection) : super(selection.initial);

  final BodySelection selection;

  /// Replace the whole selection (chip presets, "select all").
  void setAll(Iterable<int> bodies) => state = List<int>.unmodifiable(bodies);

  /// Replace with a single body — the shape a single-body role uses.
  void setSingle(int body) => state = <int>[body];

  void add(int body) {
    if (!state.contains(body)) state = <int>[...state, body];
  }

  void remove(int body) => state = <int>[
    for (final b in state)
      if (b != body) b,
  ];

  void toggle(int body) => state.contains(body) ? remove(body) : add(body);

  void clear() => state = const <int>[];

  void reset() => state = selection.initial;
}

/// One selection's live value. Keyed by the registry enum, not a free-form
/// string: naming a selection core has not declared is a compile error.
final bodySelectionProvider =
    StateNotifierProvider.family<
      BodySelectionNotifier,
      List<int>,
      BodySelection
    >((ref, selection) => BodySelectionNotifier(selection));

/// A single-body selection read as a scalar.
///
/// Falls back to the selection's initial body if the list was emptied — a
/// single-body role has no "nothing selected" state to render, and the tabs
/// that use it index straight into the value.
final singleBodyProvider = Provider.family<int, BodySelection>((
  ref,
  selection,
) {
  final bodies = ref.watch(bodySelectionProvider(selection));
  if (bodies.isNotEmpty) return bodies.first;
  return selection.initial.first;
});

/// Every selected body id across the whole registry.
///
/// This fold is the point of the registry: it enumerates [BodySelection.values],
/// which the language guarantees is complete, instead of a hand-maintained list
/// of tab providers that a new tab could be missing from.
Iterable<int> _allSelectedBodies(Ref ref) sync* {
  for (final selection in BodySelection.values) {
    yield* ref.watch(bodySelectionProvider(selection));
  }
}

/// Planet moon body IDs (9000-9999) currently selected, filtered to only
/// those whose sat/ files are installed. swisseph_rs fails engine creation
/// if a declared file is missing.
final selectedPlanetMoonIdsProvider = Provider<List<int>>((ref) {
  final moons = <int>{
    for (final id in _allSelectedBodies(ref))
      if (id >= sePlmoonOffset && id < seAstOffset) id,
  };
  if (moons.isEmpty) return const [];
  final installed = _installedFilenames(ref);
  return moons.where((id) => installed.contains('sepm$id.se1')).toList();
});

/// Asteroid MPC numbers selected across all tabs, filtered to only those
/// whose files are installed. swisseph_rs fails engine creation if a
/// declared file is missing.
final selectedAsteroidMpcProvider = Provider<List<int>>((ref) {
  final mpcs = <int>{
    for (final id in _allSelectedBodies(ref))
      if (id >= seAstOffset) id - seAstOffset,
  };
  if (mpcs.isEmpty) return const [];
  final installed = _installedFilenames(ref);
  return mpcs.where((mpc) {
    final fn = asteroidFilenameFor(mpc);
    return installed.contains(fn);
  }).toList();
});

Set<String> _installedFilenames(Ref ref) {
  final scan = ref.watch(ephemerisScanProvider).valueOrNull;
  if (scan == null) return const {};
  return {
    for (final f in scan.files)
      if (f.status == EpheFileStatus.installed) f.filename,
  };
}
