// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;

import '../calc_context.dart';
import '../context_state.dart';
import '../ephe/dir_provider.dart';
import '../ephe/scanner.dart';
import '../ephe/types.dart';
import 'applied_globals.dart';
import 'ephemeris.dart';
import 'trace_model.dart';
import 'tracing_rust_eph.dart';

class EphemerisRunner {
  EphemerisRunner() : _tracing = TracingRustEph();

  final TracingRustEph _tracing;
  AppliedGlobals? _last;

  List<CallEntry> get traceEntries => _tracing.entries;
  void setTabTag(String tag) => _tracing.setTabTag(tag);

  rs.Ephemeris get engine => _tracing.engine;

  T run<T>(AppliedGlobals globals, T Function(Ephemeris eph) body) {
    if (_last != globals) {
      _apply(globals);
      _last = globals;
    }
    return body(_tracing);
  }

  T runScoped<T>(
    void Function(Ephemeris eph) override,
    T Function(Ephemeris eph) body,
  ) {
    override(_tracing);
    try {
      return body(_tracing);
    } finally {
      if (_last != null) _apply(_last!);
    }
  }

  static const _sourceMap = {
    EpheSource.moshier: rs.EphemerisSource.moshier,
    EpheSource.swissEph: rs.EphemerisSource.swiss,
    EpheSource.jpl: rs.EphemerisSource.jpl,
  };

  void _apply(AppliedGlobals g) {
    _tracing.applyGlobals(
      source: _sourceMap[g.epheSource]!,
      ephePath: g.ephePath,
      jplFile: g.jplFile,
      sidMode: g.sidMode,
      userAyanT0: g.userAyanT0,
      userAyanValue: g.userAyanValue,
      topo: g.topo,
    );
  }

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
  var globals = AppliedGlobals.fromContext(ctx, ephePath);
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
        );
      }
    }
  }
  return globals;
});
