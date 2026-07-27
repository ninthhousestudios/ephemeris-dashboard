// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/moment.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_utils_provider.dart';
import '../../layout/tab_definitions.dart';

/// Body selection for nodes/apsides calculation.
final nodesBodyProvider = StateProvider<int>((ref) => seMoon);

/// Method for nodApsUt: a NodApsMethod bitflag (seNodBit*), passed untranslated
/// through the Ephemeris seam. These are NOT dense indices — MEAN=1, OSCU=2,
/// OSCU_BAR=4 — and 0 (empty) is treated by the engine as MEAN, so it must not
/// be used as a distinct "osculating" value.
final nodesMethodProvider = StateProvider<int>((ref) => seNodBitMean);

/// Display format for this tab.
final nodesFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Full result for the Nodes & Apsides tab.
class NodesApsResult {
  const NodesApsResult({
    required this.bodyName,
    required this.ascending,
    required this.descending,
    required this.perihelion,
    required this.aphelion,
    this.orbitalElements,
    this.maxDist,
    this.minDist,
  });

  final String bodyName;
  final CalcResult ascending;
  final CalcResult descending;
  final CalcResult perihelion;
  final CalcResult aphelion;

  // Optional — not all bodies support these.
  final OrbitalElementsResult? orbitalElements;
  final double? maxDist;
  final double? minDist;
}

NodesApsResult computeNodesApsides({
  required Ephemeris eph,
  required double jdUt,
  required double deltat,
  required int body,
  required int iflag,
  required int method,
  required String bodyName,
}) {
  final flags = iflag | seFlgSpeed;
  final jdEt = jdUt + deltat;

  final nar = eph.nodApsUt(jdUt, body, flags, method);

  OrbitalElementsResult? orbEl;
  try {
    orbEl = eph.getOrbitalElements(jdEt, body, flags);
  } on SweException {
    orbEl = null;
  }

  double? maxDist;
  double? minDist;
  try {
    final od = eph.orbitMaxMinTrueDistance(jdEt, body, flags);
    maxDist = od.maxDist;
    minDist = od.minDist;
  } on SweException {
    maxDist = null;
    minDist = null;
  }

  return NodesApsResult(
    bodyName: bodyName,
    ascending: nar.ascending,
    descending: nar.descending,
    perihelion: nar.perihelion,
    aphelion: nar.aphelion,
    orbitalElements: orbEl,
    maxDist: maxDist,
    minDist: minDist,
  );
}

NodesApsResult Function(Ephemeris, Moment) _nodesApsCompute(Ref ref) {
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final body = ref.watch(nodesBodyProvider);
  final method = ref.watch(nodesMethodProvider);

  return (eph, moment) => computeNodesApsides(
    eph: eph,
    jdUt: moment.ut,
    deltat: moment.deltaT,
    body: body,
    iflag: flags.iflag,
    method: method,
    bodyName: safeGetName(swe, body),
  );
}

final _nodesApsCalcProvider = Provider<CalcOutcome<NodesApsResult>>((ref) {
  return runTabCalc(ref, compute: _nodesApsCompute(ref));
});

final nodesApsResultsProvider = Provider<CalcOutcome<NodesApsResult>>((ref) {
  return ref.watch(_nodesApsCalcProvider);
});

final nodesApsSeriesProvider =
    Provider<List<(Moment, CalcOutcome<NodesApsResult>)>>((ref) {
      return seriesSteps(
        ref,
        AppTab.nodesApsides.name,
        compute: () => _nodesApsCompute(ref),
      );
    });

/// Convert a NodesApsResult to export rows.
List<ExportRow> nodesApsToExportRows(
  NodesApsResult result,
  DisplayFormat fmt, {
  bool isXyz = false,
  int coordValue = 0,
}) {
  final lbl = coordLabels(coordValue);
  String deg(double v) => formatAngle(v, fmt);
  String raw(double v) => v.toStringAsFixed(8);

  List<(String, String)> posFields(CalcResult pos) => [
    (lbl.c1, isXyz ? formatAu(pos.longitude, fmt) : deg(pos.longitude)),
    (lbl.c2, isXyz ? formatAu(pos.latitude, fmt) : deg(pos.latitude)),
    (
      isXyz ? lbl.c3 : 'Distance (AU)',
      isXyz ? formatAu(pos.distance, fmt) : raw(pos.distance),
    ),
    if (isXyz)
      (
        'Distance',
        formatEuclidean(pos.longitude, pos.latitude, pos.distance, fmt),
      ),
    (
      lbl.sc1,
      isXyz ? formatAuSpeed(pos.longitudeSpeed, fmt) : deg(pos.longitudeSpeed),
    ),
    (
      lbl.sc2,
      isXyz ? formatAuSpeed(pos.latitudeSpeed, fmt) : deg(pos.latitudeSpeed),
    ),
    (
      lbl.sc3,
      isXyz ? formatAuSpeed(pos.distanceSpeed, fmt) : raw(pos.distanceSpeed),
    ),
  ];

  final rows = <ExportRow>[
    ExportRow(
      header: '${result.bodyName} — Ascending Node',
      fields: posFields(result.ascending),
    ),
    ExportRow(
      header: '${result.bodyName} — Descending Node',
      fields: posFields(result.descending),
    ),
    ExportRow(
      header: '${result.bodyName} — Perihelion',
      fields: posFields(result.perihelion),
    ),
    ExportRow(
      header: '${result.bodyName} — Aphelion',
      fields: posFields(result.aphelion),
    ),
  ];

  final el = result.orbitalElements;
  if (el != null) {
    rows.add(
      ExportRow(
        header: '${result.bodyName} — Orbital Elements',
        fields: [
          ('Semi-major Axis (AU)', raw(el.semimajorAxis)),
          ('Eccentricity', raw(el.eccentricity)),
          ('Inclination', deg(el.inclination)),
          ('Ascending Node', deg(el.ascendingNode)),
          ('Arg. Periapsis', deg(el.argPeriapsis)),
          ('Lon. Periapsis', deg(el.lonPeriapsis)),
          ('Mean Anomaly (epoch)', deg(el.meanAnomalyEpoch)),
          ('True Anomaly (epoch)', deg(el.trueAnomalyEpoch)),
          ('Eccentric Anomaly', deg(el.eccentricAnomalyEpoch)),
          ('Mean Longitude (epoch)', deg(el.meanLongitudeEpoch)),
          ('Mean Daily Motion', deg(el.meanDailyMotion)),
          ('Perihelion Dist (AU)', raw(el.perihelionDistance)),
          ('Aphelion Dist (AU)', raw(el.aphelionDistance)),
          ('Sidereal Period (yr)', raw(el.siderealPeriodYears)),
          ('Tropical Period (yr)', raw(el.tropicalPeriodYears)),
          ('Synodic Period (days)', raw(el.synodicPeriodDays)),
          ('Perihelion Passage (JD)', raw(el.perihelionPassage)),
        ],
      ),
    );
  }

  if (result.maxDist != null && result.minDist != null) {
    rows.add(
      ExportRow(
        header: '${result.bodyName} — Distance Extremes',
        fields: [
          ('Max True Distance (AU)', raw(result.maxDist!)),
          ('Min True Distance (AU)', raw(result.minDist!)),
        ],
      ),
    );
  }

  return rows;
}
