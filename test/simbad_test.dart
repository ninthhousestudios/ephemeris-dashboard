// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephe/simbad.dart';

const _star = SimbadStar(
  tradName: 'Aldebaran',
  nomenName: 'alfTau',
  hipId: 'HIP 21421',
  raHour: '04',
  raMinute: '35',
  raSec: '55.23907',
  decDegree: '+16',
  decMinute: '30',
  decSec: '33.4885',
  pmra: '63.45',
  pmde: '-188.94',
  radVel: '54.398',
  parallax: '48.94',
  magV: '0.86',
);

void main() {
  group('nomenToLongForm', () {
    test('Bayer designation', () {
      expect(nomenToLongForm('alfTau'), 'Alpha Tauri');
      expect(nomenToLongForm('betOri'), 'Beta Orionis');
      expect(nomenToLongForm('gamSgr'), 'Gamma Sagittarii');
      expect(nomenToLongForm('zetUMa'), 'Zeta Ursae Majoris');
    });

    test('Bayer with number', () {
      expect(nomenToLongForm('eps01Ori'), 'Epsilon Orionis 01');
    });

    test('Flamsteed designation', () {
      expect(nomenToLongForm('48Lib'), 'Librae48');
      expect(nomenToLongForm('61Cyg'), 'Cygni61');
    });

    test('HIP designation', () {
      expect(nomenToLongForm('HIP12345'), 'Hipparcos Catalogue 12345');
    });

    test('Messier object', () {
      expect(nomenToLongForm('M31'), 'Messier Object 31');
    });

    test('NGC catalogue', () {
      expect(nomenToLongForm('NGC1234'), 'New General Catalogue 1234');
    });

    test('leading comma stripped', () {
      expect(nomenToLongForm(',alfTau'), 'Alpha Tauri');
    });

    test('unknown passes through', () {
      expect(nomenToLongForm('Foobar'), 'Foobar');
    });

    test('mu. is not Messier', () {
      expect(nomenToLongForm('mu.Sgr'), 'Mu Sagittarii');
    });
  });

  group('validateEntry', () {
    test('good entry passes', () {
      const line = 'alfTau,alfTau,ICRS,4,35,55.2,16,30,33,62,-189,54,48,0.85\n';
      expect(validateEntry([line]), isTrue);
    });

    test('short entry fails', () {
      expect(validateEntry(['alfTau,alfTau,ICRS,4,35\n']), isFalse);
    });

    test('comments skip validation', () {
      expect(validateEntry(['# a comment\n']), isTrue);
    });
  });

  group('buildEntryLines', () {
    test('emits comment + nomen + long form + extra ids', () {
      final lines = buildEntryLines(_star);
      expect(lines.first, startsWith('#0# alfTau, Alpha Tauri'));
      expect(lines.first, contains('Aldebaran'));
      expect(lines.first, contains('HIP 21421'));
      // Every data line carries the same 14-field astrometry, differing only
      // in the first (search-key) field.
      expect(lines[1], startsWith('alfTau,alfTau,ICRS,'));
      expect(lines[2], startsWith('Alpha Tauri,alfTau,ICRS,'));
      expect(lines.any((l) => l.startsWith('Aldebaran,alfTau,ICRS,')), isTrue);
      expect(lines.any((l) => l.startsWith('HIP 21421,alfTau,ICRS,')), isTrue);
      expect(validateEntry(lines), isTrue);
    });

    test('custom names become their own search-key lines', () {
      final lines = buildEntryLines(_star, extraNames: ['My Star', '  ', 'x']);
      expect(lines.any((l) => l.startsWith('My Star,alfTau,ICRS,')), isTrue);
      expect(lines.any((l) => l.startsWith('x,alfTau,ICRS,')), isTrue);
      // Blank custom names are dropped.
      expect(lines.every((l) => !l.startsWith(',alfTau')), isTrue);
    });
  });

  group('parseSimbadResponse', () {
    // Real SIMBAD ASCII record for Messier 39, an open cluster whose primary
    // identifier is NGC 7092. Its Object line is a two-token main id, which the
    // original star-tuned `tokens[2] + tokens[3]` read as the bare, unexpandable
    // "7092"; the fix keeps the "NGC" catalogue prefix.
    const m39 =
        'C.D.S.  -  SIMBAD4 rel 1.8  -  2026.08.21CEST18:02:47\n'
        '\n'
        'Messier 39\n'
        '----------\n'
        '\n'
        'Object NGC 7092  ---  OpC  ---  OID=@70721   (@@9441,3)  ---  coobox=158\n'
        '\n'
        'Coordinates(ICRS,ep=J2000,eq=2000): 21 31 33.4  +48 14 49 (Opt ) E [~ ~ ] 2021A&A...647A..19T\n'
        'Coordinates(FK4,ep=B1950,eq=1950): 21 29 44.9  +48 01 33\n'
        'Coordinates(Gal,ep=J2000,eq=2000): 092.2459  -02.3508\n'
        'hierarchy counts: #parents=0, #children=887, #siblings=0\n'
        'Proper motions: -7.3569 -19.5993 [0.0256 0.0260 90] B 2018A&A...616A..10G\n'
        'Parallax: 3.3373 [0.0024] B 2018A&A...616A..10G\n'
        'Radial Velocity: -5.20 [0.2] A 2021A&A...647A..19T\n';

    // Real Aldebaran record — the star path must be unchanged: its Object line
    // `* alf Tau` has a leading '*' star-type marker that is dropped, leaving
    // the Bayer designation "alfTau".
    const aldebaran =
        'C.D.S.  -  SIMBAD4 rel 1.8  -  2026.08.21CEST18:07:43\n'
        '\n'
        'Aldebaran\n'
        '---------\n'
        '\n'
        'Object * alf Tau  ---  LP?  ---  OID=@719377   (@@19667,0)  ---  coobox=4875\n'
        '\n'
        'Coordinates(ICRS,ep=J2000,eq=2000): 04 35 55.23907  +16 30 33.4885 (Opt ) A [7.38 5.70 90] 2007A&A...474..653V\n'
        'Coordinates(FK4,ep=B1950,eq=1950): 04 33 02.89523  +16 24 37.5805\n'
        'Coordinates(Gal,ep=J2000,eq=2000): 180.97191142  -20.24829666\n'
        'hierarchy counts: #parents=0, #children=1, #siblings=0\n'
        'Proper motions: 63.45 -188.94 [0.84 0.65 0] A 2007A&A...474..653V\n'
        'Parallax: 48.94 [0.77] A 2007A&A...474..653V\n'
        'Radial Velocity: 54.398 [0.0008] A 2018A&A...616A...7S\n'
        'Redshift: 0.000181 [0.000000] A 2018A&A...616A...7S\n'
        'cz: 54.40 [0.00] A 2018A&A...616A...7S\n'
        'Flux U : 4.32 [~] C 2002yCat.2237....0D\n'
        'Flux B : 2.40 [~] C 2002yCat.2237....0D\n'
        'Flux V : 0.86 [~] C 2002yCat.2237....0D\n';

    test('bright star drops the star-type marker, keeping the Bayer key', () {
      final star = parseSimbadResponse(aldebaran);
      expect(star, isNotNull);
      expect(star!.nomenName, 'alfTau');
      expect(star.tradName, 'Aldebaran');
      expect(star.magV, '0.86');
      expect(star.raHour, '04');
      expect(star.pmde, '-188.94');
    });

    test('deep-sky object keeps its catalogue prefix as nomen', () {
      final star = parseSimbadResponse(m39);
      expect(star, isNotNull);
      expect(star!.nomenName, 'NGC7092');
      expect(star.tradName, 'Messier 39');
      // The astrometry is parsed off the same record.
      expect(star.raHour, '21');
      expect(star.decDegree, '+48');
      expect(star.pmra, '-7.3569');
      expect(star.parallax, '3.3373');
      expect(star.radVel, '-5.20');
    });

    test('nomen expands to a real long form and search keys', () {
      final lines = buildEntryLines(parseSimbadResponse(m39)!);
      expect(
        lines.first,
        startsWith('#0# NGC7092, New General Catalogue 7092'),
      );
      expect(lines.any((l) => l.startsWith('NGC7092,NGC7092,ICRS,')), isTrue);
      expect(
        lines.any(
          (l) => l.startsWith('New General Catalogue 7092,NGC7092,ICRS,'),
        ),
        isTrue,
      );
      expect(
        lines.any((l) => l.startsWith('Messier 39,NGC7092,ICRS,')),
        isTrue,
      );
    });
  });

  group('dedupEntries', () {
    test('drops data lines whose key already exists', () {
      const existing =
          'Aldebaran,alfTau,ICRS,04,35,55,16,30,33,63,-189,54,48,0.86\n';
      final lines = buildEntryLines(_star);
      final result = dedupEntries(existing, lines);
      expect(result.skipped, contains('Aldebaran'));
      expect(result.added, contains('alfTau'));
      expect(result.added, isNot(contains('Aldebaran')));
      // The comment header survives because some data lines were kept.
      expect(result.append.first, startsWith('#'));
    });

    test('all-duplicate build yields empty append (no orphan comment)', () {
      final lines = buildEntryLines(_star);
      // Seed existing with every data line's key.
      final existing = lines.where((l) => !l.startsWith('#')).join();
      final result = dedupEntries(existing, lines);
      expect(result.added, isEmpty);
      expect(result.append, isEmpty);
    });
  });

  test('simbadUrl encodes spaces and requests ASCII', () {
    final url = simbadUrl('62 Sagittarii');
    expect(url, contains('Ident=62+Sagittarii'));
    expect(url, contains('output.format=ASCII'));
  });

  group('simbadErrorLine', () {
    test('extracts the message from a SIMBAD not-found body', () {
      const body =
          "!! 'Reglus': No known catalog could be found\n query string: Reglus";
      expect(
        simbadErrorLine(body),
        "'Reglus': No known catalog could be found",
      );
    });

    test('returns null for a normal record', () {
      const body = 'C.D.S. - SIMBAD4\nObject alf Tau ---\n';
      expect(simbadErrorLine(body), isNull);
    });
  });

  group('levenshtein', () {
    test('single edits', () {
      expect(levenshtein('Reglus', 'Regulus'), 1); // one insertion
      expect(levenshtein('kitten', 'sitting'), 3);
      expect(levenshtein('Vega', 'Vega'), 0);
    });

    test('case-insensitive', () {
      expect(levenshtein('SPICA', 'spica'), 0);
    });
  });

  group('closestNames', () {
    const catalog = ['Regulus', 'Rigel', 'Aldebaran', 'Antares', 'Betelgeuse'];

    test('suggests the near miss, nearest first', () {
      expect(closestNames('Reglus', catalog), contains('Regulus'));
    });

    test('drops far-off and exact matches', () {
      // Exact match yields no suggestion (distance 0 excluded).
      expect(closestNames('Regulus', catalog), isNot(contains('Regulus')));
      // Nothing within 2 edits of a wildly different query.
      expect(closestNames('Zxqwv', catalog), isEmpty);
    });

    test('ignores queries shorter than 3 chars', () {
      expect(closestNames('Ri', catalog), isEmpty);
    });
  });
}
