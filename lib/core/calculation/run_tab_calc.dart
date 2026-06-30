import 'package:swisseph/swisseph.dart';

import '../ephemeris/applied_globals.dart';
import '../ephemeris/ephemeris.dart';
import '../ephemeris/runner.dart';
import 'calc_outcome.dart';

/// Owns the tab-tag -> apply-globals -> execute -> envelope wiring shared
/// by every tab's calculation provider. Synchronous by construction.
CalcOutcome<T> runTabCalc<T>({
  required EphemerisRunner runner,
  required AppliedGlobals globals,
  required String tabTag,
  required T Function(Ephemeris eph) compute,
}) {
  runner.setTabTag(tabTag);
  try {
    return CalcOk(runner.run(globals, compute));
  } on SweException catch (e) {
    return CalcSweError(e.message);
  }
}
