import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../model/chart_data.dart';

/// JSON chart format — open, human-readable format.
class JsonChartFormat {
  static ChartData read(String filePath) =>
      readBytes(File(filePath).readAsBytesSync());

  static ChartData readBytes(Uint8List bytes) {
    final content = String.fromCharCodes(bytes);
    final json = jsonDecode(content) as Map<String, dynamic>;
    return ChartData.fromJson(json);
  }

  static void write(String filePath, ChartData chart) {
    final encoder = JsonEncoder.withIndent('  ');
    File(filePath).writeAsStringSync(encoder.convert(chart.toJson()));
  }

  static String encode(ChartData chart) {
    final encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(chart.toJson());
  }

  static ChartData decode(String json) {
    return ChartData.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
}
