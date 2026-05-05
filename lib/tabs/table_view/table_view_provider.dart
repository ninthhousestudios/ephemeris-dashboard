import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_context.dart';
import '../../core/calc_session.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/export_service.dart';
import '../../core/swe_service.dart';
import '../../core/display_format.dart';

// ── Selectable bodies ────────────────────────────────────────────────────────

const tableViewBodies = <(int, String)>[
  (seSun, 'Sun'),
  (seMoon, 'Moon'),
  (seMercury, 'Mercury'),
  (seVenus, 'Venus'),
  (seMars, 'Mars'),
  (seJupiter, 'Jupiter'),
  (seSaturn, 'Saturn'),
  (seUranus, 'Uranus'),
  (seNeptune, 'Neptune'),
  (sePluto, 'Pluto'),
  (seMeanNode, 'Mean Node'),
  (seTrueNode, 'True Node'),
  (seChiron, 'Chiron'),
];

// ── Step units ───────────────────────────────────────────────────────────────

enum StepUnit {
  minutes('Minutes', 1.0 / 1440.0),
  hours('Hours', 1.0 / 24.0),
  days('Days', 1.0),
  weeks('Weeks', 7.0),
  months('Months', 30.4375); // approximate

  const StepUnit(this.label, this.jdFactor);
  final String label;
  final double jdFactor;
}

// ── State providers ──────────────────────────────────────────────────────────

/// Selected bodies as a set of planet IDs.
final tableViewBodiesProvider =
    StateProvider<Set<int>>((ref) => {seSun, seMoon});

final tableViewStepValueProvider = StateProvider<double>((ref) => 1.0);

final tableViewStepUnitProvider =
    StateProvider<StepUnit>((ref) => StepUnit.days);

final tableViewStepCountProvider = StateProvider<int>((ref) => 30);

final tableViewFormatProvider =
    StateProvider<DisplayFormat>((ref) => DisplayFormat.dms);

// ── Result model ─────────────────────────────────────────────────────────────

class EphemerisRow {
  const EphemerisRow({
    required this.jd,
    required this.dateStr,
    required this.bodyValues,
  });

  final double jd;
  final String dateStr;

  /// Map from body ID to longitude value (or error string).
  final Map<int, (double?, String?)> bodyValues;
}

// ── Computation ──────────────────────────────────────────────────────────────

final tableViewResultsProvider = Provider<List<EphemerisRow>>((ref) {
  final session = ref.watch(calcSessionProvider);
  if (!session.tabHasRun('tableView')) return [];

  final ectx = ref.watch(effectiveContextProvider);
  final globals = ref.watch(appliedGlobalsProvider);
  final runner = ref.watch(ephemerisRunnerProvider);
  final swe = ref.read(sweProvider);
  final bodies = ref.watch(tableViewBodiesProvider);
  final stepValue = ref.watch(tableViewStepValueProvider);
  final stepUnit = ref.watch(tableViewStepUnitProvider);
  final stepCount = ref.watch(tableViewStepCountProvider);

  final iflag = ectx.iflag;
  final jdStart = ectx.jdUt;
  final stepJd = stepValue * stepUnit.jdFactor;
  final sortedBodies = bodies.toList()..sort();
  final rows = <EphemerisRow>[];

  for (var i = 0; i < stepCount; i++) {
    final jd = jdStart + i * stepJd;
    final bodyValues = <int, (double?, String?)>{};

    for (final body in sortedBodies) {
      try {
        final result = runner.run(
          globals, (eph) => eph.calcUt(jd, body, iflag));
        bodyValues[body] = (result.longitude, null);
      } catch (e) {
        bodyValues[body] = (null, e.toString());
      }
    }

    String dateStr;
    try {
      final r = swe.revjul(jd);
      final h = r.hour.floor();
      final mFrac = (r.hour - h) * 60;
      final m = mFrac.floor();
      final s = ((mFrac - m) * 60).round();
      dateStr =
          '${r.year}-${_p(r.month)}-${_p(r.day)} ${_p(h)}:${_p(m)}:${_p(s)}';
    } catch (_) {
      dateStr = jd.toStringAsFixed(4);
    }

    rows.add(EphemerisRow(jd: jd, dateStr: dateStr, bodyValues: bodyValues));
  }

  return rows;
});

String _p(int n) => n.toString().padLeft(2, '0');

// ── Export ────────────────────────────────────────────────────────────────────

String bodyName(int id) {
  for (final b in tableViewBodies) {
    if (b.$1 == id) return b.$2;
  }
  return 'Body $id';
}

List<ExportRow> tableViewToExportRows(
  List<EphemerisRow> rows,
  Set<int> bodies,
  DisplayFormat format,
) {
  final sortedBodies = bodies.toList()..sort();
  return rows.map((row) {
    final fields = <(String, String)>[
      ('JD', row.jd.toStringAsFixed(8)),
    ];
    for (final body in sortedBodies) {
      final val = row.bodyValues[body];
      if (val == null) continue;
      final (lon, err) = val;
      fields.add((
        bodyName(body),
        err ?? formatAngle(lon!, format),
      ));
    }
    return ExportRow(header: row.dateStr, fields: fields);
  }).toList();
}
