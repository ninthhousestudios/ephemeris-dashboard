// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/swe_service.dart';

// ── Library info model ───────────────────────────────────────────────────────

class LibraryInfo {
  const LibraryInfo({
    required this.version,
    required this.ephePath,
    required this.bodies,
  });

  final String version;
  final String ephePath;
  final List<(int, String)> bodies;
}

// ── Provider ─────────────────────────────────────────────────────────────────

/// OFF-PATTERN by design (swe-dashboard/14): a library-metadata reader, not a
/// Calculation. Reads sweProvider for version/body-name strings only — no
/// Context dependency, no Applied Globals, no kernel, no trace. Kept as a plain
/// Provider.
final libraryInfoProvider = Provider<LibraryInfo>((ref) {
  final swe = ref.read(sweProvider);

  final version = swe.version();

  // Enumerate known bodies and their names.
  final bodies = <(int, String)>[];
  for (var i = 0; i <= 22; i++) {
    try {
      bodies.add((i, swe.getPlanetName(i)));
    } catch (_) {}
  }
  // Uranian fictitious bodies (40–48)
  for (var i = 40; i <= 48; i++) {
    try {
      bodies.add((i, swe.getPlanetName(i)));
    } catch (_) {}
  }

  return LibraryInfo(
    version: version,
    ephePath: bundledEphePath ?? 'none (Moshier mode)',
    bodies: bodies,
  );
});
