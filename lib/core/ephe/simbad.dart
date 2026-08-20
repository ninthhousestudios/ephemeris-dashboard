// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert' show LineSplitter;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dart port of swisseph-rs' `make-swe-stars` binary: query SIMBAD for a fixed
/// star, parse its ASCII record, and generate `sefstars.txt` catalog lines.
///
/// The catalog format is `search_key,nomenclature,ICRS,<astrometry…>,mag`. One
/// star yields several lines that share the astrometry but differ in the first
/// field (the search key): the nomenclature designation, the long form, the
/// traditional name, the HIP id, and any user-supplied custom names. Every
/// first field is independently searchable in the app's star search fields.

const _simbadBase = 'https://simbad.cds.unistra.fr/simbad/sim-id';

/// Number of comma-separated fields a valid catalog data line must have.
const expectedFieldCount = 14;

/// A parsed SIMBAD record — the raw string fields that feed a catalog entry.
class SimbadStar {
  const SimbadStar({
    required this.tradName,
    required this.nomenName,
    required this.hipId,
    required this.raHour,
    required this.raMinute,
    required this.raSec,
    required this.decDegree,
    required this.decMinute,
    required this.decSec,
    required this.pmra,
    required this.pmde,
    required this.radVel,
    required this.parallax,
    required this.magV,
  });

  final String tradName;
  final String nomenName;
  final String hipId;
  final String raHour;
  final String raMinute;
  final String raSec;
  final String decDegree;
  final String decMinute;
  final String decSec;
  final String pmra;
  final String pmde;
  final String radVel;
  final String parallax;
  final String magV;
}

/// Thrown when a SIMBAD query fails or its response cannot be parsed.
class SimbadException implements Exception {
  const SimbadException(this.message);
  final String message;
  @override
  String toString() => 'SimbadException: $message';
}

String simbadUrl(String name) {
  final encoded = name.replaceAll(' ', '+');
  return '$_simbadBase?Ident=$encoded&NbIdent=1&Radius=2&Radius.unit=arcmin'
      '&submit=submit%20id&output.format=ASCII';
}

/// Query SIMBAD for [name] and parse the ASCII record into a [SimbadStar].
Future<SimbadStar> querySimbad(String name, Dio dio) async {
  final Response<String> resp;
  try {
    resp = await dio.get<String>(
      simbadUrl(name),
      options: Options(responseType: ResponseType.plain),
    );
  } on DioException catch (e) {
    throw SimbadException('Network error: ${e.message ?? e}');
  }
  final star = parseSimbadResponse(resp.data ?? '');
  if (star == null) {
    throw SimbadException("Could not parse SIMBAD response for '$name'");
  }
  return star;
}

