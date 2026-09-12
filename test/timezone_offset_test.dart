// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// The zone→offset resolver, honestly (swe-dashboard/112).
///
/// A derived offset is only as good as tzdata, so the resolver's job is not
/// just the number but the confidence: these pin the standard/DST/`:45` cases
/// it must get right, and the pre-1970 / LMT / DST-gap / DST-fold cases it must
/// flag rather than present as fact. Pure — no widget, no engine.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/jd_utils.dart' show Civil;
import 'package:swe_dashboard/core/timezone_offset.dart';

Civil _c(int y, int mo, int d, [int h = 0, int mi = 0, int s = 0]) =>
    (year: y, month: mo, day: d, hour: h, minute: mi, second: s);

void main() {
  setUpAll(ensureTimeZonesInitialized);

  group('resolveTzOffsetForLocal — high confidence', () {
    test('standard time (EST)', () {
      final r = resolveTzOffsetForLocal(
        'America/New_York',
        _c(1985, 1, 15, 12),
      );
      expect(r.resolved, isTrue);
      expect(r.offsetHours, -5.0);
      expect(r.abbreviation, 'EST');
      expect(r.warnings, isEmpty);
      expect(r.lowConfidence, isFalse);
    });

    test('daylight time (EDT)', () {
      final r = resolveTzOffsetForLocal(
        'America/New_York',
        _c(1985, 7, 15, 12),
      );
      expect(r.offsetHours, -4.0);
      expect(r.abbreviation, 'EDT');
      expect(r.warnings, isEmpty);
    });

    test('a :45 zone (Asia/Kathmandu, +5:45)', () {
      final r = resolveTzOffsetForLocal('Asia/Kathmandu', _c(2000, 6, 15, 12));
      expect(r.offsetHours, 5.75);
      expect(r.warnings, isEmpty);
    });
  });

  group('resolveTzOffsetForLocal — low confidence', () {
    test('pre-1970 date is flagged even when the offset is a clean value', () {
      final r = resolveTzOffsetForLocal(
        'America/New_York',
        _c(1965, 7, 15, 12),
      );
      // 1965 is EDT (-4), a perfectly clean offset — but tzdata is not
      // authoritative before 1970, so it must still be flagged.
      expect(r.offsetHours, -4.0);
      expect(r.warnings, contains(TzWarning.preModern));
      expect(r.lowConfidence, isTrue);
    });

    test('Local Mean Time (before standard time) is flagged', () {
      final r = resolveTzOffsetForLocal('Europe/Paris', _c(1850, 6, 15, 12));
      expect(r.resolved, isTrue);
      // Named mean time in this era ('LMT' or 'PMT' depending on tzdata) — the
      // point is it is flagged as mean time, not the exact abbreviation.
      expect(r.warnings, containsAll([TzWarning.lmt, TzWarning.preModern]));
      // Paris Mean Time is a longitude-derived fractional offset (+0:09:21),
      // not a legal whole/half-hour zone.
      expect(r.offsetHours, closeTo(0.156, 0.02));
    });

    test('a DST spring-forward gap (this local time never occurred)', () {
      // 2021-03-14 02:00 → 03:00 in New York: 02:30 does not exist.
      final r = resolveTzOffsetForLocal(
        'America/New_York',
        _c(2021, 3, 14, 2, 30),
      );
      expect(r.warnings, contains(TzWarning.gap));
      expect(r.lowConfidence, isTrue);
    });

    test('a DST fall-back fold (this local time occurred twice)', () {
      // 2021-11-07 02:00 → 01:00 in New York: 01:30 happens twice.
      final r = resolveTzOffsetForLocal(
        'America/New_York',
        _c(2021, 11, 7, 1, 30),
      );
      expect(r.warnings, contains(TzWarning.ambiguous));
      expect(r.lowConfidence, isTrue);
    });

    test('an unknown zone resolves to unresolved, not a wrong number', () {
      final r = resolveTzOffsetForLocal('Not/AZone', _c(2000, 1, 1, 12));
      expect(r.resolved, isFalse);
      expect(r.lowConfidence, isTrue);
    });
  });

  group('resolveTzOffsetForLocal — folds/gaps east of UTC+12', () {
    // The sampling window must exceed the offset, or a fold's earlier occurrence
    // (one whole offset before the naive wall time) is never sampled and the
    // fold reads as unambiguous (swe-dashboard/113 TZ-003).
    test('Auckland fall-back fold is ambiguous (+13 NZDT / +12 NZST)', () {
      // 2021-04-04: 02:59:59 NZDT → 02:00:00 NZST, so 02:30 happens twice.
      final r = resolveTzOffsetForLocal(
        'Pacific/Auckland',
        _c(2021, 4, 4, 2, 30),
      );
      expect(r.warnings, contains(TzWarning.ambiguous));
      expect(
        r.offsetHours,
        13.0,
        reason: 'earlier occurrence (NZDT) is chosen',
      );
    });

    test('Chatham fall-back fold is ambiguous (+13:45 / +12:45)', () {
      // 2021-04-04: 03:44:59 +1345 → 02:45:00 +1245, so 03:00 happens twice.
      final r = resolveTzOffsetForLocal('Pacific/Chatham', _c(2021, 4, 4, 3));
      expect(r.warnings, contains(TzWarning.ambiguous));
      expect(r.offsetHours, 13.75, reason: 'earlier occurrence is chosen');
    });

    test('Auckland spring-forward gap is flagged', () {
      // 2021-09-26: 01:59:59 NZST → 03:00:00 NZDT, so 02:30 never occurred.
      final r = resolveTzOffsetForLocal(
        'Pacific/Auckland',
        _c(2021, 9, 26, 2, 30),
      );
      expect(r.warnings, contains(TzWarning.gap));
      expect(r.lowConfidence, isTrue);
    });
  });

  group('resolveTzOffsetForInstant — UTC→local is unambiguous', () {
    test('picks the offset in effect at the instant, no gap/fold', () {
      // 1985-07-15 16:00 UTC is inside EDT for New York.
      final r = resolveTzOffsetForInstant(
        'America/New_York',
        _c(1985, 7, 15, 16),
      );
      expect(r.offsetHours, -4.0);
      expect(r.abbreviation, 'EDT');
      expect(r.warnings, isEmpty, reason: 'UTC→local cannot gap or fold');
    });

    test('flags pre-1970 instants', () {
      final r = resolveTzOffsetForInstant(
        'America/New_York',
        _c(1960, 1, 15, 17),
      );
      expect(r.warnings, contains(TzWarning.preModern));
    });

    test('an unknown zone is unresolved', () {
      final r = resolveTzOffsetForInstant('Not/AZone', _c(2000, 1, 1, 12));
      expect(r.resolved, isFalse);
    });
  });
}
