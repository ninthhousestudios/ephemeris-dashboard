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
  });

  final String filename;
  final BodyFamily family;
  final String url;
  final int? sizeBytes;
  final String? md5;
  final int startYear;
  final int endYear;
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

/// SE catalog (Phase 1 bound): bundled range ± 2 chunks per family per
/// direction. Bundled AD covers 00–48 (0–5400 CE), BCE covers m06–m54
/// (−5399 to 0). Catalog adds chunks 50 and 52 (AD), m56 and m58 (BCE).
/// Phase 2 will extend further; for Phase 1 we keep the surface small.
const _seExtensionChunks = <({String prefix, String bceMarker, int nn})>[
  // Planets AD
  (prefix: 'sepl', bceMarker: '_', nn: 50),
  (prefix: 'sepl', bceMarker: '_', nn: 52),
  // Moon AD
  (prefix: 'semo', bceMarker: '_', nn: 50),
  (prefix: 'semo', bceMarker: '_', nn: 52),
  // Asteroids AD
  (prefix: 'seas', bceMarker: '_', nn: 50),
  (prefix: 'seas', bceMarker: '_', nn: 52),
  // Planets BCE
  (prefix: 'sepl', bceMarker: 'm', nn: 56),
  (prefix: 'sepl', bceMarker: 'm', nn: 58),
  // Moon BCE
  (prefix: 'semo', bceMarker: 'm', nn: 56),
  (prefix: 'semo', bceMarker: 'm', nn: 58),
  // Asteroids BCE
  (prefix: 'seas', bceMarker: 'm', nn: 56),
  (prefix: 'seas', bceMarker: 'm', nn: 58),
];

List<CatalogEntry> _buildSeCatalog() {
  final out = <CatalogEntry>[];
  for (final chunk in _seExtensionChunks) {
    final nnStr = chunk.nn.toString().padLeft(2, '0');
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
    out.add(CatalogEntry(
      filename: filename,
      family: family,
      url:
          'https://raw.githubusercontent.com/aloistr/swisseph/master/ephe/$filename',
      startYear: sy,
      endYear: ey,
    ));
  }
  return out;
}

final seCatalog = _buildSeCatalog();

/// Full catalog of files offered for download (JPL + SE extensions).
List<CatalogEntry> get fullCatalog => [...jplCatalog, ...seCatalog];

CatalogEntry? catalogEntryFor(String filename) {
  for (final e in fullCatalog) {
    if (e.filename == filename) return e;
  }
  return null;
}
