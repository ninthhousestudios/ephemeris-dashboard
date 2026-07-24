// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// One Moment must not read as two different civil dates.
///
/// The Dates tab's Calendar card renders the same Julian Day the context bar
/// is showing, so it has to render it on the same Calendar. It used to take
/// `revjul`'s Gregorian default regardless, which put the card and the bar a
/// fortnight apart on any pre-1582 Moment.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;

import 'package:swe_dashboard/core/calendar.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/ephemeris/rust_eph.dart';
import 'package:swe_dashboard/core/jd_utils.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/tabs/dates/dates_provider.dart';

void main() {
  late RustEph eph;
  late EphemerisRunner runner;
  late SweUtils swe;

  setUp(() {
    eph = RustEph(
      const rs.EphemerisConfig(
        ephemerisSource: rs.EphemerisSource.swiss,
        ephePath: 'assets/ephe',
      ),
    );
    // SweUtils takes a runner, but the calendar surface under test (revjul) is
    // a pure conversion that never reaches the engine.
    runner = EphemerisRunner();
    swe = SweUtils(runner);
  });

  tearDown(() {
    eph.close();
    runner.close();
  });

  DatesResult compute(double jdUt, Calendar calendar) => computeDates(
    eph,
    swe,
    jdUt: jdUt,
    geolon: 0,
    iflag: 0,
    calendar: calendar,
  );

  // 1 Jan 1000: Julian and Gregorian are six days apart here, so a card
  // ignoring the calendar is unmistakably wrong rather than off by rounding.
  const medieval = 2086308.5;

  test('the Calendar card renders on the Context calendar', () {
    final julian = compute(medieval, Calendar.julian);
    final gregorian = compute(medieval, Calendar.gregorian);

    expect(julian.revjulError, isNull);
    expect(gregorian.revjulError, isNull);
    expect(
      (julian.revjulYear, julian.revjulMonth, julian.revjulDay),
      isNot((gregorian.revjulYear, gregorian.revjulMonth, gregorian.revjulDay)),
      reason: 'the calendar made no difference — it is being ignored',
    );
  });

  for (final calendar in Calendar.values) {
    test('card and context bar agree on one Moment (${calendar.label})', () {
      // What the context bar renders for this Moment, via the shared helper
      // every one of its fields goes through.
      final bar = JdUtils(swe).civilFieldsOn(medieval, calendar);
      final card = compute(medieval, calendar);

      expect(card.revjulYear, bar.year, reason: 'year');
      expect(card.revjulMonth, bar.month, reason: 'month');
      expect(card.revjulDay, bar.day, reason: 'day');
    });
  }

  test('Auto follows the reform, matching the bar on both sides', () {
    // Straddle 15 Oct 1582: before it Auto reads Julian, on/after it Gregorian.
    for (final jd in [Calendar.reformJd - 1, Calendar.reformJd + 1]) {
      final bar = JdUtils(swe).civilFieldsOn(jd, Calendar.auto);
      final card = compute(jd, Calendar.auto);
      expect(
        (card.revjulYear, card.revjulMonth, card.revjulDay),
        (bar.year, bar.month, bar.day),
        reason: 'JD $jd',
      );
    }
  });
}