/// Parse a SIMBAD ASCII (`output.format=ASCII`) record. Returns null when the
/// astrometric fields required for a catalog entry are absent (e.g. a
/// not-found response or an object without full ICRS coordinates + proper
/// motion + parallax). Faithful port of `parse_simbad_response`.
SimbadStar? parseSimbadResponse(String text) {
  final lines = const LineSplitter().convert(text);

  String? magV;
  var hipId = 'no hip id';
  var tradName = '';
  var nomenName = 'noMen';
  String? raHour, raMinute, raSec;
  String? decDegree, decMinute, decSec;
  String? pmra, pmde, parallax, radVel;

  for (var n = 0; n < lines.length; n++) {
    final line = lines[n];
    if (n > 28) {
      final end = lines.length < 50 ? lines.length : 50;
      for (var i = 28; i < end; i++) {
        final tail = lines[i];
        if (tail.contains('HIP')) {
          final parts = _whitespaceTokens(tail);
          for (var k = 0; k < parts.length; k++) {
            if (parts[k] == 'HIP' && k + 1 < parts.length) {
              hipId = 'HIP ${parts[k + 1]}';
            }
          }
        }
        if (tail.contains('NAME')) {
          final parts = _whitespaceTokens(tail);
          for (var k = 0; k < parts.length; k++) {
            if (parts[k] == 'NAME' && k + 1 < parts.length) {
              tradName = parts[k + 1];
            }
          }
        }
      }
      break;
    }
    switch (n) {
      case 2:
        tradName = line;
      case 5:
        final tokens = line.split(' ');
        if (tokens.length > 3) nomenName = '${tokens[2]}${tokens[3]}';
      case 7:
        final icrs = line.split(' ');
        if (icrs.length > 7) {
          raHour = icrs[1];
          raMinute = icrs[2];
          raSec = icrs[3];
          decDegree = icrs[5];
          decMinute = icrs[6];
          decSec = icrs[7];
        }
      case 11:
        final pm = line.split(' ');
        if (pm.length > 3) {
          pmra = pm[2];
          pmde = pm[3];
        }
      case 12:
        final para = line.split(' ');
        if (para.length > 1) parallax = para[1];
      case 13:
        final rv = line.split(' ');
        if (rv.length > 2) radVel = rv[2];
    }
    if (line.contains('Flux V')) {
      final flux = line.split(' ');
      if (flux.length > 3) magV = flux[3];
    }
  }

  if (raHour == null ||
      raMinute == null ||
      raSec == null ||
      decDegree == null ||
      decMinute == null ||
      decSec == null ||
      pmra == null ||
      pmde == null ||
      radVel == null ||
      parallax == null) {
    return null;
  }

  return SimbadStar(
    tradName: tradName,
    nomenName: nomenName,
    hipId: hipId,
    raHour: raHour,
    raMinute: raMinute,
    raSec: raSec,
    decDegree: decDegree,
    decMinute: decMinute,
    decSec: decSec,
    pmra: pmra,
    pmde: pmde,
    radVel: radVel,
    parallax: parallax,
    magV: magV ?? '0',
  );
}

List<String> _whitespaceTokens(String s) {
  final trimmed = s.trim();
  if (trimmed.isEmpty) return const [];
  return trimmed.split(RegExp(r'\s+'));
}

/// Build the `sefstars.txt` lines for [star]. The first line is a `#0#` comment
/// header; the rest are catalog data lines, one per search key. [extraNames]
/// are user-supplied names to also register as search keys. Every line ends in
/// a newline. Faithful port of `build_entry_lines`, plus the [extraNames] hook.
List<String> buildEntryLines(
  SimbadStar star, {
  List<String> extraNames = const [],
}) {
  final nomen = star.nomenName;
  final longForm = nomenToLongForm(nomen);
  final dataFields =
      '$nomen,ICRS,${star.raHour},${star.raMinute},${star.raSec},'
      '${star.decDegree},${star.decMinute},${star.decSec},'
      '${star.pmra},${star.pmde},${star.radVel},${star.parallax},${star.magV}';

  final extraIds = <String>[
    for (final id in [star.tradName, star.hipId])
      if (id.isNotEmpty && id != 'no hip id') id,
  ];

  final comment = StringBuffer('#0# $nomen, $longForm');
  for (final id in extraIds) {
    comment.write(', $id');
  }
  comment.write('\n');

  final lines = <String>[
    comment.toString(),
    '$nomen,$dataFields\n',
    '$longForm,$dataFields\n',
    for (final id in extraIds) '$id,$dataFields\n',
    for (final name in extraNames)
      if (name.trim().isNotEmpty) '${name.trim()},$dataFields\n',
  ];
  return lines;
}

/// True when every non-comment line in [lines] has at least
/// [expectedFieldCount] comma-separated fields. Port of `validate_entry`.
bool validateEntry(List<String> lines) {
  for (final line in lines) {
    if (line.startsWith('#')) continue;
    if (line.trim().split(',').length < expectedFieldCount) return false;
  }
  return true;
}

/// Result of reconciling freshly-built entry lines against existing catalog
/// contents: [append] is what to write (comment header + kept data lines, or
/// empty when every key already exists), [added]/[skipped] are the first-field
/// search keys accepted and rejected as duplicates.
typedef DedupResult = ({
  List<String> append,
  List<String> added,
  List<String> skipped,
});

