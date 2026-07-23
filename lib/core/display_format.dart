// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:math' show asin, cos, pi, sin, sqrt;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'context_provider.dart';
import 'output_clock.dart';
import 'swe_constants.dart';

/// Per-tab display format provider (currently used by Planets tab).
final planetsFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Global output-clock choice: which clock event times and Moments render in.
/// A display concern (sibling to [DisplayFormat]), not a computation flag.
final outputClockProvider = StateProvider<OutputClock>(
  (ref) => OutputClock.standard,
);

/// The [ClockView] to hand [formatJdDateTime], assembled from the current clock
/// choice plus the Context's longitude (LMT/LAT) and UTC offset (civil clock).
final clockViewProvider = Provider<ClockView>((ref) {
  final ctx = ref.watch(contextBarProvider);
  return ClockView(
    clock: ref.watch(outputClockProvider),
    longitude: ctx.longitude,
    utcOffset: ctx.utcOffset,
    calendar: ctx.calendar,
    scale: ctx.timeScale,
  );
});

/// Display format for angular values.
///
/// [radians] is a units choice for *angular* quantities only (longitude,
/// latitude, RA/Dec, angular speed); non-angular quantities (distances) fall
/// back to their decimal presentation. It replaces the former SEFLG_RADIANS
/// computation flag, which returned radians the display layer then mis-rendered
/// as degrees.
enum DisplayFormat {
  dms('DMS'),
  decimal('Dec'),
  raw('Raw'),
  radians('Rad');

  const DisplayFormat(this.label);
  final String label;
}

/// Format a longitude/latitude value according to the selected format.
String formatAngle(double degrees, DisplayFormat format) {
  switch (format) {
    case DisplayFormat.dms:
      return _toDms(degrees);
    case DisplayFormat.decimal:
      return '${degrees.toStringAsFixed(6)}°';
    case DisplayFormat.radians:
      return '${(degrees * _degToRad).toStringAsFixed(8)} rad';
    case DisplayFormat.raw:
      return degrees.toStringAsFixed(12);
  }
}

/// Format a distance value (AU or km).
String formatDistance(double value, DisplayFormat format) {
  switch (format) {
    case DisplayFormat.dms:
    case DisplayFormat.decimal:
    case DisplayFormat.radians:
      return '${value.toStringAsFixed(8)} AU';
    case DisplayFormat.raw:
      return value.toStringAsFixed(12);
  }
}

/// Format a speed value (degrees/day).
String formatSpeed(double value, DisplayFormat format) {
  switch (format) {
    case DisplayFormat.dms:
      return '${_toDms(value)}/day';
    case DisplayFormat.decimal:
      return '${value.toStringAsFixed(6)}°/day';
    case DisplayFormat.radians:
      return '${(value * _degToRad).toStringAsFixed(8)} rad/day';
    case DisplayFormat.raw:
      return value.toStringAsFixed(12);
  }
}

/// Coordinate labels that vary by coordinate mode.
typedef CoordLabels = ({
  String c1,
  String c2,
  String c3,
  String sc1,
  String sc2,
  String sc3,
});

const CoordLabels _defaultLabels = (
  c1: 'Longitude',
  c2: 'Latitude',
  c3: 'Distance',
  sc1: 'Spd Lon',
  sc2: 'Spd Lat',
  sc3: 'Spd Dist',
);

const CoordLabels _xyzLabels = (
  c1: 'X',
  c2: 'Y',
  c3: 'Z',
  sc1: 'Spd X',
  sc2: 'Spd Y',
  sc3: 'Spd Z',
);

const CoordLabels _equatLabels = (
  c1: 'Right Asc',
  c2: 'Declination',
  c3: 'Distance',
  sc1: 'Spd RA',
  sc2: 'Spd Dec',
  sc3: 'Spd Dist',
);

CoordLabels coordLabels(int coordValue) => switch (coordValue) {
  seFlgXyz => _xyzLabels,
  seFlgEquatorial => _equatLabels,
  _ => _defaultLabels,
};

/// Format a cartesian coordinate value (AU).
String formatAu(double value, DisplayFormat format) {
  switch (format) {
    case DisplayFormat.dms:
    case DisplayFormat.decimal:
    case DisplayFormat.radians:
      return '${value.toStringAsFixed(8)} AU';
    case DisplayFormat.raw:
      return value.toStringAsFixed(12);
  }
}

