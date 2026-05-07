import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../core/swe_service.dart';

/// Body selection for nodes/apsides calculation.
final nodesBodyProvider = StateProvider<int>((ref) => seMoon);

/// Method for nodApsUt: 0=mean, 1=osculating, 2=oscu barycentric.
final nodesMethodProvider = StateProvider<int>((ref) => 0);

/// Display format for this tab.
final nodesFormatProvider =
    StateProvider<DisplayFormat>((ref) => DisplayFormat.dms);

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

/// Computes nodes & apsides for the selected body.
final nodesApsResultsProvider = Provider<NodesApsResult?>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('nodesApsides')) return null;

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  runner.setTabTag('nodesApsides');
  final swe = ref.read(sweProvider);
  final body = ref.watch(nodesBodyProvider);
  final method = ref.watch(nodesMethodProvider);

  final flags = ectx.iflag | seFlgSpeed;
  final jdUt = ectx.jdUt;
  final jdEt = jdUt + swe.deltat(jdUt);

  try {
    final nar = runner.run(
      globals,
      (eph) => eph.nodApsUt(jdUt, body, flags, method),
    );

    OrbitalElementsResult? orbEl;
    double? maxDist;
    double? minDist;

    try {
      orbEl = runner.run(
        globals, (eph) => eph.getOrbitalElements(jdEt, body, flags));
    } on SweException {
      orbEl = null;
    }

    try {
      final od = swe.orbitMaxMinTrueDistance(jdEt, body, flags);
      maxDist = od.maxDist;
      minDist = od.minDist;
    } on SweException {
      maxDist = null;
      minDist = null;
    }

    return NodesApsResult(
      bodyName: swe.getPlanetName(body),
      ascending: nar.ascending,
      descending: nar.descending,
      perihelion: nar.perihelion,
      aphelion: nar.aphelion,
      orbitalElements: orbEl,
      maxDist: maxDist,
      minDist: minDist,
    );
  } on SweException {
    return null;
  }
});

/// Convert a NodesApsResult to export rows.
List<ExportRow> nodesApsToExportRows(
    NodesApsResult result, DisplayFormat fmt) {
  String deg(double v) => formatAngle(v, fmt);
  String raw(double v) => v.toStringAsFixed(8);

  List<(String, String)> posFields(CalcResult pos) => [
        ('Longitude', deg(pos.longitude)),
        ('Latitude', deg(pos.latitude)),
        ('Distance (AU)', raw(pos.distance)),
        ('Speed Lon', deg(pos.longitudeSpeed)),
        ('Speed Lat', deg(pos.latitudeSpeed)),
        ('Speed Dist', raw(pos.distanceSpeed)),
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
    rows.add(ExportRow(
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
    ));
  }

  if (result.maxDist != null && result.minDist != null) {
    rows.add(ExportRow(
      header: '${result.bodyName} — Distance Extremes',
      fields: [
        ('Max True Distance (AU)', raw(result.maxDist!)),
        ('Min True Distance (AU)', raw(result.minDist!)),
      ],
    ));
  }

  return rows;
}
