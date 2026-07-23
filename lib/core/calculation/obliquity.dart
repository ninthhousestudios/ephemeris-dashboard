// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ephemeris/ephemeris.dart';
import '../flag_provider.dart';
import '../swe_constants.dart';
import 'calc_outcome.dart';
import 'house_pos.dart';
import 'run_tab_calc.dart';

/// Obliquity of the ecliptic and nutation for one Moment, from the SE_ECL_NUT
/// pseudo-body (swetest -p o/n).
typedef ObliquityNutation = ({
  /// True obliquity in degrees (SE_ECL_NUT xx[0]).
  double trueObliquity,

  /// Mean obliquity in degrees (SE_ECL_NUT xx[1]).
  double meanObliquity,

  /// Nutation in longitude in degrees (SE_ECL_NUT xx[2]).
  double nutationLongitude,

  /// Nutation in obliquity in degrees (SE_ECL_NUT xx[3]).
  double nutationObliquity,
});

/// Computes obliquity and nutation at [jdUt]. The frame flags are stripped from
/// [iflag] so only the ephemeris source selects the model; the four SE_ECL_NUT
/// outputs land in xx[0..3], which RustEph maps to lon/lat/dist/lonSpeed.
ObliquityNutation computeObliquityNutation(
  Ephemeris eph,
  double jdUt,
  int iflag,
) {
  final r = eph.calcUt(jdUt, seEclNut, tropicalEclipticFlag(iflag));
  return (
    trueObliquity: r.longitude,
    meanObliquity: r.latitude,
    nutationLongitude: r.distance,
    nutationObliquity: r.longitudeSpeed,
  );
}

/// Obliquity and nutation for the Context Moment, independent of any per-tab
/// date override. Tabs that want a default obliquity (e.g. the Coordinates
/// Ecl↔Equ transform) read this rather than the Dates tab's result, whose JD
/// can carry the Dates tab's local override — invisible from another tab.
final contextObliquityProvider = Provider<CalcOutcome<ObliquityNutation>>((
  ref,
) {
  final flags = ref.watch(flagBarProvider);
  return runTabCalc(
    ref,
    compute: (eph, moment) =>
        computeObliquityNutation(eph, moment.ut, flags.iflag),
  );
});
