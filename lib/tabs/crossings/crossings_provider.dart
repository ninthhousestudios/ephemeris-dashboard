// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';
import '../../core/body_selection.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/jd_utils.dart';
import '../../core/output_clock.dart';
import '../../core/sign_names.dart';
import '../../core/swe_utils_provider.dart';
import '../../core/swe_utils.dart';
import '../../core/true_sidereal.dart';

enum CrossingType {
  sunCross('Sun crosses longitude'),
  moonCross('Moon crosses longitude'),
  moonNode('Moon node crossing'),
  helioCross('Heliocentric crossing');

  const CrossingType(this.label);
  final String label;
}

/// Which crossing type to compute.
final crossingTypeProvider = StateProvider<CrossingType>(
  (ref) => CrossingType.sunCross,
);

/// Target longitude in degrees (0–360).
final crossingLonProvider = StateProvider<double>((ref) => 0.0);

/// Direction: 1 = forward (next crossing), -1 = backward (previous crossing).
/// Applies to all four crossing types.
final crossingDirProvider = StateProvider<int>((ref) => 1);

// swisseph's sol/moon/node crossings search forward only. The previous crossing
// is two forward searches: find the next crossing, then search forward again
// from one period-with-margin before it — with P < margin < 2P the window
// (next - margin, next) holds exactly the immediately-previous event. These
// margins are app policy (the periodicity of each body), deliberately kept here
// and not pushed into the Ephemeris seam, which stays a faithful mirror of
// swisseph_rs (forward-only for these; only helioCross has a native direction).
const _sunBackMargin = 370.0; // tropical year ~365.24d
const _moonBackMargin = 30.0; // sidereal month ~27.32d
const _nodeBackMargin = 16.0; // successive node crossings ~13.6d apart

/// Previous crossing for a scalar (sol/moon) forward search [nextFrom]:
/// the next crossing, then a second forward search one period-with-[margin]
/// before it. Propagates NaN (no event) without a second search.
double _prevScalarCrossing(
  double Function(double startJd) nextFrom,
  double jdUt,
  double margin,
) {
  final next = nextFrom(jdUt);
  if (next.isNaN) return next;
  return nextFrom(next - margin);
}

class CrossingResult {
  const CrossingResult({
    required this.crossingJd,
    required this.crossingDate,
    required this.crossingLongitude,
    required this.description,
    required this.jdFieldLabel,
    required this.jdFieldValue,
    required this.jdOnScale,
  });

  /// Canonical UT1 Julian Day of the crossing (NaN when no event was found).
  final double crossingJd;

  /// Human-readable date/time string, on the Context's Scale/Calendar/clock.
  final String crossingDate;

  /// For moonNode: the longitude at which the crossing occurs; else null.
  final double? crossingLongitude;

  /// Short description of what was computed.
  final String description;

  /// The bare-JD field's label (`JD UT1` / `JD TT`) and value, both on the
  /// Context's Scale so the number matches [crossingDate] beside it rather than
  /// sitting on UT1 while the date-time reads in TT. Built once here (the sole
  /// site with the Scale + engine) so the card and the export cannot drift.
  final String jdFieldLabel;
  final String jdFieldValue;

  /// The scale-shifted JD as a number, for a [ResultField.rawValue].
  final double? jdOnScale;
}

CrossingResult computeCrossing({
  required Ephemeris eph,
  required SweUtils swe,
  required double jdUt,
  required int iflag,
  required CrossingType type,
  required double longitude,
  required int helioBody,
  required int dir,
  required String helioBodyName,
  required ClockView view,
}) {
  if (type != CrossingType.helioCross &&
      iflag & (seFlgHelCtr | seFlgBaryCtr) != 0) {
    throw const InvalidArgException(
      'Crossings require geocentric or topocentric origin',
    );
  }

  CrossingResult build(
    double jd, {
    double? crossingLongitude,
    required String description,
  }) {
    final f = jdScaleField(swe, jd, scale: view.scale, digits: 6);
    return CrossingResult(
      crossingJd: jd,
      crossingDate: formatJdDateTime(swe, jd, view: view),
      crossingLongitude: crossingLongitude,
      description: description,
      jdFieldLabel: f.label,
      jdFieldValue: f.value,
      jdOnScale: f.onScale,
    );
  }

  final dirWord = dir == 1 ? 'forward' : 'backward';

  switch (type) {
    case CrossingType.sunCross:
      final jd = dir == 1
          ? eph.solCrossUt(longitude, jdUt, iflag)
          : _prevScalarCrossing(
              (s) => eph.solCrossUt(longitude, s, iflag),
              jdUt,
              _sunBackMargin,
            );
      return build(
        jd,
        description: 'Sun crosses ${longitude.toStringAsFixed(4)}° ($dirWord)',
      );

    case CrossingType.moonCross:
      final jd = dir == 1
          ? eph.moonCrossUt(longitude, jdUt, iflag)
          : _prevScalarCrossing(
              (s) => eph.moonCrossUt(longitude, s, iflag),
              jdUt,
              _moonBackMargin,
            );
      return build(
        jd,
        description: 'Moon crosses ${longitude.toStringAsFixed(4)}° ($dirWord)',
      );

    case CrossingType.moonNode:
      var r = eph.moonCrossNodeUt(jdUt, iflag);
      if (dir == -1 && !r.jdUt.isNaN) {
        r = eph.moonCrossNodeUt(r.jdUt - _nodeBackMargin, iflag);
      }
      return build(
        r.jdUt,
        crossingLongitude: r.longitude,
        description: 'Moon crosses node ($dirWord)',
      );

    case CrossingType.helioCross:
      return build(
        eph.helioCrossUt(helioBody, longitude, jdUt, iflag, dir),
        description:
            '$helioBodyName helio crosses ${longitude.toStringAsFixed(4)}° '
            '($dirWord)',
      );
  }
}

final _crossingCalcProvider = Provider<CalcOutcome<CrossingResult>>((ref) {
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final view = ref.watch(clockViewProvider);
  final type = ref.watch(crossingTypeProvider);
  final lon = ref.watch(crossingLonProvider);
  final helioBody = ref.watch(
    singleBodyProvider(BodySelection.crossingsHelioBody),
  );
  final dir = ref.watch(crossingDirProvider);

  return runTabCalc(
    ref,
    compute: (eph, moment) => computeCrossing(
      eph: eph,
      jdUt: moment.ut,
      iflag: flags.iflag,
      type: type,
      longitude: lon,
      helioBody: helioBody,
      dir: dir,
      helioBodyName: safeGetName(swe, helioBody),
      swe: swe,
      view: view,
    ),
  );
});

final crossingResultProvider = Provider<CalcOutcome<CrossingResult>>((ref) {
  return ref.watch(_crossingCalcProvider);
});

List<ExportRow> crossingToExportRows(
  CrossingResult result, {
  SignScheme scheme = SignScheme.none,
  UserSignSet? signSet,
  TrueSiderealBinning? binning,
}) {
  final lon = result.crossingLongitude;
  // No display-format selector on this tab: longitude is fixed decimal degrees,
  // and the in-sign line matches ([DisplayFormat.decimal]).
  final signField = lon == null
      ? null
      : inSignField(lon, 0, scheme, signSet, DisplayFormat.decimal, binning);
  return [
    ExportRow(
      header: result.description,
      fields: [
        (result.jdFieldLabel, result.jdFieldValue),
        ('Date/Time', result.crossingDate),
        if (lon != null) ('Node Longitude', '${lon.toStringAsFixed(6)}°'),
        ?signField,
      ],
    ),
  ];
}
