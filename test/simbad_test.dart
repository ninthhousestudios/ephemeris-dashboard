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
