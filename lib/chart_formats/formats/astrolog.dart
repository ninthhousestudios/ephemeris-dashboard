import 'dart:io';
import 'dart:typed_data';

import '../model/chart_data.dart';

/// Astrolog .as chart format.
///
/// Plain text — each line is an Astrolog command-line switch.
/// The key switch is `-qa` which carries all birth data.
/// Zone: positive = west of UTC, negative = east (US convention).
class AstrologFormat {
  static ChartData read(String filePath) =>
      readBytes(File(filePath).readAsBytesSync());

  static ChartData readBytes(Uint8List bytes) {
    final lines = String.fromCharCodes(bytes).split(RegExp(r'\r?\n'));

    int month = 1, day = 1, year = 2000, hour = 0, minute = 0;
    double utcOffset = 0.0;
    double longitude = 0.0, latitude = 0.0;
    String? name;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('-qa ')) {
        final parts = trimmed.substring(4).trim().split(RegExp(r'\s+'));
        if (parts.length >= 7) {
          month = int.tryParse(parts[0]) ?? 1;
          day = int.tryParse(parts[1]) ?? 1;
          year = int.tryParse(parts[2]) ?? 2000;
          final timeParts = parts[3].split(':');
          hour = int.tryParse(timeParts[0]) ?? 0;
          minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
          utcOffset = -(double.tryParse(parts[4]) ?? 0.0);
          longitude = _parseCoord(parts[5]);
          latitude = _parseCoord(parts[6]);
        }
      }

      if (trimmed.startsWith('-q ') && !trimmed.startsWith('-qa ')) {
        final parts = trimmed.substring(3).trim().split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          month = int.tryParse(parts[0]) ?? 1;
          day = int.tryParse(parts[1]) ?? 1;
          year = int.tryParse(parts[2]) ?? 2000;
          final timeParts = parts[3].split(':');
          hour = int.tryParse(timeParts[0]) ?? 0;
          minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
        }
      }

      if (trimmed.startsWith('-zl ')) {
        final parts = trimmed.substring(4).trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          longitude = _parseCoord(parts[0]);
          latitude = _parseCoord(parts[1]);
        }
      }

      if (trimmed.startsWith('-z ') && !trimmed.startsWith('-zl ')) {
        final parts = trimmed.substring(3).trim().split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          utcOffset = -(double.tryParse(parts[0]) ?? 0.0);
        }
      }

      if (trimmed.startsWith(';')) {
        name ??= trimmed.substring(1).trim();
      }
    }

    return ChartData(
      name: name ?? 'Chart',
      dateTime: DateTime(year, month, day, hour, minute),
      birthLocation: GeoLocation(latitude: latitude, longitude: longitude),
      utcOffsetHours: utcOffset,
    );
  }

  static void write(String filePath, ChartData chart) {
    final sb = StringBuffer();
    sb.writeln('; ${chart.name}');

    final dt = chart.dateTime;
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final zone = -chart.utcOffsetHours;
    final zoneStr = zone == zone.roundToDouble()
        ? zone.toInt().toString()
        : zone.toStringAsFixed(2);
    final lonStr = _formatCoord(chart.birthLocation.longitude);
    final latStr = _formatCoord(chart.birthLocation.latitude);

    sb.writeln(
      '-qa ${dt.month} ${dt.day} ${dt.year} $timeStr $zoneStr $lonStr $latStr',
    );

    File(filePath).writeAsStringSync(sb.toString());
  }

  static double _parseCoord(String s) {
    s = s.trim();
    final negative = s.startsWith('-');
    if (negative) s = s.substring(1);
    final parts = s.split(':');
    var value = double.tryParse(parts[0]) ?? 0.0;
    if (parts.length > 1) value += (double.tryParse(parts[1]) ?? 0.0) / 60.0;
    return negative ? -value : value;
  }

  static String _formatCoord(double value) {
    final negative = value < 0;
    final abs = value.abs();
    final deg = abs.floor();
    final min = ((abs - deg) * 60).round();
    return '${negative ? '-' : ''}$deg:${min.toString().padLeft(2, '0')}';
  }
}
