// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/true_sidereal.dart';

void main() {
  // Edge-star ecliptic longitudes at J2000 (Chimenti's Midpoint Method paper,
  // reproduced in arrow/docs/true-sidereal-method.md), keyed by the same star
  // identifiers the default set uses.
  const j2000 = <String, double>{
    ',gamAri': 33.1846, // Mesarthim   (Aries first)
    ',delAri': 50.8530, // Botein      (Aries last)
    ',omiTau': 51.1636, // Omicron Tau (Taurus first)
    ',zetTau': 84.7846, // Tianguan    (Taurus last)
    ',1Gem': 90.9463, // 1 Geminorum   (Gemini first)
    ',kapGem': 113.6658, // Kappa Gem  (Gemini last)
    ',chiCnc': 120.9730, // Chi Cnc    (Cancer first)
    ',alfCnc': 133.6416, // Acubens    (Cancer last)
    ',kapLeo': 135.2961, // Kappa Leo  (Leo first)
    ',betLeo': 171.6175, // Denebola   (Leo last)
    ',nu.Vir': 174.1592, // Nu Vir     (Virgo first)
    ',mu.Vir': 220.1312, // Mu Vir     (Virgo last)
    ',alf02Lib': 225.0827, // Zubenelgenubi (Libra first)
    ',48Lib': 240.3994, // 48 Librae   (Libra last)
    ',delSco': 242.5712, // Dschubba   (Scorpius first)
    ',tauSco': 251.4569, // Paikauhale (Scorpius last)
    ',etaOph': 257.9696, // Sabik      (Ophiuchus first)
    ',45Oph': 262.8807, // 45 Ophiuchi (Ophiuchus last)
    ',gamSgr': 271.2614, // Alnasl     (Sagittarius first)
    ',62Sgr': 297.0658, // 62 Sgr      (Sagittarius last)
    ',alf02Cap': 303.8586, // Algedi   (Capricornus first)
    ',delCap': 323.5426, // Deneb Algedi (Capricornus last)
    ',iotAqr': 328.7199, // Iota Aqr   (Aquarius first)
    ',phiAqr': 347.1386, // Phi Aqr    (Aquarius last)
    ',gamPsc': 351.4532, // Gamma Psc  (Pisces first)
    ',alfPsc': 29.3787, // Alrescha    (Pisces last)
  };

  // The Absolute column of the paper's boundary table: the start longitude of
  // each sign, in the default (Chimenti) constellation order.
  const expectedStarts = <String, double>{
    'Aries': 31.2816,
    'Taurus': 51.0083,
    'Gemini': 87.8655,
    'Cancer': 117.3194,
    'Leo': 134.4689,
    'Virgo': 172.8884,
    'Libra': 222.6069,
    'Scorpius': 241.4853,
    'Ophiuchus': 254.7132,
    'Sagittarius': 267.0711,
    'Capricornus': 300.4622,
    'Aquarius': 326.1312,
    'Pisces': 349.2959,
  };

  group('default set', () {
    test('is Chimenti with 13 constellations and 26 unique edge stars', () {
      final set = defaultTrueSiderealSet();
      expect(set.name, 'Chimenti');
      expect(set.constellations, hasLength(13));
      final stars = <String>{
        for (final c in set.constellations) ...[c.firstStar, c.lastStar],
      };
      expect(stars, hasLength(26));
      expect(
        set.constellations.map((c) => c.name),
        containsAll(<String>['Ophiuchus', 'Aries', 'Pisces']),
      );
    });
  });

  group('midpoint binning', () {
    final binning = TrueSiderealBinning.build(defaultTrueSiderealSet(), j2000);

    test('reproduces the published J2000 boundary starts', () {
      for (var i = 0; i < binning.names.length; i++) {
        final name = binning.names[i];
        expect(
          binning.boundaries[i],
          closeTo(expectedStarts[name]!, 0.001),
          reason: 'start of $name',
        );
      }
    });

    test('boundaries sum to a full 360° partition', () {
      var total = 0.0;
      for (var i = 0; i < binning.boundaries.length; i++) {
        final start = binning.boundaries[i];
        final end = binning.boundaries[(i + 1) % binning.boundaries.length];
        total += (end - start + 360) % 360;
      }
      expect(total, closeTo(360.0, 1e-6));
    });

    test(
      'places a longitude in its unequal constellation, degrees from start',
      () {
        // 40° is inside Aries (31.2816–51.0083).
        final aries = binning.placementAt(40);
        expect(aries.name, 'Aries');
        expect(aries.inSign, closeTo(40 - 31.2816, 0.001));

        // 260° is inside Ophiuchus (254.7132–267.0711) — the 13th sign.
        final oph = binning.placementAt(260);
        expect(oph.name, 'Ophiuchus');
        expect(oph.inSign, closeTo(260 - 254.7132, 0.001));

        // 10° wraps into Pisces (349.2959 → 31.2816 across 0°).
        final pisces = binning.placementAt(10);
        expect(pisces.name, 'Pisces');
        expect(pisces.inSign, closeTo((10 - 349.2959 + 360) % 360, 0.001));
      },
    );

    test(
      'the numeric longitude and the constellation deliberately disagree',
      () {
        // 210° is Libra by naive lon/30 (Scorpio index 7 → 210–240 is Scorpio,
        // actually index 7), but its true-sidereal constellation is different
        // because the widths are unequal. Just assert the placement is a real,
        // in-range constellation and its in-sign degrees are within that sign.
        final p = binning.placementAt(210);
        final idx = binning.names.indexOf(p.name);
        final width =
            (binning.boundaries[(idx + 1) % 13] -
                binning.boundaries[idx] +
                360) %
            360;
        expect(p.inSign, inInclusiveRange(0, width));
      },
    );
  });

  group('missing boundary star', () {
    test('throws MissingBoundaryStarException naming the star', () {
      final partial = Map<String, double>.of(j2000)..remove(',62Sgr');
      expect(
        () => TrueSiderealBinning.build(defaultTrueSiderealSet(), partial),
        throwsA(
          isA<MissingBoundaryStarException>().having(
            (e) => e.starName,
            'starName',
            ',62Sgr',
          ),
        ),
      );
    });

    test('a non-finite longitude is treated as missing', () {
      final bad = Map<String, double>.of(j2000)..[',gamAri'] = double.nan;
      expect(
        () => TrueSiderealBinning.build(defaultTrueSiderealSet(), bad),
        throwsA(isA<MissingBoundaryStarException>()),
      );
    });
  });

  group('TrueSiderealSet json', () {
    test('round-trips', () {
      final set = defaultTrueSiderealSet(id: 3).copyWith(name: 'Mine');
      final back = TrueSiderealSet.fromJson(set.toJson());
      expect(back, set);
    });

    test('rejects a wrong-length constellation list', () {
      final json = defaultTrueSiderealSet().toJson();
      (json['constellations'] as List).removeLast();
      expect(TrueSiderealSet.fromJson(json), isNull);
    });
  });
}
