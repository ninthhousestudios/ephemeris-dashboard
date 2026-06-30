import 'dart:io';
import 'dart:typed_data';

import '../model/chart_data.dart';

/// CSV chart format — simple tabular export/import.
class CsvChartFormat {
  static const _header =
      'name,date,time,utc_offset,dst_offset,city,country,latitude,longitude,gender,rodden_rating';

  static List<ChartData> readAll(String filePath) =>
      readAllBytes(File(filePath).readAsBytesSync());

  static List<ChartData> readAllBytes(Uint8List bytes) {
    final lines = String.fromCharCodes(bytes).split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return [];

    final start = lines[0].startsWith('name') ? 1 : 0;
    return lines.sublist(start).where((l) => l.trim().isNotEmpty).map((line) {
      final fields = _parseCsvLine(line);
      final dateParts = (fields.length > 1 ? fields[1] : '2000-01-01').split(
        '-',
      );
      final timeParts = (fields.length > 2 ? fields[2] : '00:00:00').split(':');
      return ChartData(
        name: fields.isNotEmpty ? fields[0] : '',
        dateTime: DateTime(
          int.tryParse(dateParts[0]) ?? 2000,
          dateParts.length > 1 ? (int.tryParse(dateParts[1]) ?? 1) : 1,
          dateParts.length > 2 ? (int.tryParse(dateParts[2]) ?? 1) : 1,
          int.tryParse(timeParts[0]) ?? 0,
          timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0,
          timeParts.length > 2 ? (int.tryParse(timeParts[2]) ?? 0) : 0,
        ),
        birthLocation: GeoLocation(
          city: fields.length > 5 ? fields[5] : '',
          country: fields.length > 6 ? fields[6] : '',
          latitude: fields.length > 7 ? (double.tryParse(fields[7]) ?? 0) : 0,
          longitude: fields.length > 8 ? (double.tryParse(fields[8]) ?? 0) : 0,
        ),
        utcOffsetHours: fields.length > 3
            ? (double.tryParse(fields[3]) ?? 0)
            : 0,
        dstOffsetHours: fields.length > 4
            ? (double.tryParse(fields[4]) ?? 0)
            : 0,
        gender: fields.length > 9 ? _parseGender(fields[9]) : null,
        roddenRating: fields.length > 10 && fields[10].isNotEmpty
            ? fields[10]
            : null,
      );
    }).toList();
  }

  static void writeAll(String filePath, List<ChartData> charts) {
    final sb = StringBuffer();
    sb.writeln(_header);
    for (final c in charts) {
      sb.writeln(_chartToCsvLine(c));
    }
    File(filePath).writeAsStringSync(sb.toString());
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

  static void write(String filePath, ChartData chart) {
    writeAll(filePath, [chart]);
  }

  static String _chartToCsvLine(ChartData c) {
    final dt = c.dateTime;
    final date = '${dt.year}-${_p2(dt.month)}-${_p2(dt.day)}';
    final time = '${_p2(dt.hour)}:${_p2(dt.minute)}:${_p2(dt.second)}';
    return [
      _csvEscape(c.name),
      date,
      time,
      c.utcOffsetHours.toString(),
      c.dstOffsetHours.toString(),
      _csvEscape(c.birthLocation.city),
      _csvEscape(c.birthLocation.country),
      c.birthLocation.latitude.toStringAsFixed(6),
      c.birthLocation.longitude.toStringAsFixed(6),
      c.gender?.name ?? '',
      c.roddenRating ?? '',
    ].join(',');
  }

  static String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    var i = 0;
    while (i < line.length) {
      if (line[i] == '"') {
        i++;
        final sb = StringBuffer();
        while (i < line.length) {
          if (line[i] == '"') {
            if (i + 1 < line.length && line[i + 1] == '"') {
              sb.write('"');
              i += 2;
            } else {
              i++;
              break;
            }
          } else {
            sb.write(line[i]);
            i++;
          }
        }
        fields.add(sb.toString());
        if (i < line.length && line[i] == ',') i++;
      } else {
        final end = line.indexOf(',', i);
        if (end < 0) {
          fields.add(line.substring(i));
          break;
        }
        fields.add(line.substring(i, end));
        i = end + 1;
      }
    }
    return fields;
  }

  static Gender? _parseGender(String s) {
    return switch (s.trim().toLowerCase()) {
      'male' => Gender.male,
      'female' => Gender.female,
      _ => null,
    };
  }
}

String _p2(int n) => n.toString().padLeft(2, '0');
