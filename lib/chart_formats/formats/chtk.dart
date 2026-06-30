import 'dart:io';
import 'dart:typed_data';

import '../model/chart_data.dart';

/// Kala Vedic Astrology .chtk format.
///
/// UTF-16 LE encoded plain text, one value per line.
/// Two location blocks: birth + current/observer.
/// Sentinel lines: `~end of notes~` and `~end of muhurtas~`.
class ChtkFormat {
  /// Read a .chtk file and return a [ChartData].
  static ChartData read(String filePath) =>
      readBytes(File(filePath).readAsBytesSync());

  /// Read from raw bytes.
  static ChartData readBytes(Uint8List bytes) {
    final content = _decodeUtf16Le(bytes);
    final lines = content.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();

    // Remove empty trailing lines
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    if (lines.length < 13) {
      throw FormatException(
        'Invalid .chtk file: expected at least 13 lines, got ${lines.length}',
      );
    }
    final name = lines[0];
    final year = int.tryParse(lines[1]) ?? 2000;
    final month = int.tryParse(lines[2]) ?? 1;
    final day = int.tryParse(lines[3]) ?? 1;
    final hour = int.tryParse(lines[4]) ?? 0;
    final minute = int.tryParse(lines[5]) ?? 0;
    final second = int.tryParse(lines[6]) ?? 0;
    final genderCode = int.tryParse(lines[7]) ?? 0;
    final country = lines[8];
    final city = lines[9];
    final longitude = _parseDms(lines[10]);
    final latitude = _parseDms(lines[11]);
    final utcOffset = _parseUtcOffset(lines[12]);

    // Line 13 may be DST flag
    var dstOffset = 0.0;
    var idx = 13;
    if (idx < lines.length) {
      final maybeFlag = int.tryParse(lines[idx]);
      if (maybeFlag != null) {
        dstOffset = 0.0;
        idx++;
      }
    }

    // Scan for notes
    final noteLines = <String>[];
    while (idx < lines.length && lines[idx] != '~end of notes~') {
      if (lines[idx].isNotEmpty) noteLines.add(lines[idx]);
      idx++;
    }
    if (idx < lines.length) idx++; // skip sentinel

    // Scan for muhurtas
    while (idx < lines.length && lines[idx] != '~end of muhurtas~') {
      idx++;
    }
    if (idx < lines.length) idx++; // skip sentinel

    // After muhurtas: current location block
    GeoLocation? currentLoc;
    double? currentUtcOffset;
    if (idx + 6 < lines.length) {
      idx++; // muhurta count
      idx++; // location preset name
      final curCountry = idx < lines.length ? lines[idx++] : '';
      final curCity = idx < lines.length ? lines[idx++] : '';
      final curLon = idx < lines.length ? _parseDms(lines[idx++]) : 0.0;
      final curLat = idx < lines.length ? _parseDms(lines[idx++]) : 0.0;
      final curOffset = idx < lines.length
          ? _parseUtcOffset(lines[idx++])
          : 0.0;
      currentLoc = GeoLocation(
        city: curCity,
        country: curCountry,
        latitude: curLat,
        longitude: curLon,
      );
      currentUtcOffset = curOffset;
    }

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
      dstOffsetHours: dstOffset,
      gender: genderCode == 2
          ? Gender.female
          : genderCode == 1
          ? Gender.male
          : null,
      notes: noteLines.isNotEmpty ? noteLines.join('\n') : null,
      currentLocation: currentLoc,
      currentUtcOffsetHours: currentUtcOffset,
    );
  }

  /// Write a [ChartData] to .chtk format.
  static void write(String filePath, ChartData chart) {
    final sb = StringBuffer();
    sb.writeln(chart.name);
    sb.writeln(chart.dateTime.year);
    sb.writeln(chart.dateTime.month);
    sb.writeln(chart.dateTime.day);
    sb.writeln(chart.dateTime.hour);
    sb.writeln(chart.dateTime.minute);
    sb.writeln(chart.dateTime.second);

    final gc = chart.gender == Gender.female
        ? 2
        : chart.gender == Gender.male
        ? 1
        : 0;
    sb.writeln(gc);
    sb.writeln(chart.birthLocation.country);
    sb.writeln(chart.birthLocation.city);
    sb.writeln(_formatDmsLon(chart.birthLocation.longitude));
    sb.writeln(_formatDmsLat(chart.birthLocation.latitude));
    sb.writeln(_formatUtcOffset(chart.utcOffsetHours));
    sb.writeln('0'); // DST flag

    if (chart.notes != null && chart.notes!.isNotEmpty) {
      sb.writeln(chart.notes);
    }
    sb.writeln('~end of notes~');
    sb.writeln('');
    sb.writeln('~end of muhurtas~');
    sb.writeln('0'); // muhurta count

    if (chart.currentLocation != null) {
      sb.writeln('Custom');
      sb.writeln(chart.currentLocation!.country);
      sb.writeln(chart.currentLocation!.city);
      sb.writeln(_formatDmsLon(chart.currentLocation!.longitude));
      sb.writeln(_formatDmsLat(chart.currentLocation!.latitude));
      sb.writeln(
        _formatUtcOffset(chart.currentUtcOffsetHours ?? chart.utcOffsetHours),
      );
      sb.writeln('0');
      sb.writeln('XX00');
    }

    final encoded = _encodeUtf16Le(sb.toString());
    File(filePath).writeAsBytesSync(encoded);
  }

  static double _parseDms(String s) {
    s = s.trim();
    final match = RegExp(
      r"(\d+)([NESW])(\d+)'(\d+)",
    ).firstMatch(s.toUpperCase());
    if (match == null) return 0.0;
    final deg = int.parse(match.group(1)!);
    final dir = match.group(2)!;
    final min = int.parse(match.group(3)!);
    final sec = int.parse(match.group(4)!);
    var val = deg + min / 60.0 + sec / 3600.0;
    if (dir == 'W' || dir == 'S') val = -val;
    return val;
  }

  static String _formatDmsLon(double lon) {
    final dir = lon >= 0 ? 'E' : 'W';
    final abs = lon.abs();
    final deg = abs.floor();
    final min = ((abs - deg) * 60).floor();
    final sec = (((abs - deg) * 60 - min) * 60).round();
    return '${deg.toString().padLeft(3, '0')}$dir'
        "${min.toString().padLeft(2, '0')}'${sec.toString().padLeft(2, '0')}";
  }

  static String _formatDmsLat(double lat) {
    final dir = lat >= 0 ? 'N' : 'S';
    final abs = lat.abs();
    final deg = abs.floor();
    final min = ((abs - deg) * 60).floor();
    final sec = (((abs - deg) * 60 - min) * 60).round();
    return '${deg.toString().padLeft(2, '0')}$dir'
        "${min.toString().padLeft(2, '0')}'${sec.toString().padLeft(2, '0')}";
  }

  static double _parseUtcOffset(String s) {
    s = s.trim();
    if (s == 'UTC' || s == '0') return 0.0;
    // Kala stores offsets with inverted sign: "-05:30:00" means UTC+5:30.
    final negative = s.startsWith('-');
    s = s.replaceFirst(RegExp(r'^[+-]'), '');
    final parts = s.split(':');
    var hours = double.tryParse(parts[0]) ?? 0.0;
    if (parts.length > 1) hours += (double.tryParse(parts[1]) ?? 0.0) / 60;
    if (parts.length > 2) hours += (double.tryParse(parts[2]) ?? 0.0) / 3600;
    return negative ? hours : -hours;
  }

  static String _formatUtcOffset(double hours) {
    if (hours == 0) return 'UTC';
    // Invert sign back to Kala convention: UTC+5 → "-05:00:00".
    final abs = hours.abs();
    final sign = hours > 0 ? '-' : '';
    final h = abs.floor();
    final m = ((abs - h) * 60).round();
    return '$sign${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
  }

  static String _decodeUtf16Le(Uint8List bytes) {
    var start = 0;
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      start = 2;
    }
    final buf = StringBuffer();
    for (var i = start; i + 1 < bytes.length; i += 2) {
      final code = bytes[i] | (bytes[i + 1] << 8);
      buf.writeCharCode(code);
    }
    return buf.toString();
  }

  static Uint8List _encodeUtf16Le(String s) {
    final bytes = BytesBuilder();
    bytes.addByte(0xFF);
    bytes.addByte(0xFE);
    for (var i = 0; i < s.length; i++) {
      final code = s.codeUnitAt(i);
      bytes.addByte(code & 0xFF);
      bytes.addByte((code >> 8) & 0xFF);
    }
    return bytes.toBytes();
  }
}
