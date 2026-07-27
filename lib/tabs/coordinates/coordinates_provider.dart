// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
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

// ── Shared UI state ───────────────────────────────────────────────────────

final coordFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

// ── Per-card input records ────────────────────────────────────────────────

typedef AzAltInput = ({
  bool forward,
  double lon,
  double lat,
  double dist,
  double atpress,
  double attemp,
  double azimuth,
  double altitude,
});

final azAltInputProvider = StateProvider<AzAltInput>(
  (ref) => (
    forward: true,
    lon: 0.0,
    lat: 0.0,
    dist: 1.0,
    atpress: 1013.25,
    attemp: 15.0,
    azimuth: 0.0,
    altitude: 0.0,
  ),
);

typedef CoTransInput = ({
  bool eclToEqu,
  double lon,
  double lat,
  double dist,
  double eps,
});

final coTransInputProvider = StateProvider<CoTransInput>(
  (ref) => (eclToEqu: true, lon: 0.0, lat: 0.0, dist: 1.0, eps: 23.4393),
);

typedef RefracInput = ({double altitude, double atpress, double attemp});

final refracInputProvider = StateProvider<RefracInput>(
  (ref) => (altitude: 0.0, atpress: 1013.25, attemp: 15.0),
);

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

// ── Pure compute ───────────────────────────────────────────────────────────

CoordResult computeCoordinates({
  required Ephemeris eph,
  required CoordOp op,
  required double jdUt,
  required double geolon,
  required double geolat,
  required double geoalt,
  required double lon,
  required double lat,
  required double dist,
  required double atpress,
  required double attemp,
  required double azimuth,
  required double altitude,
  required double eps,
}) {
  try {
    switch (op) {
      case CoordOp.azAlt:
        final r = eph.azAlt(
          jdUt,
          seEcl2hor,
          geolon: geolon,
          geolat: geolat,
          geoalt: geoalt,
          atpress: atpress,
          attemp: attemp,
          bodyLon: lon,
          bodyLat: lat,
          bodyDist: dist,
        );
        return CoordAzAltResult(r.azimuth, r.trueAltitude, r.apparentAltitude);

      case CoordOp.azAltRev:
        final r = eph.azAltRev(
          jdUt,
          seHor2ecl,
          geolon: geolon,
          geolat: geolat,
          geoalt: geoalt,
          azimuth: azimuth,
          altitude: altitude,
        );
        return CoordAzAltRevResult(r.lon, r.lat);

      case CoordOp.cotrans:
        final r = eph.cotrans(lon, lat, dist, eps);
        final dir = eps >= 0 ? 'ecl→equ' : 'equ→ecl';
        return CoordCoTransResult(r.lon, r.lat, r.dist, dir);

      case CoordOp.refrac:
        final apparent = eph.refrac(altitude, atpress, attemp, seTrueToApp);
        return CoordRefracResult(
          altitude,
          apparent,
          'input=${altitude.toStringAsFixed(4)}° true→apparent',
        );
    }
  } on SweException catch (e) {
    return CoordErrorResult(e.message);
  } catch (e) {
    return CoordErrorResult(e.toString());
  }
}

// ── Per-card kernel wiring ─────────────────────────────────────────────────

final _azAltCalcProvider = Provider<CalcOutcome<CoordResult>>((ref) {
  final ctx = ref.watch(contextBarProvider);
  final i = ref.watch(azAltInputProvider);
  return runTabCalc(
    ref,
    compute: (eph, moment) => computeCoordinates(
      eph: eph,
      op: i.forward ? CoordOp.azAlt : CoordOp.azAltRev,
      jdUt: moment.ut,
      geolon: ctx.longitude,
      geolat: ctx.latitude,
      geoalt: ctx.altitude,
      lon: i.lon,
      lat: i.lat,
      dist: i.dist,
      atpress: i.atpress,
      attemp: i.attemp,
      azimuth: i.azimuth,
      altitude: i.altitude,
      eps: 0,
    ),
  );
});

final azAltResultProvider = Provider<CalcOutcome<CoordResult>>(
  (ref) => ref.watch(_azAltCalcProvider),
);

final _coTransCalcProvider = Provider<CalcOutcome<CoordResult>>((ref) {
  final ctx = ref.watch(contextBarProvider);
  final i = ref.watch(coTransInputProvider);
  final epsAbs = i.eps.abs();
  return runTabCalc(
    ref,
    compute: (eph, moment) => computeCoordinates(
      eph: eph,
      op: CoordOp.cotrans,
      jdUt: moment.ut,
      geolon: ctx.longitude,
      geolat: ctx.latitude,
      geoalt: ctx.altitude,
      lon: i.lon,
      lat: i.lat,
      dist: i.dist,
      atpress: 0,
      attemp: 0,
      azimuth: 0,
      altitude: 0,
      eps: i.eclToEqu ? epsAbs : -epsAbs,
    ),
  );
});

final coTransResultProvider = Provider<CalcOutcome<CoordResult>>(
  (ref) => ref.watch(_coTransCalcProvider),
);

final _refracCalcProvider = Provider<CalcOutcome<CoordResult>>((ref) {
  final ctx = ref.watch(contextBarProvider);
  final i = ref.watch(refracInputProvider);
  return runTabCalc(
    ref,
    compute: (eph, moment) => computeCoordinates(
      eph: eph,
      op: CoordOp.refrac,
      jdUt: moment.ut,
      geolon: ctx.longitude,
      geolat: ctx.latitude,
      geoalt: ctx.altitude,
      lon: 0,
      lat: 0,
      dist: 0,
      atpress: i.atpress,
      attemp: i.attemp,
      azimuth: 0,
      altitude: i.altitude,
      eps: 0,
    ),
  );
});

final refracResultProvider = Provider<CalcOutcome<CoordResult>>(
  (ref) => ref.watch(_refracCalcProvider),
);
// ── ResultField conversion ─────────────────────────────────────────────────

List<ResultField> coordResultToFields(CoordResult result, DisplayFormat fmt) {
  switch (result) {
    case final CoordAzAltResult r:
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

    case final CoordAzAltRevResult r:
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

    case final CoordCoTransResult r:
      return [
        ResultField(label: 'Direction', value: r.direction, rawValue: null),
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

    case final CoordRefracResult r:
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

    case final CoordErrorResult r:
      return [ResultField(label: 'Error', value: r.message, rawValue: 0.0)];
  }
}

// ── Export ─────────────────────────────────────────────────────────────────

List<ExportRow> coordToExportRows(
  CoordOp op,
  CoordResult result,
  DisplayFormat fmt,
) {
  return [
    ExportRow(
      header: '${op.label} — ${op.description}',
      fields: coordResultToFields(
        result,
        fmt,
      ).map((f) => (f.label, f.value)).toList(),
    ),
  ];
}
