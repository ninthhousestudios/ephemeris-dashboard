import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/ephemeris/trace_model.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
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

String _formatDateResult(DateResult r, double utcOffset) {
  final y = r.year;
  final mo = r.month.toString().padLeft(2, '0');
  final d = r.day.toString().padLeft(2, '0');
  final totalSec = (r.hour * 3600).round();
  final hh = (totalSec ~/ 3600).toString().padLeft(2, '0');
  final mm = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (totalSec % 60).toString().padLeft(2, '0');
  final utStr = '$y-$mo-$d $hh:$mm:$ss UT';
  if (utcOffset == 0.0) return utStr;
  final utcDt = DateTime.utc(
    r.year,
    r.month,
    r.day,
    totalSec ~/ 3600,
    (totalSec % 3600) ~/ 60,
    totalSec % 60,
  );
  final local = utcDt.add(Duration(minutes: (utcOffset * 60).round()));
  final sign = utcOffset >= 0 ? '+' : '';
  final offsetStr = utcOffset == utcOffset.roundToDouble()
      ? '$sign${utcOffset.round()}'
      : '$sign${utcOffset.toStringAsFixed(1)}';
  return '$utStr  (${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')} UTC$offsetStr)';
}

CrossingResult computeCrossing({
  required Ephemeris eph,
  required double jdUt,
  required int iflag,
  required CrossingType type,
  required double longitude,
  required int helioBody,
  required int helioDir,
  required String helioBodyName,
  required DateResult Function(double) revjul,
  required double utcOffset,
}) {
  switch (type) {
    case CrossingType.sunCross:
      final jd = eph.solCrossUt(longitude, jdUt, iflag);
      return CrossingResult(
        crossingJd: jd,
        crossingDate: _formatDateResult(revjul(jd), utcOffset),
        crossingLongitude: null,
        description: 'Sun crosses ${longitude.toStringAsFixed(4)}°',
      );

    case CrossingType.moonCross:
      final jd = eph.moonCrossUt(longitude, jdUt, iflag);
      return CrossingResult(
        crossingJd: jd,
        crossingDate: _formatDateResult(revjul(jd), utcOffset),
        crossingLongitude: null,
        description: 'Moon crosses ${longitude.toStringAsFixed(4)}°',
      );

    case CrossingType.moonNode:
      final r = eph.moonCrossNodeUt(jdUt, iflag);
      return CrossingResult(
        crossingJd: r.jdUt,
        crossingDate: _formatDateResult(revjul(r.jdUt), utcOffset),
        crossingLongitude: r.longitude,
        description: 'Moon crosses node',
      );

    case CrossingType.helioCross:
      final jd = eph.helioCrossUt(helioBody, longitude, jdUt, iflag, helioDir);
      return CrossingResult(
        crossingJd: jd,
        crossingDate: _formatDateResult(revjul(jd), utcOffset),
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
          revjul: swe.revjul,
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
