// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';
import 'dart:typed_data';

import 'package:charts_dart/charts_dart.dart' hide ChartIO;
import 'package:path/path.dart' as p;

export 'package:charts_dart/charts_dart.dart'
    show ChartData, GeoLocation, PlanetPosition, Gender;

/// Chart file I/O for the dashboard.
///
/// charts_dart's own `ChartIO` only reads/writes via file paths (dart:io).
/// This dispatches by extension to each format's pure `parseString`/
/// `parseBytes` API so loading works from in-memory bytes too (web/mobile
/// file pickers, which can't touch the filesystem).
class ChartIO {
  static const supportedExtensions = [
    '.chtk',
    '.jhd',
    '.aaf',
    '.as',
    '.json',
    '.csv',
    '.toml',
    '.qck',
  ];

  static const formatDescriptions = {
    '.chtk': 'Kala Vedic Astrology',
    '.jhd': 'Jagannatha Hora',
    '.aaf': 'AAF\'97 Astrological Exchange Format',
    '.as': 'Astrolog',
    '.json': 'JSON (charts_dart native)',
    '.csv': 'CSV tabular',
    '.toml': 'TOML (Open Astrology Chart)',
    '.qck': 'Quick*Chart (Solar Fire / Astrolog interchange)',
  };

  /// File extension filter strings for file_picker.
  static final pickerExtensions = supportedExtensions
      .map((e) => e.substring(1))
      .toList();

  /// Read a chart from any supported format (native — uses dart:io).
  static ChartData read(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    return switch (ext) {
      '.chtk' => ChtkFormat.read(filePath),
      '.jhd' => JhdFormat.read(filePath),
      '.aaf' => AafFormat.read(filePath),
      '.as' => AstrologFormat.read(filePath),
      '.json' => JsonChartFormat.read(filePath),
      '.csv' => CsvChartFormat.read(filePath),
      '.toml' => TomlChartFormat.read(filePath),
      '.qck' => QckFormat.read(filePath),
      _ => throw UnsupportedError('Unknown chart format: $ext'),
    };
  }

  /// Read a chart from raw bytes + filename (web / mobile file picker).
  static ChartData readBytes(Uint8List bytes, String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return switch (ext) {
      '.chtk' => ChtkFormat.parseBytes(bytes),
      '.jhd' => JhdFormat.parseString(_decode(bytes), fileName: fileName),
      '.aaf' => AafFormat.parseString(_decode(bytes)),
      '.as' => AstrologFormat.parseString(_decode(bytes), fileName: fileName),
      '.json' => JsonChartFormat.decode(_decode(bytes)),
      '.csv' => CsvChartFormat.parseString(_decode(bytes)),
      '.toml' => TomlChartFormat.parseString(
        _decode(bytes),
        fileName: fileName,
      ),
      '.qck' => QckFormat.parseString(_decode(bytes)),
      _ => throw UnsupportedError('Unknown chart format: $ext'),
    };
  }

  /// Decode text-format bytes as UTF-8, matching the desktop `read()` path
  /// (charts_dart's per-format `read` uses `File.readAsStringSync()`, which
  /// defaults to UTF-8). CHTK is UTF-16LE and goes through `parseBytes`
  /// directly, bypassing this.
  static String _decode(Uint8List bytes) => utf8.decode(bytes);
}
