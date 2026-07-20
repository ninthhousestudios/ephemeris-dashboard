// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'types.dart';

/// One entry in the known-download catalog.
/// Used by the downloader + manager screen to offer files beyond the bundle.
class CatalogEntry {
  const CatalogEntry({
    required this.filename,
    required this.family,
    required this.url,
    this.sizeBytes,
    this.md5,
    this.startYear = 0,
    this.endYear = 0,
    this.subdir = '',
    this.mpcNumber,
    this.displayName,
  });

  final String filename;
  final BodyFamily family;
  final String url;
  final int? sizeBytes;
  final String? md5;
  final int startYear;
  final int endYear;

  /// Subdirectory relative to the ephe root (e.g. 'ast0'). Empty = root.
  final String subdir;

  /// For numbered asteroids, the MPC number (e.g. 433 for Eros).
  final int? mpcNumber;

  /// Pretty name used in the manager UI (e.g. 'Eros (433)'). Falls back
  /// to [filename] when absent.
  final String? displayName;
}

/// JPL DE files served from ephe.scryr.io. MD5 values copied from the
/// index page; fill in exact hashes as they are read from the site.
const jplCatalog = <CatalogEntry>[
  CatalogEntry(
    filename: 'de200.eph',
    family: BodyFamily.jpl,
    url: 'https://ephe.scryr.io/jpl/de200.eph',
    sizeBytes: 43 * 1024 * 1024,
    startYear: 1600,
    endYear: 2169,
  ),
  CatalogEntry(
    filename: 'de406e.eph',
    family: BodyFamily.jpl,
    url: 'https://ephe.scryr.io/jpl/de406e.eph',
    sizeBytes: 190 * 1024 * 1024,
    startYear: -3000,
    endYear: 3000,
  ),
  CatalogEntry(
    filename: 'de431.eph',
    family: BodyFamily.jpl,
    url: 'https://ephe.scryr.io/jpl/de431.eph',
    sizeBytes: 2700 * 1024 * 1024,
    startYear: -13000,
    endYear: 17000,
  ),
  CatalogEntry(
    filename: 'de440.eph',
    family: BodyFamily.jpl,
    url: 'https://ephe.scryr.io/jpl/de440.eph',
    sizeBytes: 110 * 1024 * 1024,
    startYear: 1550,
    endYear: 2650,
  ),
  CatalogEntry(
    filename: 'de441.eph',
    family: BodyFamily.jpl,
    url: 'https://ephe.scryr.io/jpl/de441.eph',
    sizeBytes: 3100 * 1024 * 1024,
    startYear: -13200,
    endYear: 17191,
  ),
];

/// SE catalog: bundled range is 00–48 (AD) + m06–m54 (BCE). Chunk files
/// step by 6 (each covers 600 years) in the aloistr/swisseph `ephe/`
/// directory. Past NN=99 the filename uses 3 digits (`sepl_102.se1`).
/// We list the next four AD + BCE chunks per family.
const _seExtensionAdStarts = <int>[54, 60, 66, 72];
const _seExtensionBceStarts = <int>[60, 66, 72, 78];
const _seFamilyPrefixes = <String>['sepl', 'semo', 'seas'];

List<CatalogEntry> _buildSeCatalog() {
  final out = <CatalogEntry>[];
  final chunks = <({String prefix, String bceMarker, int nn})>[
    for (final p in _seFamilyPrefixes)
      for (final nn in _seExtensionAdStarts)
        (prefix: p, bceMarker: '_', nn: nn),
    for (final p in _seFamilyPrefixes)
      for (final nn in _seExtensionBceStarts)
        (prefix: p, bceMarker: 'm', nn: nn),
  ];
  for (final chunk in chunks) {
    // Aloistr filenames use 2 digits below 100, 3 digits above.
    final nnStr = chunk.nn < 100
        ? chunk.nn.toString().padLeft(2, '0')
        : chunk.nn.toString();
    final filename = '${chunk.prefix}${chunk.bceMarker}$nnStr.se1';
    final family = switch (chunk.prefix) {
      'sepl' => BodyFamily.planets,
      'semo' => BodyFamily.moon,
      'seas' => BodyFamily.mainAsteroids,
      _ => BodyFamily.unknown,
    };
    final (int sy, int ey) = chunk.bceMarker == '_'
        ? (chunk.nn * 100, chunk.nn * 100 + 600)
        : (-(chunk.nn * 100 - 1), -(chunk.nn * 100 - 1) + 599);
    out.add(
      CatalogEntry(
        filename: filename,
        family: family,
        url:
            'https://raw.githubusercontent.com/aloistr/swisseph/master/ephe/$filename',
        startYear: sy,
        endYear: ey,
      ),
    );
  }
  return out;
}

final seCatalog = _buildSeCatalog();

// ── Numbered asteroids ──
//
// Aloistr hosts one `seNNNNNs.se1` per asteroid under `ephe/astX/` where
// `X = MPC ~/ 1000`. We seed the catalog with the set we surface as chips
// on the Planets tab, plus a helper to conjure an entry for any MPC number
// on the fly (`asteroidCatalogEntryFor`) so the user isn't blocked on
// arbitrary numbers we didn't pre-register.

/// Subdir ('astX') for an MPC asteroid number. X = floor(N / 1000).
String asteroidSubdirFor(int mpcNumber) => 'ast${mpcNumber ~/ 1000}';

