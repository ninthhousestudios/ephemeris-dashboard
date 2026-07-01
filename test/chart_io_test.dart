import 'dart:convert';

import 'package:charts_dart/charts_dart.dart' hide ChartIO;
import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/chart_io.dart';

ChartData _sampleChart() => ChartData(
  name: 'São Paulo Müller',
  dateTime: DateTime(1990, 6, 15, 14, 30),
  birthLocation: GeoLocation(
    city: 'São Paulo',
    country: 'Brasil',
    latitude: -23.55,
    longitude: -46.63,
  ),
  utcOffsetHours: -3,
);

void main() {
  group('ChartIO.readBytes decodes non-ASCII text formats as UTF-8', () {
    test('.json', () {
      final bytes = utf8.encode(JsonChartFormat.encode(_sampleChart()));
      final chart = ChartIO.readBytes(bytes, 'chart.json');
      expect(chart.name, 'São Paulo Müller');
      expect(chart.birthLocation.city, 'São Paulo');
    });

    test('.csv', () {
      final bytes = utf8.encode(CsvChartFormat.encode(_sampleChart()));
      final chart = ChartIO.readBytes(bytes, 'chart.csv');
      expect(chart.name, 'São Paulo Müller');
      expect(chart.birthLocation.city, 'São Paulo');
    });

    test('.toml', () {
      final bytes = utf8.encode(TomlChartFormat.encode(_sampleChart()));
      final chart = ChartIO.readBytes(bytes, 'chart.toml');
      expect(chart.name, 'São Paulo Müller');
      expect(chart.birthLocation.city, 'São Paulo');
    });

    test('.aaf', () {
      final bytes = utf8.encode(AafFormat.encode(_sampleChart()));
      final chart = ChartIO.readBytes(bytes, 'chart.aaf');
      expect(chart.birthLocation.city, 'São Paulo');
    });
  });
}
