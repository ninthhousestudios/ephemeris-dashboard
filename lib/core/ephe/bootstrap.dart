// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// The only conditional import in this module, and the only name that has to
// exist on both sides: `stageEpheSource`. Its return type is checked at the
// call site below, so a drifting stub is a compile error rather than a
// runtime surprise.
import 'staging_io.dart'
    if (dart.library.js_interop) 'staging_web.dart'
    as staging;

/// A staging step that tried to do its job and could not — as distinct from
/// one that looked and found nothing.
///
/// The distinction is the whole point. A *miss* is how staging normally
/// narrows down: most probes miss on any given platform, and a build that
/// legitimately ships no `.se1` files misses every one of them. A *failure*
/// means something is broken — a corrupt package config, an asset that would
/// not extract — and a silent Moshier fallback would hide it.
@immutable
class StagingFailure {
  const StagingFailure(this.probeName, this.message);

  /// The probe's [EpheProbe.name], so the report says which step broke.
  final String probeName;

  final String message;

  @override
  String toString() => '$probeName: $message';
}

/// Everything startup resolved about where the Ephemeris Source files live.
///
/// Produced once by [bootstrapEpheSource] before `runApp`, then installed as
/// a value via [epheBootstrapProvider]. Replaces the module-level mutable
/// globals (and their invisible must-init-first ordering) that this used to
/// flow through.
@immutable
class EpheBootstrap {
  const EpheBootstrap({
    required this.bundledPath,
    required this.managedPath,
    required this.webFilenames,
    this.failures = const [],
  });

  /// No ephemeris files anywhere and nothing broken — every probe simply
  /// missed. The engine falls back to Moshier, by design rather than by
  /// accident. Contrast [stagingFailed].
  const EpheBootstrap.none()
    : bundledPath = null,
      managedPath = null,
      webFilenames = const [],
      failures = const [];

  /// The staged read-only directory the app ships (native), or the MEMFS
  /// root the `.se1` files were loaded into (web). Null when nothing was
  /// found, which is the Moshier-only case.
  final String? bundledPath;

  /// The writable `<appSupport>/ephe` directory, seeded from [bundledPath]
  /// on first launch. Null on web, or if resolution failed. This is what the
  /// Ephemeris Manager downloads into.
  final String? managedPath;

  /// Filenames loaded into MEMFS. Web only; always empty on native, where
  /// the scanner reads the directory instead.
  final List<String> webFilenames;

  /// Staging steps that broke, in probe order. Empty is the normal case —
  /// including a build that legitimately ships no ephemeris files, where
  /// every probe merely missed.
  final List<StagingFailure> failures;

  /// Whether `.se1` files are available at all. When false the Context is
  /// pinned to Moshier.
  ///
  /// False does *not* imply healthy: check [stagingFailed] to tell "this
  /// build ships no ephemeris files" from "staging broke".
  bool get hasEpheFiles => bundledPath != null;

  /// Whether some staging step broke, as opposed to legitimately finding
  /// nothing. Independent of [hasEpheFiles]: an earlier probe can fail and a
  /// later one still succeed, which is a working app with a real problem.
  bool get stagingFailed => failures.isNotEmpty;
}

/// The startup bootstrap result. Overridden in `main()` with the value from
/// [bootstrapEpheSource]; there is no default, so a scope that forgets the
/// override fails loudly instead of silently reporting "no ephemeris files".
final epheBootstrapProvider = Provider<EpheBootstrap>((ref) {
  throw UnimplementedError('epheBootstrapProvider must be overridden');
});

/// Resolve or stage the ephemeris data files (`.se1` + `sefstars.txt`) into a
/// directory the engine can read, and seed the writable managed directory
/// from it. Call once from `main()` before `runApp`.
///
/// - **Web:** loads the WASM module and stages bundled files into MEMFS.
/// - **Native:** walks the platform's probe plan (see `probes.dart`), then
///   seeds `<appSupport>/ephe` from whatever it found.
///
/// Never throws: a failure to stage is reported as an [EpheBootstrap] with no
/// paths, which the app renders as Moshier mode.
Future<EpheBootstrap> bootstrapEpheSource() => staging.stageEpheSource();
