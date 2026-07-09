// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/run_tab_calc.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/ephemeris.dart';
import '../../core/ephemeris/trace_model.dart';
import '../../core/export_service.dart';
import '../../core/flag_provider.dart';
import '../../core/swe_service.dart';

/// Common star names for quick-select chips.
const commonStars = [
  'Aldebaran',
  'Regulus',
  'Spica',
  'Antares',
  'Fomalhaut',
  'Algol',
  'Sirius',
  'Canopus',
  'Arcturus',
  'Vega',
  'Capella',
  'Rigel',
  'Betelgeuse',
  'Pollux',
];

/// Star catalog entry for autocomplete search.
class StarCatalogEntry {
  const StarCatalogEntry(this.commonName, this.bayerDesig);
  final String commonName;
  final String bayerDesig;

  /// The search term to pass to fixstar2Ut for Bayer lookup.
  String get bayerSearch => ',$bayerDesig';
}

/// Catalog of stars with common names and Bayer designations,
/// sourced from sefstars.txt. Covers the major named stars.
const starCatalog = [
  StarCatalogEntry('Aldebaran', 'alTau'),
  StarCatalogEntry('Algol', 'bePer'),
  StarCatalogEntry('Antares', 'alSco'),
  StarCatalogEntry('Regulus', 'alLeo'),
  StarCatalogEntry('Sirius', 'alCMa'),
  StarCatalogEntry('Spica', 'alVir'),
  StarCatalogEntry('Arcturus', 'alBoo'),
  StarCatalogEntry('Vega', 'alLyr'),
  StarCatalogEntry('Capella', 'alAur'),
  StarCatalogEntry('Rigel', 'bOri'),
  StarCatalogEntry('Betelgeuse', 'alOri'),
  StarCatalogEntry('Pollux', 'bGem'),
  StarCatalogEntry('Canopus', 'alCar'),
  StarCatalogEntry('Fomalhaut', 'alPsA'),
  StarCatalogEntry('Deneb', 'alCyg'),
  StarCatalogEntry('Altair', 'alAql'),
  StarCatalogEntry('Castor', 'alGem'),
  StarCatalogEntry('Procyon', 'alCMi'),
  StarCatalogEntry('Achernar', 'alEri'),
  StarCatalogEntry('Acrux', 'alCru'),
  StarCatalogEntry('Polaris', 'alUMi'),
  StarCatalogEntry('Mimosa', 'beCru'),
  StarCatalogEntry('Hadar', 'beCen'),
  StarCatalogEntry('Bellatrix', 'gOri'),
  StarCatalogEntry('Alnilam', 'epOri'),
  StarCatalogEntry('Alnitak', 'zeOri'),
  StarCatalogEntry('Mintaka', 'deOri'),
  StarCatalogEntry('Saiph', 'kaOri'),
  StarCatalogEntry('Dubhe', 'alUMa'),
  StarCatalogEntry('Merak', 'beUMa'),
  StarCatalogEntry('Alioth', 'epUMa'),
  StarCatalogEntry('Mizar', 'zeUMa'),
  StarCatalogEntry('Alkaid', 'etUMa'),
  StarCatalogEntry('Denebola', 'beLeo'),
  StarCatalogEntry('Alphard', 'alHya'),
  StarCatalogEntry('Rasalhague', 'alOph'),
  StarCatalogEntry('Shaula', 'laScor'),
  StarCatalogEntry('Sargas', 'thSco'),
  StarCatalogEntry('Kaus Australis', 'epSgr'),
  StarCatalogEntry('Nunki', 'siSgr'),
  StarCatalogEntry('Algieba', 'gaLeo'),
  StarCatalogEntry('Zubenelgenubi', 'alLib'),
  StarCatalogEntry('Zubeneschamali', 'beLib'),
  StarCatalogEntry('Unukalhai', 'alSer'),
  StarCatalogEntry('Alphecca', 'alCrB'),
  StarCatalogEntry('Dschubba', 'deSco'),
  StarCatalogEntry('Sabik', 'etOph'),
  StarCatalogEntry('Yed Prior', 'deOph'),
  StarCatalogEntry('Yed Posterior', 'epOph'),
  StarCatalogEntry('Scheat', 'bePeg'),
  StarCatalogEntry('Markab', 'alPeg'),
  StarCatalogEntry('Algenib', 'gaPeg'),
  StarCatalogEntry('Alpheratz', 'alAnd'),
  StarCatalogEntry('Mirach', 'beAnd'),
  StarCatalogEntry('Almach', 'gaAnd'),
  StarCatalogEntry('Hamal', 'alAri'),
  StarCatalogEntry('Sheratan', 'beAri'),
  StarCatalogEntry('Menkalinan', 'beAur'),
  StarCatalogEntry('Alhena', 'gaGem'),
  StarCatalogEntry('Wezen', 'deCMa'),
  StarCatalogEntry('Adhara', 'epCMa'),
  StarCatalogEntry('Aludra', 'etCMa'),
  StarCatalogEntry('Naos', 'zePup'),
  StarCatalogEntry('Suhail', 'laVel'),
  StarCatalogEntry('Avior', 'epCar'),
  StarCatalogEntry('Miaplacidus', 'beCar'),
  StarCatalogEntry('Aspidiske', 'ioCar'),
  StarCatalogEntry('Gacrux', 'gaCru'),
  StarCatalogEntry('Rigil Kentaurus', 'alCen'),
  StarCatalogEntry('Toliman', 'al2Cen'),
  StarCatalogEntry('Agena', 'beCen'),
  StarCatalogEntry('Kochab', 'beUMi'),
  StarCatalogEntry('Eltanin', 'gaDra'),
  StarCatalogEntry('Thuban', 'alDra'),
  StarCatalogEntry('Enif', 'epPeg'),
  StarCatalogEntry('Sadalmelik', 'alAqr'),
  StarCatalogEntry('Sadalsuud', 'beAqr'),
  StarCatalogEntry('Deneb Algedi', 'deCap'),
  StarCatalogEntry('Nashira', 'gaCap'),
  StarCatalogEntry('Acubens', 'alCnc'),
  StarCatalogEntry('Asellus Borealis', 'gaCnc'),
  StarCatalogEntry('Asellus Australis', 'deCnc'),
  StarCatalogEntry('Zaniah', 'etVir'),
  StarCatalogEntry('Vindemiatrix', 'epVir'),
  StarCatalogEntry('Algorab', 'deCrv'),
  StarCatalogEntry('Gienah', 'gaCrv'),
  StarCatalogEntry('Cor Caroli', 'alCVn'),
  StarCatalogEntry('Zosma', 'deLeo'),
  StarCatalogEntry('Chara', 'beCVn'),
  StarCatalogEntry('Alderamin', 'alCep'),
  StarCatalogEntry('Errai', 'gaCep'),
  StarCatalogEntry('Diphda', 'beCet'),
  StarCatalogEntry('Menkar', 'alCet'),
  StarCatalogEntry('Mira', 'omiCet'),
  StarCatalogEntry('Acamar', 'thEri'),
  StarCatalogEntry('Ankaa', 'alPhe'),
  StarCatalogEntry('Schedar', 'alCas'),
  StarCatalogEntry('Caph', 'beCas'),
  StarCatalogEntry('Ruchbah', 'deCas'),
  StarCatalogEntry('Navi', 'gaCas'),
  StarCatalogEntry('Peacock', 'alPav'),
  StarCatalogEntry('Alnair', 'alGru'),
  // Fomalhaut already in commonStars — removed duplicate (was misspelled "Formalhaut")
  StarCatalogEntry('Al Niyat', 'si1Sco'),
  StarCatalogEntry('Gal. Center', 'SgrA*'),
];

