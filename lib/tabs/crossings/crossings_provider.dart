import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/context_provider.dart';
import '../../core/export_service.dart';
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
  // hour field is fractional — split into h/m/s
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

final crossingResultProvider = Provider<CrossingResult?>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('crossings')) return null;

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  runner.setTabTag('crossings');
  final swe = ref.read(sweProvider);
  final type = ref.watch(crossingTypeProvider);
  final lon = ref.watch(crossingLonProvider);
  final helioBody = ref.watch(crossingHelioBodyProvider);
  final dir = ref.watch(crossingDirProvider);
  final utcOffset = ref.watch(contextBarProvider).utcOffset;

  try {
    switch (type) {
      case CrossingType.sunCross:
        final jd = runner.run(
          globals,
          (eph) => eph.solCrossUt(lon, ectx.jdUt, ectx.iflag),
        );
        final date = _formatDateResult(swe.revjul(jd), utcOffset);
        return CrossingResult(
          crossingJd: jd,
          crossingDate: date,
          crossingLongitude: null,
          description: 'Sun crosses ${lon.toStringAsFixed(4)}°',
        );

      case CrossingType.moonCross:
        final jd = runner.run(
          globals,
          (eph) => eph.moonCrossUt(lon, ectx.jdUt, ectx.iflag),
        );
        final date = _formatDateResult(swe.revjul(jd), utcOffset);
        return CrossingResult(
          crossingJd: jd,
          crossingDate: date,
          crossingLongitude: null,
          description: 'Moon crosses ${lon.toStringAsFixed(4)}°',
        );

      case CrossingType.moonNode:
        final r = runner.run(
          globals,
          (eph) => eph.moonCrossNodeUt(ectx.jdUt, ectx.iflag),
        );
        final date = _formatDateResult(swe.revjul(r.jdUt), utcOffset);
        return CrossingResult(
          crossingJd: r.jdUt,
          crossingDate: date,
          crossingLongitude: r.longitude,
          description: 'Moon crosses node',
        );

      case CrossingType.helioCross:
        final bodyName = _safeGetName(swe, helioBody);
        final jd = runner.run(
          globals,
          (eph) => eph.helioCrossUt(helioBody, lon, ectx.jdUt, ectx.iflag, dir),
        );
        final date = _formatDateResult(swe.revjul(jd), utcOffset);
        return CrossingResult(
          crossingJd: jd,
          crossingDate: date,
          crossingLongitude: null,
          description:
              '$bodyName helio crosses ${lon.toStringAsFixed(4)}° (${dir == 1 ? 'forward' : 'backward'})',
        );
    }
  } on SweException catch (e) {
    return CrossingResult(
      crossingJd: double.nan,
      crossingDate: 'Error',
      crossingLongitude: null,
      description: e.message,
    );
  }
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

String _safeGetName(SwissEph swe, int body) {
  try {
    return swe.getPlanetName(body);
  } catch (_) {
    return 'Body $body';
  }
}