/// Canonical short-file filename for an MPC asteroid number.
/// Below 100000: `seNNNNNs.se1` (5 digits, 'se' prefix).
/// At/above 100000: `sNNNNNNs.se1` (6 digits, 's' prefix — note one less 'e').
String asteroidFilenameFor(int mpcNumber) {
  if (mpcNumber < 100000) {
    return 'se${mpcNumber.toString().padLeft(5, '0')}s.se1';
  }
  return 's${mpcNumber.toString().padLeft(6, '0')}s.se1';
}

/// Build a catalog entry for an arbitrary MPC asteroid number.
/// Returns null for non-positive inputs or MPC 1–4, which have no
/// standalone files on the scryr.io host (they live in bundled
/// `seas_*.se1` main-asteroid chunks only).
CatalogEntry? asteroidCatalogEntryFor(int mpcNumber, {String? displayName}) {
  if (mpcNumber < 5) return null;
  final filename = asteroidFilenameFor(mpcNumber);
  final subdir = asteroidSubdirFor(mpcNumber);
  return CatalogEntry(
    filename: filename,
    family: BodyFamily.numberedAsteroid,
    url: 'https://ephe.scryr.io/ephe/$subdir/$filename',
    subdir: subdir,
    mpcNumber: mpcNumber,
    displayName: displayName == null
        ? '#$mpcNumber'
        : '$displayName ($mpcNumber)',
  );
}

/// Seed list: the asteroids we offer as named chips on Planets tab, plus
/// a handful of well-known outer bodies. Users can still add any MPC
/// number on the fly via `asteroidCatalogEntryFor`.
const _asteroidSeed = <(int, String)>[
  (5, 'Astraea'),
  (6, 'Hebe'),
  (7, 'Iris'),
  (8, 'Flora'),
  (9, 'Metis'),
  (10, 'Hygiea'),
  (16, 'Psyche'),
  (433, 'Eros'),
  (1221, 'Amor'),
  (2060, 'Chiron'),
  (5145, 'Pholus'),
  (7066, 'Nessus'),
  (50000, 'Quaoar'),
  (90377, 'Sedna'),
  (90482, 'Orcus'),
  (136108, 'Haumea'),
  (136199, 'Eris'),
  (136472, 'Makemake'),
  (225088, 'Gonggong'),
];

final asteroidCatalog = <CatalogEntry>[
  for (final (mpc, name) in _asteroidSeed)
    asteroidCatalogEntryFor(mpc, displayName: name)!,
];

// ── Planetary moons & COB (sat/ subdir) ──

const _satelliteSeed = <(int, String)>[
  (9401, 'Phobos'),
  (9402, 'Deimos'),
  (9501, 'Io'),
  (9502, 'Europa'),
  (9503, 'Ganymede'),
  (9504, 'Callisto'),
  (9599, 'Jupiter COB'),
  (9601, 'Mimas'),
  (9602, 'Enceladus'),
  (9603, 'Tethys'),
  (9604, 'Dione'),
  (9605, 'Rhea'),
  (9606, 'Titan'),
  (9607, 'Hyperion'),
  (9608, 'Iapetus'),
  (9699, 'Saturn COB'),
  (9701, 'Ariel'),
  (9702, 'Umbriel'),
  (9703, 'Titania'),
  (9704, 'Oberon'),
  (9705, 'Miranda'),
  (9799, 'Uranus COB'),
  (9801, 'Triton'),
  (9802, 'Nereid'),
  (9808, 'Proteus'),
  (9899, 'Neptune COB'),
  (9901, 'Charon'),
  (9902, 'Nix'),
  (9903, 'Hydra'),
  (9904, 'Kerberos'),
  (9905, 'Styx'),
  (9999, 'Pluto COB'),
];

final satelliteCatalog = <CatalogEntry>[
  for (final (bodyId, name) in _satelliteSeed)
    CatalogEntry(
      filename: 'sepm$bodyId.se1',
      family: BodyFamily.satellite,
      url:
          'https://raw.githubusercontent.com/aloistr/swisseph/master/ephe/sat/sepm$bodyId.se1',
      subdir: 'sat',
      displayName: name,
    ),
];

// ── Comets (pseudo-MPC numbers, stored as numbered asteroids in ast999/) ──

const _cometSeed = <(int, String)>[
  (999032, '67P/Churyumov-Gerasimenko'),
  (999043, 'C/2020 F3 (NEOWISE)'),
  (999044, '1P/Halley'),
  (999045, "1I/'Oumuamua"),
  (999046, 'Hale-Bopp'),
  (999047, 'West'),
];

final cometCatalog = <CatalogEntry>[
  for (final (mpc, name) in _cometSeed)
    asteroidCatalogEntryFor(mpc, displayName: name)!,
];

/// Full catalog of files offered for download (JPL + SE extensions +
/// seeded asteroids + satellites + comets). On-the-fly MPC entries come
/// from [asteroidCatalogEntryFor], not this list.
List<CatalogEntry> get fullCatalog => [
  ...jplCatalog,
  ...seCatalog,
  ...asteroidCatalog,
  ...satelliteCatalog,
  ...cometCatalog,
];

CatalogEntry? catalogEntryFor(String filename) {
  for (final e in fullCatalog) {
    if (e.filename == filename) return e;
  }
  // Fall back to synthesizing an entry for any numbered-asteroid filename
  // so bulk/range downloads don't need pre-seeded entries. Two schemes:
  // `seNNNNN[s].se1` (MPC < 100000) and `sNNNNNN[s].se1` (MPC >= 100000).
  final m = RegExp(r'^se?(\d+)s?\.se1$').firstMatch(filename);
  if (m != null) {
    final mpc = int.parse(m.group(1)!);
    return asteroidCatalogEntryFor(mpc);
  }
  return null;
}
