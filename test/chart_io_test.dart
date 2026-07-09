// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/chart_io.dart';

// Fixtures are hand-written (not built via charts_dart's encode()) so this
// test doesn't import package:charts_dart directly — that's confined to
// lib/core/** by .sutra/rules.toml's charts-dart-at-load-sites-only.

const _jsonFixture = '''
{
  "name": "São Paulo Müller",
  "date": "1990-06-15",
  "time": "14:30:00",
  "utc_offset": -3.0,
  "dst_offset": 0.0,
  "location": {
    "city": "São Paulo",
    "country": "Brasil",
    "latitude": -23.55,
    "longitude": -46.63
  }
}
''';

const _csvFixture =
    'name,date,time,utc_offset,dst_offset,city,country,latitude,longitude,gender,rodden_rating\n'
    'São Paulo Müller,1990-06-15,14:30:00,-3,0,São Paulo,Brasil,-23.550000,-46.630000,,\n';

const _tomlFixture = '''
spec = "open-astrology-chart"
name = "São Paulo Müller"

[civil]
date = "1990-06-15"
time = "14:30:00"
utc_offset = -3.0
dst_offset = 0.0

[location]
lat = -23.55
lon = -46.63
placename = "São Paulo"
country = "Brasil"
''';

void main() {
  group('ChartIO.readBytes decodes non-ASCII text formats as UTF-8', () {
    test('.json', () {
      final chart = ChartIO.readBytes(utf8.encode(_jsonFixture), 'chart.json');
      expect(chart.name, 'São Paulo Müller');
      expect(chart.birthLocation.city, 'São Paulo');
    });

    test('.csv', () {
      final chart = ChartIO.readBytes(utf8.encode(_csvFixture), 'chart.csv');
      expect(chart.name, 'São Paulo Müller');
      expect(chart.birthLocation.city, 'São Paulo');
    });

    test('.toml', () {
      final chart = ChartIO.readBytes(utf8.encode(_tomlFixture), 'chart.toml');
      expect(chart.name, 'São Paulo Müller');
      expect(chart.birthLocation.city, 'São Paulo');
    });
  });
}
