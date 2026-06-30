import 'dart:io';
import 'dart:typed_data';

import '../model/chart_data.dart';

/// Quick*Chart .qck format.
///
/// Fixed-width text, one chart per line, ~100 characters.
/// The de facto bulk interchange format — supported by Solar Fire,
/// Astrolog, ZET, AstroConnexions, Janus, and others.
class QckFormat {
  static List<ChartData> readAll(String filePath) =>
      readAllBytes(File(filePath).readAsBytesSync());

  static List<ChartData> readAllBytes(Uint8List bytes) {
    final lines = String.fromCharCodes(bytes).split(RegExp(r'\r?\n'));
    return lines
        .where((l) => l.trim().isNotEmpty && l.length >= 62)
        .map(_parseLine)
        .whereType<ChartData>()
        .toList();
  }

  static ChartData read(String filePath) =>
      readBytes(File(filePath).readAsBytesSync());

  static ChartData readBytes(Uint8List bytes) {
    final charts = readAllBytes(bytes);
    if (charts.isEmpty) {
      throw const FormatException('No chart data found');
    }
    return charts.first;
  }

  static void writeAll(String filePath, List<ChartData> charts) {
    final sb = StringBuffer();
    for (final c in charts) {
      sb.writeln(_formatLine(c));
    }
    File(filePath).writeAsStringSync(sb.toString());
  }

  static void write(String filePath, ChartData chart) {
    writeAll(filePath, [chart]);
  }

  static ChartData? _parseLine(String line) {
    try {
      if (line.length < 62) return null;

      final s = line.padRight(100);

      final name = s.substring(0, 34).trim();
      final month = int.tryParse(s.substring(34, 36).trim()) ?? 1;
      final day = int.tryParse(s.substring(36, 38).trim()) ?? 1;
      final year = int.tryParse(s.substring(38, 42).trim()) ?? 2000;
      final hour = int.tryParse(s.substring(42, 44).trim()) ?? 12;
      final minute = int.tryParse(s.substring(44, 46).trim()) ?? 0;

      final tzStr = s.substring(47, 51).trim();
      final tz = double.tryParse(tzStr) ?? 0.0;
      final utcOffset = -tz;

      final latDeg = int.tryParse(s.substring(51, 53).trim()) ?? 0;
      final latDir = s[53].toUpperCase();
      final latMin = int.tryParse(s.substring(54, 56).trim()) ?? 0;
      var lat = latDeg + latMin / 60.0;
      if (latDir == 'S') lat = -lat;

      final lonDeg = int.tryParse(s.substring(56, 59).trim()) ?? 0;
      final lonDir = s[59].toUpperCase();
      final lonMin = int.tryParse(s.substring(60, 62).trim()) ?? 0;
      var lon = lonDeg + lonMin / 60.0;
      if (lonDir == 'W') lon = -lon;

      final place = s.length > 62
          ? s.substring(62, s.length.clamp(62, 96)).trim()
          : '';

      Gender? gender;
      if (s.length > 96) {
        final g = s[96].toUpperCase();
        if (g == 'M') gender = Gender.male;
        if (g == 'F') gender = Gender.female;
      }

      String? rodden;
      if (s.length > 97) {
        final r = s.substring(97).trim();
        if (r.isNotEmpty) rodden = r;
      }

      return ChartData(
        name: name,
        dateTime: DateTime(year, month, day, hour, minute),
        birthLocation: GeoLocation(city: place, latitude: lat, longitude: lon),
        utcOffsetHours: utcOffset,
        gender: gender,
        roddenRating: rodden,
      );
    } catch (_) {
      return null;
    }
  }

  static String _formatLine(ChartData c) {
    final dt = c.dateTime;
    final loc = c.birthLocation;

    final name = c.name.padRight(34).substring(0, 34);
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final year = dt.year.toString().padLeft(4, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final timeFlag = ' ';

    final tz = -c.utcOffsetHours;
    // QCK format only supports integer timezone offsets; round to nearest hour.
    final tzStr = tz.round().toString().padLeft(3);
    final tzExtra = ' ';

    final latAbs = loc.latitude.abs();
    final latDeg = latAbs.floor().toString().padLeft(2, '0');
    final latDir = loc.latitude >= 0 ? 'N' : 'S';
    final latMin = ((latAbs - latAbs.floor()) * 60).round().toString().padLeft(
      2,
      '0',
    );

    final lonAbs = loc.longitude.abs();
    final lonDeg = lonAbs.floor().toString().padLeft(3, '0');
    final lonDir = loc.longitude >= 0 ? 'E' : 'W';
    final lonMin = ((lonAbs - lonAbs.floor()) * 60).round().toString().padLeft(
      2,
      '0',
    );

    final place = loc.city.padRight(34).substring(0, 34);

    final gender = c.gender == Gender.male
        ? 'M'
        : c.gender == Gender.female
        ? 'F'
        : ' ';
    final rodden = (c.roddenRating ?? '').padRight(3).substring(0, 3);

    return '$name$month$day$year$hour$minute$timeFlag$tzStr$tzExtra'
        '$latDeg$latDir$latMin$lonDeg$lonDir$lonMin$place$gender$rodden';
  }
}
