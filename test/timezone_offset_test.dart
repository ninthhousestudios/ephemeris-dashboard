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