/// Format a cartesian speed value (AU/day).
String formatAuSpeed(double value, DisplayFormat format) {
  switch (format) {
    case DisplayFormat.dms:
    case DisplayFormat.decimal:
    case DisplayFormat.radians:
      return '${value.toStringAsFixed(8)} AU/day';
    case DisplayFormat.raw:
      return value.toStringAsFixed(12);
  }
}

const _auPerLightYear = 63241.077;

/// Euclidean distance from three cartesian components.
double euclideanDistance(double x, double y, double z) =>
    sqrt(x * x + y * y + z * z);

/// Format a Euclidean distance, choosing AU or light-years.
/// SE returns all XYZ in AU; [lightYears] converts AU → ly.
String formatEuclidean(
  double x,
  double y,
  double z,
  DisplayFormat format, {
  bool lightYears = false,
}) {
  var d = euclideanDistance(x, y, z);
  final unit = lightYears ? 'ly' : 'AU';
  if (lightYears) d /= _auPerLightYear;
  switch (format) {
    case DisplayFormat.dms:
    case DisplayFormat.decimal:
    case DisplayFormat.radians:
      return '${d.toStringAsFixed(8)} $unit';
    case DisplayFormat.raw:
      return d.toStringAsFixed(12);
  }
}

/// Convert decimal degrees to DMS string.
String _toDms(double degrees) {
  if (degrees.isNaN) return 'NaN';
  if (degrees.isInfinite) return '${degrees.isNegative ? '-' : ''}Inf';
  final negative = degrees < 0;
  var d = degrees.abs();
  final deg = d.truncate();
  d = (d - deg) * 60;
  final min = d.truncate();
  final sec = (d - min) * 60;

  final sign = negative ? '-' : '';
  return "$sign$deg° ${min.toString().padLeft(2, '0')}' ${sec.toStringAsFixed(2).padLeft(5, '0')}\"";
}

// ── Distance unit conversions (swetest -fW, -fw, -fr, -fq) ──

const _auToKm = 149597870.7;
const _earthRadiusKm = 6378.14;
const _radToArcsec = 180 * 3600 / pi;

String formatDistanceLy(double distAu, DisplayFormat format) {
  final ly = distAu / _auPerLightYear;
  return switch (format) {
    DisplayFormat.dms ||
    DisplayFormat.decimal ||
    DisplayFormat.radians => '${ly.toStringAsFixed(8)} ly',
    DisplayFormat.raw => ly.toStringAsFixed(12),
  };
}

String formatDistanceKm(double distAu, DisplayFormat format) {
  final km = distAu * _auToKm;
  return switch (format) {
    DisplayFormat.dms ||
    DisplayFormat.decimal ||
    DisplayFormat.radians => '${km.toStringAsFixed(2)} km',
    DisplayFormat.raw => km.toStringAsFixed(6),
  };
}

String formatParallax(double distAu, DisplayFormat format) {
  final pxArcsec = asin(_earthRadiusKm / (distAu * _auToKm)) * _radToArcsec;
  return switch (format) {
    DisplayFormat.dms ||
    DisplayFormat.decimal ||
    DisplayFormat.radians => '${pxArcsec.toStringAsFixed(4)}″',
    DisplayFormat.raw => pxArcsec.toStringAsFixed(12),
  };
}

String formatRelativeDistance(double dist, double dmin, DisplayFormat format) {
  final q = 1000 * dmin / dist;
  return switch (format) {
    DisplayFormat.dms ||
    DisplayFormat.decimal ||
    DisplayFormat.radians => q.toStringAsFixed(3),
    DisplayFormat.raw => q.toStringAsFixed(12),
  };
}

// ── Unit vectors (swetest -fU, -fu) ──

const _degToRad = pi / 180;

String formatUnitVector(double lonDeg, double latDeg, DisplayFormat format) {
  final lon = lonDeg * _degToRad;
  final lat = latDeg * _degToRad;
  final x = cos(lat) * cos(lon);
  final y = cos(lat) * sin(lon);
  final z = sin(lat);
  final digits = format == DisplayFormat.raw ? 12 : 8;
  return '${x.toStringAsFixed(digits)}, '
      '${y.toStringAsFixed(digits)}, '
      '${z.toStringAsFixed(digits)}';
}
