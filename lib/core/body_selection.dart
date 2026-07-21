// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'swe_constants.dart';
import 'ephe/catalog.dart';
import 'ephe/scanner.dart';
import 'ephe/types.dart';
import '../tabs/phenomena/phenomena_provider.dart' show phenomenaBodiesProvider;
import '../tabs/table_view/table_view_provider.dart'
    show tableViewExtraBodiesProvider;

/// Planet bodies selected on the Planets tab.
final selectedBodiesProvider = StateProvider<List<int>>(
  (ref) => [seSun, seMoon, seMercury, seVenus, seMars, seJupiter, seSaturn],
);

/// Bodies selected on the Other Bodies tab.
final otherBodiesSelectionProvider = StateProvider<List<int>>((ref) => <int>[]);

/// Planet moon body IDs (9000-9999) currently selected, filtered to only
/// those whose sat/ files are installed. swisseph_rs fails engine creation
/// if a declared file is missing.
final selectedPlanetMoonIdsProvider = Provider<List<int>>((ref) {
  final otherBodies = ref.watch(otherBodiesSelectionProvider);
  final phenomenaBodies = ref.watch(phenomenaBodiesProvider);
  final tableExtra = ref.watch(tableViewExtraBodiesProvider);
  final all = {...otherBodies, ...phenomenaBodies, ...tableExtra};
  final moons = all.where((id) => id >= sePlmoonOffset && id < seAstOffset);
  if (moons.isEmpty) return const [];
  final installed = _installedFilenames(ref);
  return moons.where((id) => installed.contains('sepm$id.se1')).toList();
});

/// Asteroid MPC numbers selected across all tabs, filtered to only those
/// whose files are installed. swisseph_rs fails engine creation if a
/// declared file is missing.
final selectedAsteroidMpcProvider = Provider<List<int>>((ref) {
  final planetsBodies = ref.watch(selectedBodiesProvider);
  final otherBodies = ref.watch(otherBodiesSelectionProvider);
  final phenomenaBodies = ref.watch(phenomenaBodiesProvider);
  final tableExtra = ref.watch(tableViewExtraBodiesProvider);
  final mpcs = <int>{};
  for (final id in [
    ...planetsBodies,
    ...otherBodies,
    ...phenomenaBodies,
    ...tableExtra,
  ]) {
    if (id >= seAstOffset) mpcs.add(id - seAstOffset);
  }
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
