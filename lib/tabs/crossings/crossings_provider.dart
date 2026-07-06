import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/ephemeris/trace_model.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';

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

/// Body used for heliocentric crossing.
final crossingHelioBodyProvider = StateProvider<int>((ref) => seMars);

/// Direction: 1 = forward, -1 = backward (helioCross only).
final crossingDirProvider = StateProvider<int>((ref) => 1);

class CrossingResult {
  const CrossingResult({
    required this.crossingJd,
    required this.crossingDate,
    required this.crossingLongitude,
    required this.description,
  });

  /// Julian Day of the crossing.
  final double crossingJd;

  /// Human-readable date/time string.
  final String crossingDate;

  /// For moonNode: the longitude at which the crossing occurs; else null.
  final double? crossingLongitude;

  /// Short description of what was computed.
  final String description;
}

CrossingResult computeCrossing({
  required Ephemeris eph,
  required SwissEph swe,
  required double jdUt,
  required int iflag,
  required CrossingType type,
  required double longitude,
  required int helioBody,
  required int helioDir,
  required String helioBodyName,
  required double utcOffset,
}) {
  if (iflag & (seFlgHelCtr | seFlgBaryCtr) != 0) {
    throw SweException('Crossings require geocentric or topocentric origin', 0);
  }

  switch (type) {
    case CrossingType.sunCross:
      final jd = eph.solCrossUt(longitude, jdUt, iflag);
      return CrossingResult(
        crossingJd: jd,
        crossingDate: formatJdDateTime(swe, jd, utcOffset: utcOffset),
        crossingLongitude: null,
        description: 'Sun crosses ${longitude.toStringAsFixed(4)}°',
      );

    case CrossingType.moonCross:
      final jd = eph.moonCrossUt(longitude, jdUt, iflag);
      return CrossingResult(
        crossingJd: jd,
        crossingDate: formatJdDateTime(swe, jd, utcOffset: utcOffset),
        crossingLongitude: null,
        description: 'Moon crosses ${longitude.toStringAsFixed(4)}°',
      );

    case CrossingType.moonNode:
      final r = eph.moonCrossNodeUt(jdUt, iflag);
      return CrossingResult(
        crossingJd: r.jdUt,
        crossingDate: formatJdDateTime(swe, r.jdUt, utcOffset: utcOffset),
        crossingLongitude: r.longitude,
        description: 'Moon crosses node',
      );

    case CrossingType.helioCross:
      final jd = eph.helioCrossUt(helioBody, longitude, jdUt, iflag, helioDir);
      return CrossingResult(
        crossingJd: jd,
        crossingDate: formatJdDateTime(swe, jd, utcOffset: utcOffset),
        crossingLongitude: null,
        description:
            '$helioBodyName helio crosses ${longitude.toStringAsFixed(4)}° '
            '(${helioDir == 1 ? 'forward' : 'backward'})',
      );
  }
}

final _crossingCalcProvider =
    Provider<({CalcOutcome<CrossingResult> outcome, CallTrace trace})>((ref) {
      final ctx = ref.watch(contextBarProvider);
      final flags = ref.watch(flagBarProvider);
      final swe = ref.read(sweProvider);
      final type = ref.watch(crossingTypeProvider);
      final lon = ref.watch(crossingLonProvider);
      final helioBody = ref.watch(crossingHelioBodyProvider);
      final dir = ref.watch(crossingDirProvider);

      return runTabCalc(
        ref,
        tabTag: 'crossings',
        compute: (eph) => computeCrossing(
          eph: eph,
          jdUt: ctx.jdUt,
          iflag: flags.iflag,
          type: type,
          longitude: lon,
          helioBody: helioBody,
          helioDir: dir,
          helioBodyName: safeGetName(swe, helioBody),
          swe: swe,
          utcOffset: ctx.utcOffset,
        ),
      );
    });

final crossingResultProvider = Provider<CalcOutcome<CrossingResult>>((ref) {
  return ref.watch(_crossingCalcProvider.select((c) => c.outcome));
});

final crossingTraceProvider = Provider<CallTrace>((ref) {
  return ref.watch(_crossingCalcProvider.select((c) => c.trace));
});

List<ExportRow> crossingToExportRows(CrossingResult result) {
  return [
    ExportRow(
      header: result.description,
      fields: [
        (
          'JD (UT)',
          result.crossingJd.isNaN
              ? 'NaN'
              : result.crossingJd.toStringAsFixed(6),
        ),
        ('Date/Time', result.crossingDate),
        if (result.crossingLongitude != null)
          (
            'Node Longitude',
            '${result.crossingLongitude!.toStringAsFixed(6)}°',
          ),
      ],
    ),
  ];
}