/// Drop any data line in [entryLines] whose search key (first field) already
/// appears in [existingContents]. The comment header is only emitted when at
/// least one data line survives.
DedupResult dedupEntries(String existingContents, List<String> entryLines) {
  final existing = <String>{};
  for (final line in const LineSplitter().convert(existingContents)) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final first = line.split(',').first.trim();
    if (first.isNotEmpty) existing.add(first);
  }

  final comments = <String>[];
  final keptData = <String>[];
  final added = <String>[];
  final skipped = <String>[];
  for (final line in entryLines) {
    if (line.startsWith('#')) {
      comments.add(line);
      continue;
    }
    final first = line.split(',').first.trim();
    if (existing.contains(first)) {
      skipped.add(first);
    } else {
      existing.add(first);
      keptData.add(line);
      added.add(first);
    }
  }

  return (
    append: keptData.isEmpty ? const <String>[] : [...comments, ...keptData],
    added: added,
    skipped: skipped,
  );
}

/// Provider for the SIMBAD HTTP client. Separate from the ephemeris downloader
/// so the two don't share timeouts (SIMBAD is a small text fetch).
final simbadDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

String? greekToLong(String abbr) => switch (abbr) {
  'alf' => 'Alpha',
  'bet' => 'Beta',
  'gam' || 'g' => 'Gamma',
  'del' || 'd' => 'Delta',
  'eps' => 'Epsilon',
  'zet' => 'Zeta',
  'eta' => 'Eta',
  'tet' => 'Theta',
  'iot' => 'Iota',
  'kap' => 'Kappa',
  'lam' => 'Lambda',
  'mu.' => 'Mu',
  'nu.' => 'Nu',
  'ksi' => 'Xi',
  'omi' => 'Omicron',
  'pi.' => 'Pi',
  'rho' => 'Rho',
  'sig' => 'Sigma',
  'tau' => 'Tau',
  'ups' => 'Upsilon',
  'phi' => 'Phi',
  'chi' => 'Chi',
  'psi' => 'Psi',
  'ome' => 'Omega',
  _ => null,
};

String? constellationToLong(String abbr) => switch (abbr) {
  'Ari' => 'Arietis',
  'Tau' => 'Tauri',
  'Gem' => 'Geminorum',
  'Cnc' => 'Cancri',
  'Leo' => 'Leonis',
  'Vir' => 'Virginis',
  'Lib' => 'Librae',
  'Sco' => 'Scorpii',
  'Oph' => 'Ophiuci',
  'Sgr' => 'Sagittarii',
  'Cap' => 'Capricorni',
  'Aqr' => 'Aquarii',
  'And' => 'Andromedae',
  'Ant' => 'Antliae',
  'Aps' => 'Apodis',
  'Ara' => 'Arae',
  'Psc' => 'Piscium',
  'Eri' => 'Eridani',
  'Cae' => 'Caeli',
  'Cam' => 'Camelopardalis',
  'Cas' => 'Cassiopeiae',
  'Cen' => 'Centauri',
  'Cep' => 'Cephei',
  'UMa' => 'Ursae Majoris',
  'UMi' => 'Ursae Minoris',
  'Aql' => 'Aquilae',
  'Hyd' => 'Hydrae',
  'Sct' => 'Scuti',
  'Sex' => 'Sextantis',
  'Sge' => 'Sagittae',
  'Boo' => 'Bootis',
  'Dra' => 'Draconis',
  'Del' => 'Delphini',
  'Dor' => 'Doradus',
  'Equ' => 'Equulei',
  'For' => 'Fornacis',
  'Cyg' => 'Cygni',
  'Gru' => 'Gruis',
  'Ori' => 'Orionis',
  'Cet' => 'Ceti',
  'Cha' => 'Chamaeleontis',
  'Cir' => 'Circini',
  'Col' => 'Columbae',
  'Com' => 'Comae Berenices',
  'CrB' => 'Coronae Borealis',
  'CrA' => 'Coronae Australis',
  'TCrB' => 'TCoronae Borealis',
  'Crt' => 'Crateris',
  'Cru' => 'Crucis',
  'Crv' => 'Corvi',
  'CVn' => 'Canum Venaticorum',
  'CMa' => 'Canis Majoris',
  'CMi' => 'Canis Minoris',
  'Aur' => 'Aurigae',
  'Car' => 'Carinae',
  'Lyr' => 'Lyrae',
  'Lep' => 'Leporis',
  'Men' => 'Mensae',
  'Mic' => 'Microscopii',
  'Mon' => 'Monocerotis',
  'Mus' => 'Muscae',
  'Nor' => 'Normae',
  'Oct' => 'Octantis',
  'Ind' => 'Indi',
  'Pav' => 'Pavonis',
  'Peg' => 'Pegasi',
  'Phe' => 'Phoenicis',
  'LMi' => 'Leonis Minoris',
  'Lup' => 'Lupi',
  'Lyn' => 'Lyncis',
  'Ser' => 'Serpentis',
  'Tel' => 'Telescopii',
  'TrA' => 'Trianguli Australis',
  'Tri' => 'Trianguli',
  'Tuc' => 'Tucanae',
  'Her' => 'Herculis',
  'Hor' => 'Horologii',
  'Hya' => 'Hydrae',
  'Hyi' => 'Hydri',
  'Lac' => 'Lacertae',
  'Per' => 'Persei',
  'Pic' => 'Pictoris',
  'PsA' => 'Piscis Austrini',
  'Pup' => 'Puppis',
  'Pyx' => 'Pyxidis',
  'Ret' => 'Reticuli',
  'Scl' => 'Sculptoris',
  'Vel' => 'Velorum',
  'Vol' => 'Volantis',
  'Vul' => 'Vulpeculae',
  'VC' => 'Virgo Cluster',
  'M' => 'Messier Object',
  'NGC' => 'New General Catalogue',
  'HIP' => 'Hipparcos Catalogue',
  'HR' => 'Bright Star Catalogue',
  'HD' => 'Henry Draper Catalogue',
  _ => null,
};

