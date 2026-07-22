// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/calculation/series_spec.dart';
import '../../core/context_provider.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../core/display_format.dart';
import '../other_bodies/other_bodies_provider.dart' show otherBodyName;

// ── Selectable bodies (planet chips) ────────────────────────────────────────

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

// ── State providers ──────────────────────────────────────────────────────────

/// Selected bodies as a set of planet IDs.
final tableViewBodiesProvider = StateProvider<Set<int>>(
  (ref) => {seSun, seMoon},
);

/// Extra bodies (asteroids, comets, planetary moons) by body ID.
final tableViewExtraBodiesProvider = StateProvider<Set<int>>((ref) => const {});

/// Selected stars by name.
final tableViewStarsProvider = StateProvider<List<String>>((ref) => const []);

final tableViewStepValueProvider = StateProvider<double>((ref) => 1.0);

final tableViewStepUnitProvider = StateProvider<StepUnit>(
  (ref) => StepUnit.days,
);

final tableViewStepCountProvider = StateProvider<int>((ref) => 30);

final tableViewFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

// ── Optional column toggles ─────────────────────────────────────────────────

enum TableColumn {
  latitude('Latitude'),
  distance('Distance'),
  speed('Speed');

  const TableColumn(this.label);
  final String label;
}

final tableViewColumnsProvider = StateProvider<Set<TableColumn>>(
  (ref) => const {},
);

// ── Column key: unified identifier for body or star ─────────────────────────

sealed class ColKey implements Comparable<ColKey> {
  String get label;
}

class BodyCol implements ColKey {
  const BodyCol(this.bodyId);
  final int bodyId;

  @override
  String get label {
    for (final b in tableViewBodies) {
      if (b.$1 == bodyId) return b.$2;
    }
    return otherBodyName(bodyId);
  }

  @override
  int compareTo(ColKey other) {
    if (other is BodyCol) return bodyId.compareTo(other.bodyId);
    return -1; // bodies before stars
  }

  @override
  bool operator ==(Object other) => other is BodyCol && bodyId == other.bodyId;
  @override
  int get hashCode => bodyId.hashCode;
}

class StarCol implements ColKey {
  const StarCol(this.starName);
  final String starName;

  @override
  String get label => starName;

  @override
  int compareTo(ColKey other) {
    if (other is StarCol) return starName.compareTo(other.starName);
    return 1; // stars after bodies
  }

  @override
  bool operator ==(Object other) =>
      other is StarCol && starName == other.starName;
  @override
  int get hashCode => starName.hashCode;
}

// ── Result model ─────────────────────────────────────────────────────────────

class EphemerisRow {
  const EphemerisRow({
    required this.jd,
    required this.dateStr,
    required this.values,
  });

  final double jd;
  final String dateStr;

  /// Map from column key to full calc result (or error string).
  final Map<ColKey, (CalcResult?, String?)> values;
}

// ── Computation ──────────────────────────────────────────────────────────────

final _tableViewCalcProvider = Provider<CalcOutcome<List<EphemerisRow>>>((ref) {
  final ctx = ref.watch(contextBarProvider);
  final flags = ref.watch(flagBarProvider);
  final swe = ref.read(sweProvider);
  final bodies = ref.watch(tableViewBodiesProvider);
  final extraBodies = ref.watch(tableViewExtraBodiesProvider);
  final stars = ref.watch(tableViewStarsProvider);
  final stepValue = ref.watch(tableViewStepValueProvider);
  final stepUnit = ref.watch(tableViewStepUnitProvider);
  final stepCount = ref.watch(tableViewStepCountProvider);

  final iflag = flags.iflag;
  final jdStart = ctx.jdUt;
  final allBodyIds = {...bodies, ...extraBodies}.toList()..sort();

  return runTabCalc(
    ref,
    compute: (eph, _) {
      final rows = <EphemerisRow>[];
      for (var i = 0; i < stepCount; i++) {
        final jd = stepUnit.advanceFrom(jdStart, stepValue, i);
        final values = <ColKey, (CalcResult?, String?)>{};

        for (final body in allBodyIds) {
          final key = BodyCol(body);
          try {
            final result = eph.calcUt(jd, body, iflag);
            values[key] = (result, null);
          } catch (e) {
            values[key] = (null, e.toString());
          }
        }

        for (final star in stars) {
          final key = StarCol(star);
          try {
            final result = eph.fixstar2Ut(star, jd, iflag);
            values[key] = (
              CalcResult(
                longitude: result.longitude,
                latitude: result.latitude,
                distance: result.distance,
                longitudeSpeed: result.longitudeSpeed,
                latitudeSpeed: result.latitudeSpeed,
                distanceSpeed: result.distanceSpeed,
                returnFlag: result.returnFlag,
              ),
              null,
            );
          } catch (e) {
            values[key] = (null, e.toString());
          }
        }

        rows.add(
          EphemerisRow(
            jd: jd,
            dateStr: formatJdDateTime(
              swe,
              jd,
              utLabel: false,
              fallbackDigits: 4,
            ),
            values: values,
          ),
        );
      }
      return rows;
    },
  );
});

/// Ephemeris table results (bodies × time steps).
final tableViewResultsProvider = Provider<CalcOutcome<List<EphemerisRow>>>((
  ref,
) {
  return ref.watch(_tableViewCalcProvider);
});

// ── Sorted column keys ──────────────────────────────────────────────────────

List<ColKey> tableViewSortedKeys(
  Set<int> bodies,
  Set<int> extraBodies,
  List<String> stars,
) {
  final keys = <ColKey>[
    for (final b in ({...bodies, ...extraBodies}.toList()..sort())) BodyCol(b),
    for (final s in stars) StarCol(s),
  ];
  return keys;
}

// ── Export ────────────────────────────────────────────────────────────────────

List<ExportRow> tableViewToExportRows(
  List<EphemerisRow> rows,
  List<ColKey> keys,
  DisplayFormat format, {
  bool isXyz = false,
  Set<TableColumn> columns = const {},
}) {
  return rows.map((row) {
    final fields = <(String, String)>[('JD', row.jd.toStringAsFixed(8))];
    for (final key in keys) {
      final val = row.values[key];
      if (val == null) continue;
      final (result, err) = val;
      final name = key.label;
      if (err != null) {
        fields.add((name, err));
        continue;
      }
      final r = result!;
      if (isXyz) {
        fields.add(('$name X', formatAu(r.longitude, format)));
        fields.add(('$name Y', formatAu(r.latitude, format)));
        fields.add(('$name Z', formatAu(r.distance, format)));
        if (columns.contains(TableColumn.distance)) {
          fields.add((
            '$name Dist',
            formatEuclidean(r.longitude, r.latitude, r.distance, format),
          ));
        }
      } else {
        fields.add((name, formatAngle(r.longitude, format)));
        if (columns.contains(TableColumn.latitude)) {
          fields.add(('$name Lat', formatAngle(r.latitude, format)));
        }
        if (columns.contains(TableColumn.distance)) {
          fields.add(('$name Dist', formatAu(r.distance, format)));
        }
        if (columns.contains(TableColumn.speed)) {
          fields.add(('$name Spd', formatAngle(r.longitudeSpeed, format)));
        }
      }
    }
    return ExportRow(header: row.dateStr, fields: fields);
  }).toList();
}
