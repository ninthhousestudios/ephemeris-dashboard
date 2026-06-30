import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-tab display format provider (currently used by Planets tab).
final planetsFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Display format for angular values.
enum DisplayFormat {
  dms('DMS'),
  decimal('Dec'),
  raw('Raw');

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
    case DisplayFormat.raw:
      return degrees.toStringAsFixed(12);
  }
}

/// Format a distance value (AU or km).
String formatDistance(double value, DisplayFormat format) {
  switch (format) {
    case DisplayFormat.dms:
    case DisplayFormat.decimal:
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
    case DisplayFormat.raw:
      return value.toStringAsFixed(12);
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
