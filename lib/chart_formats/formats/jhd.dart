import 'dart:io';
import 'dart:typed_data';

import '../model/chart_data.dart';

/// Jagannatha Hora .jhd format.
///
/// ASCII text, one value per line.
/// Two variants:
///   A) "Calculated" — has 9 planetary longitudes on lines 9–17 + flag string
///   B) "Input only" — has timezone/location data, shorter
class JhdFormat {
  static const _planetOrder = [
    'Sun',
    'Moon',
    'Mars',
    'Mercury',
    'Jupiter',
    'Venus',
    'Saturn',
    'Rahu',
    'Ketu',
  ];

  static ChartData read(String filePath) =>
      readBytes(File(filePath).readAsBytesSync());

  static ChartData readBytes(Uint8List bytes) {
    final lines = String.fromCharCodes(
      bytes,
    ).split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();

    if (lines.length < 9) {
      throw FormatException(
        'Invalid .jhd file: expected at least 9 lines, got ${lines.length}',
      );
    }
    final month = int.tryParse(lines[0]) ?? 1;
    final day = int.tryParse(lines[1]) ?? 1;
    final year = int.tryParse(lines[2]) ?? 2000;
    final decimalTime = double.tryParse(lines[3]) ?? 0.0;
    final hour = decimalTime.floor();
    final minute = ((decimalTime - hour) * 60).round();
    final second = (((decimalTime - hour) * 60 - minute) * 60).round().clamp(
      0,
      59,
    );

    final rawOffset = double.tryParse(lines[4]) ?? 0.0;
    final utcOffset = -rawOffset;
    final rawLon = double.tryParse(lines[5]) ?? 0.0;
    final longitude = -rawLon;
    final latitude = double.tryParse(lines[6]) ?? 0.0;
    final dstOffset = double.tryParse(lines[7]) ?? 0.0;

    List<PlanetPosition>? planets;
    String city = '';
    String country = '';

    final line8 = double.tryParse(lines[8]) ?? 0.0;
    final isVariantA = line8.abs() > 10.0;

    if (isVariantA && lines.length >= 18) {
      planets = [];
      for (var i = 0; i < 9 && (8 + i) < lines.length; i++) {
        final lon = double.tryParse(lines[8 + i]);
        if (lon == null) break;
        var retro = false;
        if (lines.length > 17) {
          final flags = lines[17];
          if (i < flags.length) retro = flags[i] == '1';
        }
        planets.add(
          PlanetPosition(
            name: _planetOrder[i],
            longitude: lon,
            retrograde: retro,
          ),
        );
      }
      if (lines.length > 18) city = lines[18];
      if (lines.length > 19) country = lines[19];
    } else {
      if (lines.length > 12) city = lines[12];
      if (lines.length > 13) country = lines[13];
    }

    return ChartData(
      name: 'Chart',
      dateTime: DateTime(year, month, day, hour, minute, second),
      birthLocation: GeoLocation(
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
      ),
      utcOffsetHours: utcOffset,
      dstOffsetHours: dstOffset,
      planets: planets,
    );
  }

  static void write(String filePath, ChartData chart) {
    final sb = StringBuffer();
    sb.writeln(chart.dateTime.month);
    sb.writeln(chart.dateTime.day);
    sb.writeln(chart.dateTime.year);
    sb.writeln(chart.decimalHours.toStringAsFixed(6));
    sb.writeln((-chart.utcOffsetHours).toStringAsFixed(6));
    sb.writeln((-chart.birthLocation.longitude).toStringAsFixed(6));
    sb.writeln(chart.birthLocation.latitude.toStringAsFixed(6));
    sb.writeln(chart.dstOffsetHours.toStringAsFixed(1));

    if (chart.planets != null && chart.planets!.length >= 9) {
      for (final p in chart.planets!) {
        sb.writeln(p.longitude.toStringAsFixed(6));
      }
      sb.writeln(chart.planets!.map((p) => p.retrograde ? '1' : '0').join());
    } else {
      // Variant B (input-only): write small placeholder values that won't
      // trigger variant-A detection (line8.abs() > 10.0).
      sb.writeln('0.000000');
      sb.writeln('0.000000');
      sb.writeln('0');
      sb.writeln('0');
    }

    sb.writeln(chart.birthLocation.city);
    sb.writeln(chart.birthLocation.country);
    File(filePath).writeAsStringSync(sb.toString());
  }

  static void writeWithPlanets(String filePath, ChartData chart) {
    if (chart.planets == null || chart.planets!.isEmpty) {
      write(filePath, chart);
      return;
    }
    final sb = StringBuffer();
    sb.writeln(chart.dateTime.month);
    sb.writeln(chart.dateTime.day);
    sb.writeln(chart.dateTime.year);
    sb.writeln(chart.decimalHours.toStringAsFixed(6));
    sb.writeln((-chart.utcOffsetHours).toStringAsFixed(6));
    sb.writeln((-chart.birthLocation.longitude).toStringAsFixed(6));
    sb.writeln(chart.birthLocation.latitude.toStringAsFixed(6));
    sb.writeln(chart.dstOffsetHours.toStringAsFixed(1));

    for (final p in chart.planets!) {
      sb.writeln(p.longitude.toStringAsFixed(6));
    }
    final flags = chart.planets!.map((p) => p.retrograde ? '1' : '0').join();
    sb.writeln(flags);

    File(filePath).writeAsStringSync(sb.toString());
  }
}
