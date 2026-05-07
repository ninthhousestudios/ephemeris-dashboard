import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/export_service.dart';
import '../../widgets/result_card.dart';

// ── Operation enum ─────────────────────────────────────────────────────────

enum CoordOp {
  azAlt('Az/Alt', 'Ecliptic → Horizontal'),
  azAltRev('Az/Alt Rev', 'Horizontal → Ecliptic'),
  cotrans('CoTrans', 'Ecliptic ↔ Equatorial'),
  refrac('Refraction', 'Atmospheric refraction');

  const CoordOp(this.label, this.description);
  final String label;
  final String description;
}

// ── UI state providers ─────────────────────────────────────────────────────

final coordOpProvider = StateProvider<CoordOp>((ref) => CoordOp.azAlt);
final coordFormatProvider =
    StateProvider<DisplayFormat>((ref) => DisplayFormat.dms);


// ── Input providers (committed on Calculate) ───────────────────────────────

// Shared angular input fields (lon/lat/dist used by azAlt, azAltRev, cotrans)
final coordLonProvider = StateProvider<double>((ref) => 0.0);
final coordLatProvider = StateProvider<double>((ref) => 0.0);
final coordDistProvider = StateProvider<double>((ref) => 1.0);

// azAlt / refrac atmospheric inputs
final coordAtpressProvider = StateProvider<double>((ref) => 1013.25);
final coordAttempProvider = StateProvider<double>((ref) => 15.0);

// azAltRev inputs
final coordAzimuthProvider = StateProvider<double>((ref) => 0.0);
final coordAltitudeProvider = StateProvider<double>((ref) => 0.0);

// cotrans obliquity
final coordEpsProvider = StateProvider<double>((ref) => 23.4393);

// ── Result sealed variants ─────────────────────────────────────────────────

sealed class CoordResult {}

class CoordAzAltResult extends CoordResult {
  CoordAzAltResult(this.azimuth, this.trueAltitude, this.apparentAltitude);
  final double azimuth;
  final double trueAltitude;
  final double apparentAltitude;
}

class CoordAzAltRevResult extends CoordResult {
  CoordAzAltRevResult(this.lon, this.lat);
  final double lon;
  final double lat;
}

class CoordCoTransResult extends CoordResult {
  CoordCoTransResult(this.lon, this.lat, this.dist, this.direction);
  final double lon;
  final double lat;
  final double dist;
  // 'ecl→equ' or 'equ→ecl'
  final String direction;
}

class CoordRefracResult extends CoordResult {
  CoordRefracResult(this.inputAlt, this.outputAlt, this.description);
  final double inputAlt;
  final double outputAlt;
  final String description;
}

class CoordErrorResult extends CoordResult {
  CoordErrorResult(this.message);
  final String message;
}

// ── Computation provider ───────────────────────────────────────────────────

final coordResultProvider = Provider<CoordResult?>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('coordinates')) return null;

  final op = ref.watch(coordOpProvider);
  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  runner.setTabTag('coordinates');

  final lon = ref.watch(coordLonProvider);
  final lat = ref.watch(coordLatProvider);
  final dist = ref.watch(coordDistProvider);
  final atpress = ref.watch(coordAtpressProvider);
  final attemp = ref.watch(coordAttempProvider);
  final azimuth = ref.watch(coordAzimuthProvider);
  final altitude = ref.watch(coordAltitudeProvider);
  final eps = ref.watch(coordEpsProvider);

  try {
    return runner.run(globals, (eph) {
      switch (op) {
        case CoordOp.azAlt:
          final r = eph.azAlt(
            ectx.jdUt, seEcl2hor,
            geolon: ectx.longitude, geolat: ectx.latitude, geoalt: ectx.altitude,
            atpress: atpress, attemp: attemp,
            bodyLon: lon, bodyLat: lat, bodyDist: dist,
          );
          return CoordAzAltResult(r.azimuth, r.trueAltitude, r.apparentAltitude);

        case CoordOp.azAltRev:
          final r = eph.azAltRev(
            ectx.jdUt, seHor2ecl,
            geolon: ectx.longitude, geolat: ectx.latitude, geoalt: ectx.altitude,
            azimuth: azimuth, altitude: altitude,
          );
          return CoordAzAltRevResult(r.lon, r.lat);

        case CoordOp.cotrans:
          final r = eph.cotrans(lon, lat, dist, eps);
          final dir = eps >= 0 ? 'ecl→equ' : 'equ→ecl';
          return CoordCoTransResult(r.lon, r.lat, r.dist, dir);

        case CoordOp.refrac:
          final apparent = eph.refrac(altitude, atpress, attemp, seTrueToApp);
          return CoordRefracResult(altitude, apparent,
              'input=${altitude.toStringAsFixed(4)}° true→apparent');
      }
    });
  } on SweException catch (e) {
    return CoordErrorResult(e.message);
  } catch (e) {
    return CoordErrorResult(e.toString());
  }
});

// ── ResultField conversion ─────────────────────────────────────────────────

List<ResultField> coordResultToFields(
    CoordResult result, DisplayFormat fmt) {
  switch (result) {
    case CoordAzAltResult r:
      return [
        ResultField(
          label: 'Azimuth',
          value: formatAngle(r.azimuth, fmt),
          rawValue: r.azimuth,
        ),
        ResultField(
          label: 'True alt',
          value: formatAngle(r.trueAltitude, fmt),
          rawValue: r.trueAltitude,
        ),
        ResultField(
          label: 'App. alt',
          value: formatAngle(r.apparentAltitude, fmt),
          rawValue: r.apparentAltitude,
        ),
      ];

    case CoordAzAltRevResult r:
      return [
        ResultField(
          label: 'Longitude',
          value: formatAngle(r.lon, fmt),
          rawValue: r.lon,
        ),
        ResultField(
          label: 'Latitude',
          value: formatAngle(r.lat, fmt),
          rawValue: r.lat,
        ),
      ];

    case CoordCoTransResult r:
      return [
        ResultField(
          label: 'Direction',
          value: r.direction,
          rawValue: null,
        ),
        ResultField(
          label: 'Longitude',
          value: formatAngle(r.lon, fmt),
          rawValue: r.lon,
        ),
        ResultField(
          label: 'Latitude',
          value: formatAngle(r.lat, fmt),
          rawValue: r.lat,
        ),
        ResultField(
          label: 'Distance',
          value: r.dist.toStringAsFixed(8),
          rawValue: r.dist,
        ),
      ];

    case CoordRefracResult r:
      return [
        ResultField(
          label: 'Input alt',
          value: formatAngle(r.inputAlt, fmt),
          rawValue: r.inputAlt,
        ),
        ResultField(
          label: 'Refracted',
          value: formatAngle(r.outputAlt, fmt),
          rawValue: r.outputAlt,
        ),
        ResultField(
          label: 'Correction',
          value: formatAngle(r.outputAlt - r.inputAlt, fmt),
          rawValue: r.outputAlt - r.inputAlt,
        ),
      ];

    case CoordErrorResult r:
      return [ResultField(label: 'Error', value: r.message, rawValue: 0.0)];
  }
}

// ── Export ─────────────────────────────────────────────────────────────────

List<ExportRow> coordToExportRows(
    CoordOp op, CoordResult result, DisplayFormat fmt) {
  return [
    ExportRow(
      header: '${op.label} — ${op.description}',
      fields: coordResultToFields(result, fmt)
          .map((f) => (f.label, f.value))
          .toList(),
    ),
  ];
}
