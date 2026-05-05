import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../calc_context.dart';
import '../swe_service.dart';
import '../ephe/dir_provider.dart';
import 'applied_globals.dart';

class EphemerisRunner {
  EphemerisRunner(this._swe);

  final SwissEph _swe;
  AppliedGlobals? _last;

  T run<T>(AppliedGlobals globals, T Function(SwissEph eph) body) {
    if (_last != globals) {
      _apply(globals);
      _last = globals;
    }
    return body(_swe);
  }

  T runScoped<T>(
    void Function(SwissEph eph) override,
    T Function(SwissEph eph) body,
  ) {
    override(_swe);
    try {
      return body(_swe);
    } finally {
      if (_last != null) _apply(_last!);
    }
  }

  void _apply(AppliedGlobals g) {
    if (g.ephePath != null) _swe.setEphePath(g.ephePath!);
    if (g.sidMode != null) {
      if (g.sidMode == 255) {
        _swe.setSidMode(255, t0: g.userAyanT0, ayanT0: g.userAyanValue);
      } else {
        _swe.setSidMode(g.sidMode!);
      }
    }
    if (g.topo != null) {
      _swe.setTopo(g.topo!.lon, g.topo!.lat, g.topo!.alt);
    }
    if (g.jplFile != null) _swe.setJplFile(g.jplFile!);
  }
}

final ephemerisRunnerProvider = Provider<EphemerisRunner>((ref) {
  return EphemerisRunner(ref.watch(sweProvider));
});

final appliedGlobalsProvider = Provider<AppliedGlobals>((ref) {
  return AppliedGlobals.fromContext(
    ref.watch(effectiveContextProvider),
    ref.watch(resolvedEphePathProvider),
  );
});
