import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';

/// A single exportable row — one per result card.
class ExportRow {
  const ExportRow({required this.header, required this.fields});

  /// Row identifier (e.g. "Sun", "House I", "Lahiri").
  final String header;

  /// Ordered (label, value) pairs using the current display format.
  final List<(String, String)> fields;
}

/// Available export formats.
enum ExportFormat { tsvClipboard, colonClipboard, csvFile, jsonFile }

/// Pure-function export logic — no widget dependency.
class ExportService {
  ExportService._();

  // ── Clipboard formats ──

  /// Tab-separated values: header row + data rows.
  static String toTsv(List<ExportRow> rows) {
    if (rows.isEmpty) return '';
    final labels = _allLabels(rows);
    final buf = StringBuffer();
    buf.writeln(['Name', ...labels].join('\t'));
    for (final row in rows) {
      final valuesByLabel = _fieldMap(row);
      buf.writeln(
        [row.header, ...labels.map((l) => valuesByLabel[l] ?? '')].join('\t'),
      );
    }
    return buf.toString().trimRight();
  }

  /// Colon-separated: matches per-card copy style.
  /// ```
  /// Sun
  /// Longitude: 284°32'15"
  /// Latitude: 0°00'00"
  ///
  /// Moon
  /// ...
  /// ```
  static String toColonSeparated(List<ExportRow> rows) {
    final buf = StringBuffer();
    for (final row in rows) {
      buf.writeln(row.header);
      for (final (label, value) in row.fields) {
        buf.writeln('$label: $value');
      }
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  // ── File formats ──

  /// RFC 4180 CSV.
  static String toCsv(List<ExportRow> rows) {
    if (rows.isEmpty) return '';
    final labels = _allLabels(rows);
    final buf = StringBuffer();
    buf.writeln(['Name', ...labels].map(_csvEscape).join(','));
    for (final row in rows) {
      final valuesByLabel = _fieldMap(row);
      buf.writeln(
        [row.header, ...labels.map((l) => valuesByLabel[l] ?? '')]
            .map(_csvEscape)
            .join(','),
      );
    }
    return buf.toString().trimRight();
  }

  /// JSON array of objects.
  static String toJson(List<ExportRow> rows) {
    final list = rows.map((row) {
      final map = <String, String>{'Name': row.header};
      for (final (label, value) in row.fields) {
        map[label] = value;
      }
      return map;
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  // ── Dispatch ──

  /// Export rows in the given format.
  /// Returns a human-readable status message for snackbar display.
  static Future<String> export(
    List<ExportRow> rows,
    ExportFormat format,
    String filenameStem,
  ) async {
    switch (format) {
      case ExportFormat.tsvClipboard:
        await Clipboard.setData(ClipboardData(text: toTsv(rows)));
        return 'Copied ${rows.length} results (TSV)';
      case ExportFormat.colonClipboard:
        await Clipboard.setData(ClipboardData(text: toColonSeparated(rows)));
        return 'Copied ${rows.length} results';
      case ExportFormat.csvFile:
        return _saveFile(toCsv(rows), filenameStem, 'csv', MimeType.csv);
      case ExportFormat.jsonFile:
        return _saveFile(toJson(rows), filenameStem, 'json', MimeType.json);
    }
  }

  static Future<String> _saveFile(
    String content,
    String stem,
    String ext,
    MimeType mime,
  ) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    try {
      // saveAs shows a file dialog on desktop; throws on web.
      final path = await FileSaver.instance.saveAs(
        name: stem,
        bytes: bytes,
        fileExtension: ext,
        mimeType: mime,
      );
      if (path != null) return 'Saved $stem.$ext';
      return 'Save cancelled';
    } catch (_) {
      // Fallback (web): auto-download.
      await FileSaver.instance.saveFile(
        name: stem,
        bytes: bytes,
        fileExtension: ext,
        mimeType: mime,
      );
      return 'Downloaded $stem.$ext';
    }
  }

  /// Union of all field labels across rows, preserving first-appearance order.
  static List<String> _allLabels(List<ExportRow> rows) {
    final seen = <String>{};
    final labels = <String>[];
    for (final row in rows) {
      for (final (label, _) in row.fields) {
        if (seen.add(label)) labels.add(label);
      }
    }
    return labels;
  }

  static Map<String, String> _fieldMap(ExportRow row) {
    return {for (final (label, value) in row.fields) label: value};
  }

  static String _csvEscape(String value) {
    if (value.contains(RegExp(r'[,"\n\r]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
