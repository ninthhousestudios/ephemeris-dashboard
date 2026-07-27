// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/foundation.dart';

/// Bump when the bundled ephemeris data changes — a mismatch against the
/// `.version` file in the extraction target forces a re-extract.
const String epheAssetVersion = '0.4.3';

/// The platform facts the probe order depends on.
///
/// Passed in rather than read from `Platform` directly so [nativeEpheProbes]
/// stays a pure function: the ordering policy can be asserted for every
/// platform from a single test process.
typedef PlatformFacts = ({
  bool isMacOS,
  bool isLinux,
  bool isWindows,
  bool isAndroid,
  bool isIOS,

  /// Directory containing the running executable.
  String exeDir,

  /// Current working directory.
  String cwd,
});

/// One strategy for locating a readable ephemeris directory, tried in order
/// until one yields a directory that holds at least one `.se1` file.
///
/// Splitting the strategies into types keeps the *ordering* (which platform
/// tries what, and in what sequence) separable from the *execution* (which
/// needs `dart:io`). The order is decided by [nativeEpheProbes]; the doing
/// lives in `staging_io.dart`.
@immutable
sealed class EpheProbe {
  const EpheProbe(this.name);

  /// Human-readable label, surfaced in diagnostics and test failures.
  final String name;
}

/// Look for an already-staged directory at a fixed [path].
final class DirectoryProbe extends EpheProbe {
  const DirectoryProbe(super.name, this.path);

  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectoryProbe && name == other.name && path == other.path;

  @override
  int get hashCode => Object.hash(name, path);
}

/// Read `.dart_tool/package_config.json` and use the `swisseph_rs` package's
/// own `ephe/` directory. Dev-mode only — there is no package config in a
/// release bundle.
final class PackageConfigProbe extends EpheProbe {
  const PackageConfigProbe() : super('swisseph_rs pub cache (dev mode)');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PackageConfigProbe;

  @override
  int get hashCode => (PackageConfigProbe).hashCode;
}

/// Copy the bundled `assets/ephe/` into the app support directory and use
/// that. Unlike the other probes this one *creates* its target, so it only
/// ever appears last: it always succeeds when assets are present.
///
/// Used on mobile, and on macOS because a signed app bundle cannot carry
/// loose `.se1` files past codesign.
final class AssetExtractionProbe extends EpheProbe {
  const AssetExtractionProbe() : super('extract bundled assets to app support');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AssetExtractionProbe;

  @override
  int get hashCode => (AssetExtractionProbe).hashCode;
}

/// The ordered probe plan for a native platform.
///
/// Pure: no filesystem access, no `Platform` reads. Execution is
/// `stageEpheSource` in `staging_io.dart`, which walks this list and takes
/// the first probe that yields a valid directory.
List<EpheProbe> nativeEpheProbes(PlatformFacts facts) => [
  // Release bundle: ephe/ shipped next to the executable. macOS is excluded
  // — it extracts to app support instead so the .se1 files live outside the
  // signed bundle.
  if (!facts.isMacOS) ...[
    DirectoryProbe('release bundle (CMake)', '${facts.exeDir}/data/ephe'),
    DirectoryProbe(
      'release bundle (flutter_assets)',
      '${facts.exeDir}/data/flutter_assets/assets/ephe',
    ),
  ],

  // Desktop dev mode. macOS is excluded here too: the app sandbox blocks
  // reads of the CWD and .dart_tool/ anyway.
  if (facts.isLinux || facts.isWindows) ...[
    DirectoryProbe('project assets (dev mode)', '${facts.cwd}/assets/ephe'),
    const PackageConfigProbe(),
  ],

  if (facts.isAndroid || facts.isIOS || facts.isMacOS)
    const AssetExtractionProbe(),
];