/// Current star search term (name or catalog number).
final starSearchProvider = StateProvider<String>((ref) => 'Aldebaran');

/// Display format for star results.
final starsFormatProvider = StateProvider<DisplayFormat>(
  (ref) => DisplayFormat.dms,
);

/// Result of a fixed star calculation.
class StarResult {
  const StarResult({
    required this.searchTerm,
    required this.resolvedName,
    required this.longitude,
    required this.latitude,
    required this.distance,
    required this.speedLon,
    required this.speedLat,
    required this.speedDist,
    required this.magnitude,
    required this.returnFlag,
  });

  final String searchTerm;
  final String resolvedName;
  final double longitude;
  final double latitude;
  final double distance;
  final double speedLon;
  final double speedLat;
  final double speedDist;
  final double magnitude;
  final int returnFlag;
}

/// Pure compute: resolve a fixed star by name, with Bayer-prefix retry.
/// Returns null when the search term doesn't match any star (not an error).
StarResult? computeStar({
  required Ephemeris eph,
  required double jdUt,
  required int iflag,
  required String searchTerm,
  required double Function(String) getMagnitude,
}) {
  final term = searchTerm.trim();
  if (term.isEmpty) return null;

  final flags = iflag | seFlgSpeed;
  var r = eph.fixstar2Ut(term, jdUt, flags);

  // swisseph silently returns the first star (Aldebaran) when a search
  // doesn't match. Detect this by checking if the resolved name contains
  // what the user typed. If not, retry as a Bayer designation (leading
  // comma). If that also mismatches, return null.
  final termLower = term.toLowerCase();
  final bayerTerm = term.startsWith(',') ? term.substring(1) : term;
  bool nameMatches(String resolved) {
    final lower = resolved.toLowerCase();
    return lower.contains(termLower) || lower.contains(bayerTerm.toLowerCase());
  }

  if (!nameMatches(r.starName)) {
    if (!term.startsWith(',')) {
      try {
        r = eph.fixstar2Ut(',$term', jdUt, flags);
      } on SweException {
        return null;
      }
    }
    if (!nameMatches(r.starName)) {
      return null;
    }
  }

  final searchForMag = r.starName.split(',').first.trim();
  double magnitude;
  try {
    magnitude = getMagnitude(searchForMag);
  } catch (_) {
    magnitude = double.nan;
  }

  return StarResult(
    searchTerm: term,
    resolvedName: r.starName,
    longitude: r.longitude,
    latitude: r.latitude,
    distance: r.distance,
    speedLon: r.longitudeSpeed,
    speedLat: r.latitudeSpeed,
    speedDist: r.distanceSpeed,
    magnitude: magnitude,
    returnFlag: r.returnFlag,
  );
}

