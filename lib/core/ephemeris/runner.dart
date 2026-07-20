// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calc_context.dart';
import '../context_state.dart';
import '../ephe/dir_provider.dart';
import '../ephe/scanner.dart';
import '../ephe/types.dart';
import '../body_selection.dart';
import 'applied_globals.dart';
import 'trace_model.dart';
import 'tracing_rust_eph.dart';

class EphemerisRunner {
  EphemerisRunner() : _tracing = TracingRustEph();

  final TracingRustEph _tracing;
  AppliedGlobals? _last;

  List<CallEntry> get traceEntries => _tracing.entries;
  void setTabTag(String tag) => _tracing.setTabTag(tag);

  void apply(AppliedGlobals globals) {
    if (_last != globals) {
      _tracing.reconfigure(globals.toEphemerisConfig());
      _last = globals;
    }
  }

  TracingRustEph get tracing => _tracing;

  void close() => _tracing.close();
}

final ephemerisRunnerProvider = Provider<EphemerisRunner>((ref) {
  final runner = EphemerisRunner();
  ref.onDispose(() => runner.close());
  return runner;
});

final appliedGlobalsProvider = Provider<AppliedGlobals>((ref) {
  final ctx = ref.watch(effectiveContextProvider);
  final ephePath = ref.watch(resolvedEphePathProvider);
  final moonIds = ref.watch(selectedPlanetMoonIdsProvider);
  final asteroidMpcs = ref.watch(selectedAsteroidMpcProvider);
  var globals = AppliedGlobals.fromContext(
    ctx,
    ephePath,
    asteroidNumbers: asteroidMpcs,
    planetMoonNumbers: moonIds,
  );
  if (globals.epheSource == EpheSource.jpl && globals.jplFile == null) {
    final scan = ref.watch(ephemerisScanProvider).valueOrNull;
    if (scan != null) {
      final jplFiles = scan.files.where(
        (f) =>
            f.family == BodyFamily.jpl && f.status == EpheFileStatus.installed,
      );
      if (jplFiles.isNotEmpty) {
        globals = AppliedGlobals(
          ephePath: globals.ephePath,
          epheSource: globals.epheSource,
          sidMode: globals.sidMode,
          userAyanT0: globals.userAyanT0,
          userAyanValue: globals.userAyanValue,
          topo: globals.topo,
          jplFile: jplFiles.first.filename,
          asteroidNumbers: globals.asteroidNumbers,
          planetMoonNumbers: globals.planetMoonNumbers,
        );
      }
    }
  }
  return globals;
});