/// Expand a compact nomenclature designation (Bayer/Flamsteed/HIP/Messier/NGC)
/// to its long human-readable form. Passes unknown forms through unchanged.
/// Port of `nomen_to_long_form`.
String nomenToLongForm(String rawNomen) {
  final nomen = rawNomen.startsWith(',') ? rawNomen.substring(1) : rawNomen;

  // Flamsteed: starts with digits, e.g. "48Lib".
  if (nomen.isNotEmpty && _isAsciiDigit(nomen.codeUnitAt(0))) {
    var split = nomen.length;
    for (var i = 0; i < nomen.length; i++) {
      if (!_isAsciiDigit(nomen.codeUnitAt(i))) {
        split = i;
        break;
      }
    }
    final number = nomen.substring(0, split);
    final constellation = nomen.substring(split);
    final long = constellationToLong(constellation);
    if (long != null) return '$long$number';
    return nomen;
  }

  // Special catalogue prefixes: NGC, HIP, HR, HD, VC.
  for (final prefix in const ['NGC', 'HIP', 'HR', 'HD', 'VC']) {
    if (nomen.startsWith(prefix)) {
      final long = constellationToLong(prefix);
      if (long != null) {
        final rest = nomen.substring(prefix.length).trim();
        return rest.isEmpty ? long : '$long $rest';
      }
    }
  }

  // Messier: starts with M but not "mu.".
  if (nomen.startsWith('M') && !nomen.startsWith('mu.')) {
    final long = constellationToLong('M');
    if (long != null) return '$long ${nomen.substring(1).trim()}';
  }

  // Bayer: 3-char greek + constellation, optionally with a numeric suffix on
  // the greek, e.g. "alfTau", "eps01Ori".
  if (nomen.length >= 4) {
    final greekAbbr = nomen.substring(0, 3);
    final remainder = nomen.substring(3);

    var numEnd = remainder.length;
    for (var i = 0; i < remainder.length; i++) {
      if (!_isAsciiDigit(remainder.codeUnitAt(i))) {
        numEnd = i;
        break;
      }
    }
    final number = remainder.substring(0, numEnd);
    final constellation = remainder.substring(numEnd);

    final lowerOrDot = greekAbbr
        .split('')
        .every(
          (c) => c == '.' || (c.toLowerCase() == c && c.toUpperCase() != c),
        );
    if (lowerOrDot) {
      final greekLong = greekToLong(greekAbbr);
      final constLong = constellationToLong(constellation);
      if (greekLong != null && constLong != null) {
        return number.isEmpty
            ? '$greekLong $constLong'
            : '$greekLong $constLong $number';
      }
    }
  }

  return nomen;
}

bool _isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
