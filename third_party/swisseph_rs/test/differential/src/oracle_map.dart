// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

enum OracleKind { direct, composite, engineTrusted }

class OracleEntry {
  final OracleKind kind;
  final String? reason;

  const OracleEntry.direct() : kind = OracleKind.direct, reason = null;

  const OracleEntry.composite() : kind = OracleKind.composite, reason = null;

  const OracleEntry.engineTrusted(String this.reason)
    : kind = OracleKind.engineTrusted;
}

const oracleMap = <String, OracleEntry>{
  'Ephemeris.new': OracleEntry.direct(),
  'Ephemeris.calcUt': OracleEntry.direct(),
  'Ephemeris.calcUtWithConfig': OracleEntry.composite(),
  'Ephemeris.calc': OracleEntry.direct(),
  'Ephemeris.calcWithConfig': OracleEntry.composite(),
  'Ephemeris.calcPctr': OracleEntry.direct(),
  'Ephemeris.close': OracleEntry.engineTrusted(
    'lifecycle; no oracle equivalent',
  ),
  'Ephemeris.share': OracleEntry.engineTrusted(
    'refcount clone; no oracle equivalent — swisseph.dart cannot share',
  ),
  'Ephemeris.fromShareToken': OracleEntry.engineTrusted(
    'lifecycle; materializes shared handle — no oracle equivalent',
  ),
  'Ephemeris.deltaT': OracleEntry.direct(),
  'Ephemeris.siderealTime': OracleEntry.direct(),
  'Ephemeris.siderealTime0': OracleEntry.direct(),
  'Ephemeris.timeEqu': OracleEntry.direct(),
  'Ephemeris.lmtToLat': OracleEntry.direct(),
  'Ephemeris.latToLmt': OracleEntry.direct(),
  'Ephemeris.getPlanetName': OracleEntry.direct(),
  'Ephemeris.utcToJd': OracleEntry.direct(),
  'Ephemeris.jdetToUtc': OracleEntry.direct(),
  'Ephemeris.jdut1ToUtc': OracleEntry.direct(),
  'engineVersion': OracleEntry.engineTrusted(
    'reports Rust engine version; no oracle comparison',
  ),
  'exceptionFromCode': OracleEntry.engineTrusted(
    'error-code dispatch; tested by unit tests',
  ),
  'julday': OracleEntry.direct(),
  'revjul': OracleEntry.direct(),
  'dateConversion': OracleEntry.direct(),
  'dayOfWeek': OracleEntry.direct(),
  'utcTimeZone': OracleEntry.direct(),
  'splitDegrees': OracleEntry.direct(),
  'cotrans': OracleEntry.direct(),
  'cotransWithSpeed': OracleEntry.engineTrusted(
    'swisseph.dart does not wrap swe_cotrans_sp',
  ),
  'normalizeDegrees': OracleEntry.engineTrusted(
    'pure math (x % 360); oracle does not expose swe_degnorm',
  ),
  'Ephemeris.houses': OracleEntry.direct(),
  'Ephemeris.housesEx2': OracleEntry.direct(),
  'Ephemeris.gauquelinSector': OracleEntry.direct(),
  'Ephemeris.gauquelinSectorGeometric': OracleEntry.direct(),
  'Ephemeris.getAyanamsaEx': OracleEntry.composite(),
  'Ephemeris.getAyanamsaExWithConfig': OracleEntry.composite(),
  'Ephemeris.getAyanamsaUt': OracleEntry.composite(),
  'Ephemeris.getAyanamsa': OracleEntry.composite(),
  'housesArmc': OracleEntry.direct(),
  'housePos': OracleEntry.direct(),
  'houseName': OracleEntry.direct(),
  'getAyanamsaName': OracleEntry.direct(),
  'Ephemeris.solEclipseWhenGlob': OracleEntry.direct(),
  'Ephemeris.solEclipseWhenLoc': OracleEntry.direct(),
  'Ephemeris.solEclipseWhere': OracleEntry.direct(),
  'Ephemeris.solEclipseHow': OracleEntry.direct(),
  'Ephemeris.lunEclipseHow': OracleEntry.direct(),
  'Ephemeris.lunEclipseWhen': OracleEntry.direct(),
  'Ephemeris.lunEclipseWhenLoc': OracleEntry.direct(),
  'Ephemeris.lunOccultWhere': OracleEntry.direct(),
  'Ephemeris.lunOccultWhenGlob': OracleEntry.direct(),
  'Ephemeris.lunOccultWhenLoc': OracleEntry.direct(),
  // Rise/set & crossings (task /32)
  'Ephemeris.riseTrans': OracleEntry.direct(),
  'Ephemeris.riseTransTrueHor': OracleEntry.direct(),
  'Ephemeris.solcross': OracleEntry.direct(),
  'Ephemeris.solcrossUt': OracleEntry.direct(),
  'Ephemeris.mooncross': OracleEntry.direct(),
  'Ephemeris.mooncrossUt': OracleEntry.direct(),
  'Ephemeris.mooncrossNode': OracleEntry.direct(),
  'Ephemeris.mooncrossNodeUt': OracleEntry.direct(),
  'Ephemeris.helioCross': OracleEntry.direct(),
  'Ephemeris.helioCrossUt': OracleEntry.direct(),
  // Phenomena, orbital, nodes/apsides (task /33)
  'Ephemeris.phenoUt': OracleEntry.direct(),
  'Ephemeris.pheno': OracleEntry.direct(),
  'Ephemeris.nodApsUt': OracleEntry.direct(),
  'Ephemeris.nodAps': OracleEntry.direct(),
  'Ephemeris.getOrbitalElements': OracleEntry.direct(),
  'Ephemeris.orbitMaxMinTrueDistance': OracleEntry.direct(),
  'Ephemeris.phenoWithConfig': OracleEntry.composite(),
  'Ephemeris.phenoUtWithConfig': OracleEntry.composite(),
  // Horizon & refraction (task /34)
  'Ephemeris.azalt': OracleEntry.direct(),
  'Ephemeris.azaltRev': OracleEntry.direct(),
  'refrac': OracleEntry.direct(),
  'refracExtended': OracleEntry.direct(),
  // Fixed stars (task /33)
  'Ephemeris.fixstar2': OracleEntry.direct(),
  'Ephemeris.fixstar2Ut': OracleEntry.direct(),
  'Ephemeris.fixstar2WithConfig': OracleEntry.composite(),
  'Ephemeris.fixstar2UtWithConfig': OracleEntry.composite(),
  'Ephemeris.fixstar2Mag': OracleEntry.direct(),
  // Heliacal (task /33)
  'Ephemeris.heliacalUt': OracleEntry.direct(),
  'Ephemeris.heliacalPhenoUt': OracleEntry.direct(),
  'Ephemeris.visLimitMag': OracleEntry.direct(),
  'Ephemeris.heliacalAngle': OracleEntry.direct(),
  'Ephemeris.topoArcusVisionis': OracleEntry.direct(),
  // Web loader seam (task /37)
  'initializeWasm': OracleEntry.engineTrusted(
    'web-only loader seam; throws UnsupportedError on native',
  ),
  'loadEpheFile': OracleEntry.engineTrusted(
    'web-only MEMFS staging; throws UnsupportedError on native',
  ),
  'wasmAssetPath': OracleEntry.engineTrusted(
    'packaging constant naming where Flutter bundles the glue; computes '
    'nothing, so there is nothing to differ against — pinned to the pubspec '
    'asset declaration by test/integration/wasm_asset_test.dart instead',
  ),
};
