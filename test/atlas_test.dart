// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/atlas/atlas.dart';

// Columns: name, admin1, country, lat, lon, population, tz.
// Rows are population-descending, as the bundled asset is.
const _tsv = '''
New York City\tNew York\tUnited States\t40.71427\t-74.00597\t8804190\tAmerica/New_York
York\tEngland\tUnited Kingdom\t53.95763\t-1.08271\t153717\tEurope/London
Springfield\tMissouri\tUnited States\t37.21533\t-93.29824\t170188\tAmerica/Chicago
Springfield\tIllinois\tUnited States\t39.80172\t-89.64371\t114394\tAmerica/Chicago
Vatican City\t\tVatican\t41.90236\t12.45332\t829\tEurope/Vatican
\tbad\trow\tnotanumber\t0\t5\tX''';

void main() {
  final atlas = InMemoryAtlas.parse(_tsv);

  test('parse skips rows with unparseable coordinates', () {
    // The trailing "bad" row has a non-numeric latitude and must be dropped;
    // every good row remains reachable.
    expect(atlas.search('a', limit: 100).any((h) => h.country == 'row'), false);
  });

  test('prefix matches rank above substring matches', () {
    final hits = atlas.search('york');
    // "York" (prefix) precedes "New York City" (substring) despite NYC's far
    // larger population.
    expect(hits.first.name, 'York');
    expect(hits.map((h) => h.name), contains('New York City'));
    expect(
      hits.indexWhere((h) => h.name == 'York'),
      lessThan(hits.indexWhere((h) => h.name == 'New York City')),
    );
  });

  test('within a match group, higher population comes first', () {
    final hits = atlas.search('springfield');
    expect(hits.map((h) => h.admin1).toList(), ['Missouri', 'Illinois']);
  });

  test('search is case-insensitive', () {
    expect(atlas.search('SPRINGFIELD').length, 2);
  });

  test('label disambiguates with admin1, or falls back to country', () {
    final springfield = atlas.search('springfield').first;
    expect(springfield.label, 'Springfield, Missouri, United States');
    final vatican = atlas.search('vatican').first;
    expect(vatican.label, 'Vatican City, Vatican');
  });

  test('empty query returns nothing', () {
    expect(atlas.search('   '), isEmpty);
  });
}
