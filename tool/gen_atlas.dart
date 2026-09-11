// Generates the bundled city atlas asset from GeoNames source dumps.
//
// Source (GeoNames, CC-BY 4.0 — https://www.geonames.org/):
//   cities5000.txt          — cities with population > 5000
//   admin1CodesASCII.txt    — admin1 code -> name
//   countryInfo.txt         — country code -> name
//
// Output: assets/atlas/cities.tsv, columns (tab-separated):
//   name  admin1  country  lat  lon  population  tz
// Sorted by population descending so the runtime atlas can filter without
// re-ranking. Timezone is retained (unused today) for a future approximate
// local-time feature — retaining it avoids re-sourcing the dump.
//
// Usage:
//   dart run tool/gen_atlas.dart <geonames_dir> [out.tsv]
// where <geonames_dir> holds the three source files above.

import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/gen_atlas.dart <geonames_dir> [out.tsv]',
    );
    exit(64);
  }
  final srcDir = args[0];
  final outPath = args.length > 1 ? args[1] : 'assets/atlas/cities.tsv';

  final countryName = _loadCountryNames('$srcDir/countryInfo.txt');
  final admin1Name = _loadAdmin1Names('$srcDir/admin1CodesASCII.txt');

  final rows = <_City>[];
  for (final line in File('$srcDir/cities5000.txt').readAsLinesSync()) {
    if (line.isEmpty) continue;
    final f = line.split('\t');
    // GeoNames columns: 1 name, 4 lat, 5 lon, 8 country, 10 admin1,
    // 14 population, 17 timezone.
    final name = f[1];
    final cc = f[8];
    final admin1Code = f[10];
    final admin1 = admin1Name['$cc.$admin1Code'] ?? '';
    final country = countryName[cc] ?? cc;
    final population = int.tryParse(f[14]) ?? 0;
    rows.add(
      _City(
        name: name,
        admin1: admin1,
        country: country,
        lat: f[4],
        lon: f[5],
        population: population,
        tz: f[17],
      ),
    );
  }

  rows.sort((a, b) => b.population.compareTo(a.population));

  final out = File(outPath);
  out.parent.createSync(recursive: true);
  final sink = out.openWrite();
  for (final c in rows) {
    sink.writeln(
      [
        c.name,
        c.admin1,
        c.country,
        c.lat,
        c.lon,
        c.population,
        c.tz,
      ].join('\t'),
    );
  }
  sink.close();
  stdout.writeln('wrote ${rows.length} cities to $outPath');
}

Map<String, String> _loadCountryNames(String path) {
  final map = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    if (line.startsWith('#') || line.isEmpty) continue;
    final f = line.split('\t');
    if (f.length > 4) map[f[0]] = f[4]; // ISO code -> country name
  }
  return map;
}

Map<String, String> _loadAdmin1Names(String path) {
  final map = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    if (line.isEmpty) continue;
    final f = line.split('\t');
    if (f.length > 1) map[f[0]] = f[1]; // "CC.code" -> admin1 name
  }
  return map;
}

class _City {
  const _City({
    required this.name,
    required this.admin1,
    required this.country,
    required this.lat,
    required this.lon,
    required this.population,
    required this.tz,
  });

  final String name;
  final String admin1;
  final String country;
  final String lat;
  final String lon;
  final int population;
  final String tz;
}
