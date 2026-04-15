/// Canonical catalog of ayanamsa modes supported by Swiss Ephemeris.
///
/// Single source of truth for both the context-bar selector and the
/// ayanamsa tab. IDs are SE_SIDM_* constants (0..46, plus 255 for user).
class AyanamsaEntry {
  const AyanamsaEntry(this.id, this.name);
  final int id;
  final String name;
}

/// Pseudo-id used by the context-bar selector to represent "tropical / none".
/// Not a real SE_SIDM_* constant. ZodiacRef.tropical is the semantic owner;
/// this is kept for UI compatibility until the tropical/sidereal split lands.
const int ayanamsaTropicalId = -1;

/// SE_SIDM_USER — requires t0 (reference JD) and ayanT0 (value at t0).
const int ayanamsaUserId = 255;

const List<AyanamsaEntry> ayanamsaCatalog = [
  AyanamsaEntry(0, 'Fagan/Bradley'),
  AyanamsaEntry(1, 'Lahiri'),
  AyanamsaEntry(2, 'De Luce'),
  AyanamsaEntry(3, 'Raman'),
  AyanamsaEntry(4, 'Usha/Shashi'),
  AyanamsaEntry(5, 'Krishnamurti'),
  AyanamsaEntry(6, 'Djwhal Khul'),
  AyanamsaEntry(7, 'Yukteshwar'),
  AyanamsaEntry(8, 'J.N. Bhasin'),
  AyanamsaEntry(9, 'Babylonian (Kugler 1)'),
  AyanamsaEntry(10, 'Babylonian (Kugler 2)'),
  AyanamsaEntry(11, 'Babylonian (Kugler 3)'),
  AyanamsaEntry(12, 'Babylonian (Huber)'),
  AyanamsaEntry(13, 'Babylonian (ETPSC)'),
  AyanamsaEntry(14, 'Aldebaran 15 Tau'),
  AyanamsaEntry(15, 'Hipparchos'),
  AyanamsaEntry(16, 'Sassanian'),
  AyanamsaEntry(17, 'Galactic Ctr 0 Sag'),
  AyanamsaEntry(18, 'J2000'),
  AyanamsaEntry(19, 'J1900'),
  AyanamsaEntry(20, 'B1950'),
  AyanamsaEntry(21, 'Suryasiddhanta'),
  AyanamsaEntry(22, 'Suryasiddhanta (mean Sun)'),
  AyanamsaEntry(23, 'Aryabhata'),
  AyanamsaEntry(24, 'Aryabhata (mean Sun)'),
  AyanamsaEntry(25, 'SS Revati'),
  AyanamsaEntry(26, 'SS Citra'),
  AyanamsaEntry(27, 'True Citra'),
  AyanamsaEntry(28, 'True Revati'),
  AyanamsaEntry(29, 'True Pushya'),
  AyanamsaEntry(30, 'Galactic Ctr (Gilbrand)'),
  AyanamsaEntry(31, 'Gal. Equator (IAU 1958)'),
  AyanamsaEntry(32, 'Gal. Equator (True)'),
  AyanamsaEntry(33, 'Gal. Equator (Mula)'),
  AyanamsaEntry(34, 'Gal. Alignment (Mardyks)'),
  AyanamsaEntry(35, 'True Mula'),
  AyanamsaEntry(36, 'Galactic Ctr (Mula/Wilhelm)'),
  AyanamsaEntry(37, 'Aryabhata 522'),
  AyanamsaEntry(38, 'Babylonian (Britton)'),
  AyanamsaEntry(39, 'True Sheoran'),
  AyanamsaEntry(40, 'Galactic Ctr (Cochrane)'),
  AyanamsaEntry(41, 'Gal. Equator (Fiorenza)'),
  AyanamsaEntry(42, 'Valens (Moon)'),
  AyanamsaEntry(43, 'Lahiri 1940'),
  AyanamsaEntry(44, 'Lahiri VP285'),
  AyanamsaEntry(45, 'Krishnamurti VP291'),
  AyanamsaEntry(46, 'Lahiri ICRC'),
  AyanamsaEntry(ayanamsaUserId, 'User-defined'),
];

String ayanamsaName(int id) {
  for (final e in ayanamsaCatalog) {
    if (e.id == id) return e.name;
  }
  return 'Mode $id';
}
