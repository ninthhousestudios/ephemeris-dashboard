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
