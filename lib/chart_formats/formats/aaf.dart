import 'dart:io';
import 'dart:typed_data';

import '../model/chart_data.dart';

/// AAF'97 — Astrological Exchange Format.
///
/// Plain text, chunk-based. Each chunk starts at column 0 with `#` + chunk ID
/// followed by `:` and comma-separated fields.
class AafFormat {
  static ChartData read(String filePath) =>
      readBytes(File(filePath).readAsBytesSync());

  static ChartData readBytes(Uint8List bytes) {
    final lines = String.fromCharCodes(bytes).split(RegExp(r'\r?\n'));
    String lastName = '';
    String firstName = '';
    Gender? gender;
    int year = 2000, month = 1, day = 1, hour = 0, minute = 0, second = 0;
    double utcOffset = 0.0;
    String city = '';
    String country = '';
    double latitude = 0.0;
    double longitude = 0.0;
    final comments = <String>[];
    String? rodden;

    for (final line in lines) {
      if (!line.startsWith('#')) continue;
      final colonIdx = line.indexOf(':');
      if (colonIdx < 0) continue;
      final tag = line.substring(0, colonIdx).toUpperCase();
      final data = line.substring(colonIdx + 1);

      switch (tag) {
        case '#A93':
          final parts = _splitFields(data);
          if (parts.isNotEmpty) lastName = parts[0];
          if (parts.length > 1) firstName = parts[1];
          if (parts.length > 2) {
            gender = switch (parts[2].toLowerCase()) {
              'm' => Gender.male,
              'f' || 'w' => Gender.female,
              _ => null,
            };
          }
        case '#B93':
          final parts = _splitFields(data);
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('.');
            if (dateParts.length >= 3) {
              day = int.tryParse(dateParts[0]) ?? 1;
              month = int.tryParse(dateParts[1]) ?? 1;
              year = int.tryParse(dateParts[2]) ?? 2000;
            }
          }
          if (parts.length > 1) {
            final timeParts = parts[1].split(':');
            hour = int.tryParse(timeParts[0]) ?? 0;
            if (timeParts.length > 1) {
              minute = int.tryParse(timeParts[1]) ?? 0;
            }
            if (timeParts.length > 2) {
              second = int.tryParse(timeParts[2]) ?? 0;
            }
          }
          if (parts.length > 2) {
            utcOffset = _parseAafTimezone(parts[2]);
          }
        case '#C93':
          final parts = _splitFields(data);
          if (parts.isNotEmpty) city = parts[0];
          if (parts.length > 1) country = parts[1];
          if (parts.length > 2) longitude = _parseAafCoord(parts[2]);
          if (parts.length > 3) latitude = _parseAafCoord(parts[3]);
        case '#COM':
          comments.add(data.trim());
        case '#ADB':
          final parts = _splitFields(data);
          if (parts.isNotEmpty) rodden = parts[0];
      }
    }

    final name = firstName.isNotEmpty
        ? '$firstName $lastName'.trim()
        : lastName;

    return ChartData(
      name: name,
      dateTime: DateTime(year, month, day, hour, minute, second),
      birthLocation: GeoLocation(
        city: city,
        country: country,
        latitude: latitude,
        longitude: longitude,
      ),
      utcOffsetHours: utcOffset,
      gender: gender,
      notes: comments.isNotEmpty ? comments.join('\n') : null,
      roddenRating: rodden,
    );
  }

  static void write(String filePath, ChartData chart) {
    final sb = StringBuffer();

    final nameParts = chart.name.split(' ');
    final firstName = nameParts.length > 1 ? nameParts.first : '';
    final lastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : chart.name;
    final sex = chart.gender == Gender.male
        ? 'm'
        : chart.gender == Gender.female
        ? 'f'
        : 'e';

    sb.writeln('#A93:$lastName,$firstName,$sex');

    final dt = chart.dateTime;
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final tzStr = _formatAafTimezone(chart.utcOffsetHours);
    sb.writeln('#B93:$dateStr,$timeStr,$tzStr');

    final lonStr = _formatAafCoord(
      chart.birthLocation.longitude,
      chart.birthLocation.longitude >= 0 ? 'e' : 'w',
    );
    final latStr = _formatAafCoord(
      chart.birthLocation.latitude,
      chart.birthLocation.latitude >= 0 ? 'n' : 's',
    );
    sb.writeln(
      '#C93:${chart.birthLocation.city},${chart.birthLocation.country},$lonStr,$latStr',
    );

    if (chart.roddenRating != null) {
      sb.writeln('#ADB:${chart.roddenRating}');
    }

    if (chart.notes != null && chart.notes!.isNotEmpty) {
      for (final line in chart.notes!.split('\n')) {
        sb.writeln('#COM:$line');
      }
    }

    File(filePath).writeAsStringSync(sb.toString());
  }

  static List<String> _splitFields(String data) {
    return data.split(',').map((s) => s.trim()).toList();
  }

  static double _parseAafTimezone(String s) {
    s = s.trim().toLowerCase();
    if (s.isEmpty || s == '0') return 0.0;

    final eastMatch = RegExp(r'^(\d+)e(\d*)$').firstMatch(s);
    if (eastMatch != null) {
      final h = int.parse(eastMatch.group(1)!);
      final m = eastMatch.group(2)!.isNotEmpty
          ? int.parse(eastMatch.group(2)!)
          : 0;
      return h + m / 60.0;
    }

    final westMatch = RegExp(r'^(\d+)w(\d*)$').firstMatch(s);
    if (westMatch != null) {
      final h = int.parse(westMatch.group(1)!);
      final m = westMatch.group(2)!.isNotEmpty
          ? int.parse(westMatch.group(2)!)
          : 0;
      return -(h + m / 60.0);
    }

    return double.tryParse(s) ?? 0.0;
  }

  static String _formatAafTimezone(double hours) {
    if (hours == 0) return '0';
    final dir = hours >= 0 ? 'e' : 'w';
    final abs = hours.abs();
    final h = abs.floor();
    final m = ((abs - h) * 60).round();
    return m > 0 ? '$h$dir$m' : '$h$dir';
  }

  static double _parseAafCoord(String s) {
    s = s.trim().toLowerCase();
    final match = RegExp(r'^(\d+)([nesw])(\d*)$').firstMatch(s);
    if (match == null) return double.tryParse(s) ?? 0.0;
    final deg = int.parse(match.group(1)!);
    final dir = match.group(2)!;
    final min = match.group(3)!.isNotEmpty ? int.parse(match.group(3)!) : 0;
    var val = deg + min / 60.0;
    if (dir == 'w' || dir == 's') val = -val;
    return val;
  }

  static String _formatAafCoord(double value, String suffix) {
    final abs = value.abs();
    final deg = abs.floor();
    final min = ((abs - deg) * 60).round();
    return '$deg$suffix$min';
  }
}
