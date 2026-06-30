import 'dart:io';
import 'dart:typed_data';

import 'package:toml/toml.dart';

import '../model/chart_data.dart';

/// TOML chart format — structured, human-readable format.
/// Time stored as Julian Day number.
class TomlChartFormat {
  static ChartData read(String filePath) =>
      readBytes(File(filePath).readAsBytesSync());

  static ChartData readBytes(Uint8List bytes) {
    final content = String.fromCharCodes(bytes);
    final doc = TomlDocument.parse(content);
    final map = doc.toMap();
    return fromMap(map, filePath: '');
  }

  static ChartData fromMap(Map<String, dynamic> map, {String? filePath}) {
    final timeJD = map['timeJD'] as Map<String, dynamic>? ?? {};
    final location = map['location'] as Map<String, dynamic>? ?? {};

    final jd = (timeJD['jd'] as num?)?.toDouble() ?? 0.0;
    final utcOffset = (timeJD['utcoffset'] as num?)?.toDouble() ?? 0.0;

    final utcDt = _jdToDateTime(jd);
    final localDt = utcDt.add(Duration(minutes: (utcOffset * 60).round()));

    String name;
    final rawName = map['name'];
    if (rawName is List) {
      name = rawName.map((e) => e.toString()).join(' ').trim();
    } else {
      name = (rawName ?? _nameFromPath(filePath ?? '')).toString();
    }

    Gender? gender;
    final rawGender = map['gender'];
    if (rawGender != null) {
      gender = switch (rawGender.toString().toLowerCase()) {
        'male' || 'm' => Gender.male,
        'female' || 'f' => Gender.female,
        _ => null,
      };
    }

    var country = (map['country'] ?? '').toString();
    var placename = (location['placename'] ?? '').toString();

    if (country.isEmpty && placename.contains(',')) {
      final parts = placename.split(',').map((s) => s.trim()).toList();
      if (parts.length >= 3) {
        country = parts.last;
        placename = parts.sublist(0, parts.length - 1).join(', ');
      }
    }

    final lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
    final lon = (location['long'] as num?)?.toDouble() ?? 0.0;
    final alt = (location['alt'] as num?)?.toDouble();

    final extra = <String, dynamic>{};
    if (alt != null) extra['altitude'] = alt;
    final icao = location['icao'];
    if (icao != null) extra['icao'] = icao.toString();

    return ChartData(
      name: name,
      dateTime: localDt,
      birthLocation: GeoLocation(
        city: placename,
        country: country,
        latitude: lat,
        longitude: lon,
      ),
      utcOffsetHours: utcOffset,
      gender: gender,
      extra: extra,
    );
  }

  static void write(String filePath, ChartData chart) {
    File(filePath).writeAsStringSync(encode(chart));
  }

  static String encode(ChartData chart) {
    final jd = _dateTimeToJd(chart.utcDateTime);

    final map = <String, dynamic>{
      'name': chart.name,
      if (chart.gender != null) 'gender': chart.gender!.name,
      if (chart.birthLocation.country.isNotEmpty)
        'country': chart.birthLocation.country,
      'timeJD': {'jd': jd, 'utcoffset': chart.utcOffsetHours},
      'location': {
        'lat': chart.birthLocation.latitude,
        'long': chart.birthLocation.longitude,
        if (chart.extra.containsKey('altitude')) 'alt': chart.extra['altitude'],
        'placename': chart.birthLocation.city,
        'timezone': _formatTimezone(chart.utcOffsetHours),
        if (chart.extra.containsKey('icao')) 'icao': chart.extra['icao'],
      },
    };

    return TomlDocument.fromMap(map).toString();
  }

  static DateTime _jdToDateTime(double jd) {
    final z = (jd + 0.5).floor();
    final f = jd + 0.5 - z;
    int a;
    if (z < 2299161) {
      a = z;
    } else {
      final alpha = ((z - 1867216.25) / 36524.25).floor();
      a = z + 1 + alpha - (alpha ~/ 4);
    }
    final b = a + 1524;
    final c = ((b - 122.1) / 365.25).floor();
    final d = (365.25 * c).floor();
    final e = ((b - d) / 30.6001).floor();

    final day = b - d - (30.6001 * e).floor();
    final month = e < 14 ? e - 1 : e - 13;
    final year = month > 2 ? c - 4716 : c - 4715;

    final totalHours = f * 24.0;
    final hour = totalHours.floor();
    final totalMinutes = (totalHours - hour) * 60.0;
    final minute = totalMinutes.floor();
    final second = ((totalMinutes - minute) * 60.0).round().clamp(0, 59);

    return DateTime.utc(year, month, day, hour, minute, second);
  }

  static double _dateTimeToJd(DateTime dt) {
    var y = dt.year;
    var m = dt.month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = y ~/ 100;
    final b = 2 - a + (a ~/ 4);
    final dayFrac = (dt.hour + dt.minute / 60.0 + dt.second / 3600.0) / 24.0;
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        dt.day +
        dayFrac +
        b -
        1524.5;
  }

  static String _formatTimezone(double hours) {
    if (hours == 0) return 'UTC';
    final sign = hours >= 0 ? '' : '-';
    return '$sign${hours.abs()}';
  }

  static String _nameFromPath(String path) {
    final name = path.split('/').last.split('\\').last;
    return name.replaceAll(RegExp(r'\.toml$', caseSensitive: false), '');
  }
}
