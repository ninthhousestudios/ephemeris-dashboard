// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;
import 'package:swe_dashboard/core/date_time_input.dart';
import 'package:swe_dashboard/core/jd_utils.dart';
import 'package:swe_dashboard/core/swe_utils.dart';

void main() {
  group('fmtDate', () {
    test('zero-pads year, month, day', () {
      expect(fmtDate(DateTime.utc(2024, 1, 5)), equals('2024-01-05'));
    });

    test('handles four-digit year', () {
      expect(fmtDate(DateTime.utc(2024, 12, 31)), equals('2024-12-31'));
    });

    test('handles negative years (BCE)', () {
      expect(fmtDate(DateTime.utc(-500, 3, 21)), equals('-0500-03-21'));
    });

    test('zero-pads small-magnitude negative years', () {
      expect(fmtDate(DateTime.utc(-50, 3, 21)), equals('-0050-03-21'));
      expect(fmtDate(DateTime.utc(-5, 3, 21)), equals('-0005-03-21'));
    });
  });

  group('fmtTime', () {
    test('zero-pads hours, minutes, seconds', () {
      expect(fmtTime(DateTime.utc(2024, 1, 1, 3, 5, 9)), equals('03:05:09'));
    });

    test('handles midnight', () {
      expect(fmtTime(DateTime.utc(2024, 1, 1, 0, 0, 0)), equals('00:00:00'));
    });

    test('handles 23:59:59', () {
      expect(fmtTime(DateTime.utc(2024, 1, 1, 23, 59, 59)), equals('23:59:59'));
    });
  });

  group('fmtHms', () {
    test('matches fmtTime for same values', () {
      final dt = DateTime.utc(2024, 1, 1, 14, 30, 45);
      expect(fmtHms(dt.hour, dt.minute, dt.second), equals(fmtTime(dt)));
    });

    test('zero-pads single digits', () {
      expect(fmtHms(1, 2, 3), equals('01:02:03'));
    });
  });

  group('parseDateFields', () {
    test('parses valid YYYY-MM-DD', () {
      final r = parseDateFields('2024-06-15');
      expect(r, isNotNull);
      expect(r!.year, equals(2024));
      expect(r.month, equals(6));
      expect(r.day, equals(15));
    });

    test('returns null on too few parts', () {
      expect(parseDateFields('2024-06'), isNull);
    });

    test('returns null on non-numeric', () {
      expect(parseDateFields('abc-06-15'), isNull);
    });

    test('returns null on empty string', () {
      expect(parseDateFields(''), isNull);
    });

    test('rejects impossible day for month (Feb 31)', () {
      expect(parseDateFields('2024-02-31'), isNull);
    });

    test('rejects month 0 and month 13', () {
      expect(parseDateFields('2024-00-15'), isNull);
      expect(parseDateFields('2024-13-15'), isNull);
    });

    test('rejects day 0', () {
      expect(parseDateFields('2024-06-00'), isNull);
    });

    test('accepts Feb 29 on leap year, rejects on non-leap', () {
      expect(parseDateFields('2024-02-29'), isNotNull);
      expect(parseDateFields('2023-02-29'), isNull);
    });

    test('parses negative year', () {
      final r = parseDateFields('-500-03-21');
      expect(r, isNotNull);
      expect(r!.year, equals(-500));
    });

    test('round-trips small-magnitude negative years through fmtDate', () {
      for (final year in [-1, -5, -50, -500, -5000]) {
        final dt = DateTime.utc(year, 3, 21);
        final r = parseDateFields(fmtDate(dt));
        expect(r, isNotNull, reason: 'year $year');
        expect(r!.year, equals(year), reason: 'year $year');
      }
    });
  });

  group('parseTimeFields', () {
    test('parses HH:MM:SS', () {
      final r = parseTimeFields('14:30:45');
      expect(r, isNotNull);
      expect(r!.hour, equals(14));
      expect(r.minute, equals(30));
      expect(r.second, equals(45));
    });

    test('parses HH:MM with seconds defaulting to 0', () {
      final r = parseTimeFields('14:30');
      expect(r, isNotNull);
      expect(r!.second, equals(0));
    });

    test('returns null on empty', () {
      expect(parseTimeFields(''), isNull);
    });

    test('returns null on non-numeric hour', () {
      expect(parseTimeFields('ab:30:00'), isNull);
    });

    test('rejects hour 24', () {
      expect(parseTimeFields('24:00:00'), isNull);
    });

    test('rejects minute 60', () {
      expect(parseTimeFields('12:60:00'), isNull);
    });

    test('rejects second 60', () {
      expect(parseTimeFields('12:30:60'), isNull);
    });

    test('rejects negative values', () {
      expect(parseTimeFields('-1:30:00'), isNull);
    });
  });

  group('civil↔JD round-trip', () {
    JdUtils? jdUtils;

    setUp(() {
      try {
        jdUtils = JdUtils(SweUtils(rs.Ephemeris(rs.EphemerisConfig())));
      } catch (_) {
        // Native library not available on this platform
      }
    });

    test('modern date round-trips through JD', () {
      if (jdUtils == null) return markTestSkipped('SwissEph unavailable');
      final dt = DateTime.utc(2024, 6, 15, 14, 30, 45);
      final jd = jdUtils!.dateTimeToJd(dt);
      final rt = jdUtils!.jdToDateTime(jd);
      expect(fmtDate(rt), equals(fmtDate(dt)));
      expect(fmtTime(rt), equals(fmtTime(dt)));
    });

    test('Gregorian/Julian boundary: Oct 15 1582 (first Gregorian day)', () {
      if (jdUtils == null) return markTestSkipped('SwissEph unavailable');
      final dt = DateTime.utc(1582, 10, 15, 12, 0, 0);
      final jd = jdUtils!.dateTimeToJd(dt);
      final rt = jdUtils!.jdToDateTime(jd);
      expect(fmtDate(rt), equals('1582-10-15'));
      expect(fmtTime(rt), equals('12:00:00'));
    });

    test('Julian calendar: Oct 4 1582 (last Julian day)', () {
      if (jdUtils == null) return markTestSkipped('SwissEph unavailable');
      final dt = DateTime.utc(1582, 10, 4, 12, 0, 0);
      final jd = jdUtils!.dateTimeToJd(dt);
      final rt = jdUtils!.jdToDateTime(jd);
      expect(fmtDate(rt), equals('1582-10-04'));
    });

    test('BCE date round-trip', () {
      if (jdUtils == null) return markTestSkipped('SwissEph unavailable');
      final jd = jdUtils!.dateTimeToJd(DateTime.utc(-500, 3, 21, 6, 0, 0));
      final rt = jdUtils!.jdToDateTime(jd);
      expect(rt.year, equals(-500));
      expect(rt.month, equals(3));
      expect(rt.day, equals(21));
    });

    test('midnight round-trip', () {
      if (jdUtils == null) return markTestSkipped('SwissEph unavailable');
      final dt = DateTime.utc(2024, 1, 1, 0, 0, 0);
      final jd = jdUtils!.dateTimeToJd(dt);
      final rt = jdUtils!.jdToDateTime(jd);
      expect(fmtTime(rt), equals('00:00:00'));
    });

    test('parse→JD→format round-trip', () {
      if (jdUtils == null) return markTestSkipped('SwissEph unavailable');
      final d = parseDateFields('2024-06-15')!;
      final t = parseTimeFields('14:30:45')!;
      final jd = jdUtils!.dateTimeToJd(
        DateTime.utc(d.year, d.month, d.day, t.hour, t.minute, t.second),
      );
      final rt = jdUtils!.jdToDateTime(jd);
      expect(fmtDate(rt), equals('2024-06-15'));
      expect(fmtTime(rt), equals('14:30:45'));
    });
  });
}
