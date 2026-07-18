// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;

import '../calc_context.dart';
import '../context_state.dart';
import '../ephe/dir_provider.dart';
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
    _tracing.setEpheSource(_sourceMap[g.epheSource]!);
    if (g.ephePath != null) _tracing.setEphePath(g.ephePath!);
    if (g.sidMode != null) {
      if (g.sidMode == 255) {
        _tracing.setSidMode(255, t0: g.userAyanT0, ayanT0: g.userAyanValue);
      } else {
        _tracing.setSidMode(g.sidMode!);
      }
    }
    if (g.topo != null) {
      _tracing.setTopo(g.topo!.lon, g.topo!.lat, g.topo!.alt);
    }
    if (g.jplFile != null) _tracing.setJplFile(g.jplFile!);
  }

  void close() => _tracing.close();
}

final ephemerisRunnerProvider = Provider<EphemerisRunner>((ref) {
  final runner = EphemerisRunner();
  ref.onDispose(() => runner.close());
  return runner;
});

final appliedGlobalsProvider = Provider<AppliedGlobals>((ref) {
  return AppliedGlobals.fromContext(
    ref.watch(effectiveContextProvider),
    ref.watch(resolvedEphePathProvider),
  );
});
