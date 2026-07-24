// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// A degraded event time must not leak the formatter's escape hatch.
///
/// `formatJdDateTime` falls back to `jd.toStringAsFixed(...)` when no calendar
/// can render the value, so a non-finite JD used to reach the Rise/Set card and
/// its export as the literal string `NaN` (swe-dashboard/88). It is an em-dash
/// now, on both surfaces — they share one renderer so they cannot drift apart
/// again (swe-dashboard/82).
///
/// JD 0.0 is deliberately *not* treated as a sentinel: `riseTrans` signals "no
/// event" by throwing (`CircumpolarBodyException` on the C `-2` return), and
/// only writes its time on success, so 0.0 is a real instant here — unlike the
/// eclipse arrays, where 0.0 does mean "unset" and gets `_nonZero`.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/output_clock.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/tabs/rise_set/rise_set_provider.dart';

void main() {
  late SweUtils swe;
  const view = ClockView.ut;

  setUp(() {
    // revjul is a pure conversion that never reaches the engine.
    swe = SweUtils(EphemerisRunner());
  });

  /// The Date/Time cell of the first export row.
  String dateTimeCell(RiseSetResult result) {
    final rows = riseSetToExportRows(
      [RiseSetGroupResult(target: RiseSetTarget.body(0), result: result)],
      swe,
      view,
    );
    return rows.first.fields.firstWhere((f) => f.$1 == 'Date/Time').$2;
  }

  group('formatRiseSetEventTime', () {
    test('renders an em-dash for a NaN JD, not "NaN"', () {
      expect(formatRiseSetEventTime(swe, double.nan, view), '—');
    });

    test('renders an em-dash for an infinite JD', () {
      expect(formatRiseSetEventTime(swe, double.infinity, view), '—');
      expect(formatRiseSetEventTime(swe, double.negativeInfinity, view), '—');
    });

    test('renders an em-dash for a missing (null) event', () {
      expect(formatRiseSetEventTime(swe, null, view), '—');
    });

    test('renders JD 0.0 as the real instant it is, not a sentinel', () {
      // -4713-11-24, not -4712-01-01: ClockView.ut renders on the proleptic
      // Gregorian calendar, where the JD epoch falls in the previous year.
      final rendered = formatRiseSetEventTime(swe, 0.0, view);
      expect(rendered, isNot('—'));
      expect(rendered, contains('-4713-11-24'));
    });
  });

  group('riseSetToExportRows', () {
    test('exports a NaN event time as an em-dash', () {
      expect(dateTimeCell(const RiseSetResult(riseJd: double.nan)), '—');
    });

    test('exports JD 0.0 as a real date', () {
      expect(
        dateTimeCell(const RiseSetResult(riseJd: 0.0)),
        contains('-4713-11-24'),
      );
    });

    test('exports a missing event as an em-dash', () {
      expect(dateTimeCell(const RiseSetResult()), '—');
    });

    test('export and card render the same text for the same JD', () {
      // The two surfaces call one renderer; this pins that they agree on the
      // degraded values as well as the ordinary ones.
      for (final jd in [double.nan, 0.0, 2451545.0]) {
        expect(
          dateTimeCell(RiseSetResult(riseJd: jd)),
          formatRiseSetEventTime(swe, jd, view),
        );
      }
    });
  });
}
