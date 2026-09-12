// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ephe/dir_provider.dart';
import 'atlas_store.dart';

/// One city in the bundled gazetteer.
///
/// Geocoding data © GeoNames (CC BY 4.0). The [tz] IANA zone is retained from
/// the source but not yet consumed — a future approximate local-time feature
/// can use it without re-sourcing the asset.
class LocationHit {
  const LocationHit({
    required this.name,
    required this.admin1,
    required this.country,
    required this.lat,
    required this.lon,
    required this.tz,
  });

  final String name;
  final String admin1;
  final String country;
  final double lat;
  final double lon;
  final String tz;

  /// Disambiguated display string, e.g. "Springfield, Illinois, United States".
  String get label =>
      admin1.isEmpty ? '$name, $country' : '$name, $admin1, $country';
}

/// Searchable gazetteer over a fixed set of cities.
abstract interface class Atlas {
  /// Cities matching [query], name-prefix matches first, then substring —
  /// each group already in descending-population order. Capped at [limit].
  List<LocationHit> search(String query, {int limit});
}

/// In-memory atlas backed by the bundled TSV, pre-sorted by population so a
/// query is a single linear scan with no re-ranking.
class InMemoryAtlas implements Atlas {
  InMemoryAtlas._(this._entries, this._names);

  final List<LocationHit> _entries;
  // Lowercased names, parallel to [_entries] — precomputed so a keystroke
  // never re-lowercases the whole gazetteer.
  final List<String> _names;

  /// Parse the bundled `cities.tsv` (columns:
  /// name, admin1, country, lat, lon, population, tz).
  factory InMemoryAtlas.parse(String tsv) {
    final entries = <LocationHit>[];
    final names = <String>[];
    for (final line in tsv.split('\n')) {
      if (line.isEmpty) continue;
      final f = line.split('\t');
      if (f.length < 7) continue;
      final lat = double.tryParse(f[3]);
      final lon = double.tryParse(f[4]);
      if (lat == null || lon == null) continue;
      entries.add(
        LocationHit(
          name: f[0],
          admin1: f[1],
          country: f[2],
          lat: lat,
          lon: lon,
          tz: f[6],
        ),
      );
      names.add(f[0].toLowerCase());
    }
    return InMemoryAtlas._(entries, names);
  }

  @override
  List<LocationHit> search(String query, {int limit = 50}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final prefix = <LocationHit>[];
    final contains = <LocationHit>[];
    for (var i = 0; i < _entries.length; i++) {
      final n = _names[i];
      if (n.startsWith(q)) {
        prefix.add(_entries[i]);
        if (prefix.length >= limit) break;
      } else if (n.contains(q) && contains.length < limit) {
        contains.add(_entries[i]);
      }
    }
    for (final c in contains) {
      if (prefix.length >= limit) break;
      prefix.add(c);
    }
    return prefix;
  }
}

/// Loads the gazetteer once, preferring a higher-coverage tier the user has
/// downloaded into `<ephe-root>/atlas/` over the bundled cities5000. On web
/// (no managed filesystem) this is always the bundle.
///
/// Not reactive to the filesystem: the ephemeris manager invalidates this
/// provider when an atlas tier is downloaded or deleted.
final atlasProvider = FutureProvider<Atlas>((ref) async {
  final dir = ref.watch(resolvedEphePathProvider);
  if (dir != null) {
    final installed = await loadInstalledAtlasTsv(dir);
    if (installed != null) return InMemoryAtlas.parse(installed);
  }
  final tsv = await rootBundle.loadString('assets/atlas/cities.tsv');
  return InMemoryAtlas.parse(tsv);
});