final _starCalcProvider =
    Provider<({CalcOutcome<StarResult?> outcome, CallTrace trace})>((ref) {
      final ctx = ref.watch(contextBarProvider);
      final flags = ref.watch(flagBarProvider);
      final swe = ref.read(sweProvider);
      final searchTerm = ref.watch(starSearchProvider);

      return runTabCalc(
        ref,
        tabTag: 'stars',
        compute: (eph) => computeStar(
          eph: eph,
          jdUt: ctx.jdUt,
          iflag: flags.iflag,
          searchTerm: searchTerm,
          getMagnitude: swe.fixstar2Mag,
        ),
      );
    });

final starResultProvider = Provider<CalcOutcome<StarResult?>>((ref) {
  return ref.watch(_starCalcProvider.select((c) => c.outcome));
});

final starTraceProvider = Provider<CallTrace>((ref) {
  return ref.watch(_starCalcProvider.select((c) => c.trace));
});

/// Convert a star result to export rows.
List<ExportRow> starToExportRows(StarResult result, DisplayFormat fmt) {
  return [
    ExportRow(
      header: result.resolvedName,
      fields: [
        ('Longitude', formatAngle(result.longitude, fmt)),
        ('Latitude', formatAngle(result.latitude, fmt)),
        ('Distance', formatDistance(result.distance, fmt)),
        (
          'Magnitude',
          result.magnitude.isNaN ? '—' : result.magnitude.toStringAsFixed(2),
        ),
        ('Spd Lon', formatSpeed(result.speedLon, fmt)),
        ('Spd Lat', formatSpeed(result.speedLat, fmt)),
        ('Spd Dist', formatSpeed(result.speedDist, fmt)),
      ],
    ),
  ];
}
