// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// The Context's UTC offset as a *derived* projection of a linked time zone
/// (swe-dashboard/112).
///
/// Drives the whole pipe through [ContextBarNotifier] (not just the resolver):
/// city select links a zone and re-derives the offset while preserving the
/// entered wall time; editing the offset by hand detaches; changing the date
/// across a DST boundary re-derives; the link persists and clears through a
/// save→restore round trip; and a series step never perturbs it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swe_dashboard/core/calendar.dart';
import 'package:swe_dashboard/core/context_provider.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/jd_utils.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/core/timezone_offset.dart';

const _nyc = 'America/New_York';

Civil _c(int y, int mo, int d, [int h = 0, int mi = 0, int s = 0]) =>
    (year: y, month: mo, day: d, hour: h, minute: mi, second: s);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensureTimeZonesInitialized);

  late SweUtils swe;
  late JdUtils ju;
  setUp(() {
    swe = SweUtils(EphemerisRunner());
    ju = JdUtils(swe);
  });

  Future<ContextBarNotifier> notifier() async {
    SharedPreferences.setMockInitialValues({});
    final store = PersistenceService(await SharedPreferences.getInstance());
    final n = ContextBarNotifier(swe, store, true);
    addTearDown(n.dispose);
    return n;
  }

  (int, int, int, int, int) wallOf(ContextBarState s) {
    final w = ju.localCivilOf(
      s.jdUt,
      calendar: s.calendar,
      scale: s.timeScale,
      offsetHours: s.utcOffset,
    );
    return (w.year, w.month, w.day, w.hour, w.minute);
  }

  /// Link New York with the given wall time already entered on a zero offset.
  Future<ContextBarNotifier> linkedAt(Civil wall) async {
    final n = await notifier();
    n.setUtcOffset(0);
    n.setLocalCivil(wall);
    n.setLocation(
      latitude: 40.7,
      longitude: -74.0,
      cityLabel: 'New York',
      timeZoneId: _nyc,
    );
    return n;
  }

  test('city select links the zone, derives the offset, keeps the wall '
      'time', () async {
    final n = await notifier();
    n.setUtcOffset(0);
    n.setLocalCivil(_c(1985, 7, 15, 14, 30));
    final jdBefore = n.state.jdUt;

    n.setLocation(
      latitude: 40.7,
      longitude: -74.0,
      cityLabel: 'New York',
      timeZoneId: _nyc,
    );

    expect(n.state.timeZoneId, _nyc);
    expect(n.state.utcOffset, -4.0, reason: 'EDT in July');
    expect(wallOf(n.state), (
      1985,
      7,
      15,
      14,
      30,
    ), reason: 'wall time preserved');
    // Wall kept, offset 0 → -4, so the canonical UT Moment moves +4h.
    expect(n.state.jdUt, closeTo(jdBefore + 4 / 24, 1e-9));
  });

  test('editing the offset by hand detaches from the linked zone', () async {
    final n = await linkedAt(_c(1985, 7, 15, 14, 30));
    expect(n.state.timeZoneId, isNotNull);

    n.setUtcOffset(3.0);

    expect(n.state.timeZoneId, isNull);
    expect(n.state.utcOffset, 3.0);
  });

  test(
    'changing the date across a DST boundary re-derives the offset',
    () async {
      final n = await linkedAt(_c(1985, 7, 15, 14, 30));
      expect(n.state.utcOffset, -4.0);

      // Same wall-clock time, winter date — exactly what the date field commits.
      n.setLocalCivil(_c(1985, 1, 15, 14, 30));

      expect(n.state.utcOffset, -5.0, reason: 'EST in January');
      expect(wallOf(n.state), (
        1985,
        1,
        15,
        14,
        30,
      ), reason: 'wall time preserved');
    },
  );

  test('a linked zone survives a save → restore round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PersistenceService(await SharedPreferences.getInstance());
    final n1 = ContextBarNotifier(swe, store, true);
    addTearDown(n1.dispose);
    n1.setLocalCivil(_c(1985, 7, 15, 14, 30));
    n1.setLocation(
      latitude: 40.7,
      longitude: -74.0,
      cityLabel: 'New York',
      timeZoneId: _nyc,
    );
    expect(n1.state.timeZoneId, _nyc);

    final n2 = ContextBarNotifier(swe, store, true);
    addTearDown(n2.dispose);
    expect(n2.state.timeZoneId, _nyc, reason: 'the link restores on launch');
  });

  test(
    'detaching persists as no-zone and does not resurrect on restore',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PersistenceService(await SharedPreferences.getInstance());
      final n1 = ContextBarNotifier(swe, store, true);
      addTearDown(n1.dispose);
      n1.setLocalCivil(_c(1985, 7, 15, 14, 30));
      n1.setLocation(
        latitude: 40.7,
        longitude: -74.0,
        cityLabel: 'New York',
        timeZoneId: _nyc,
      );
      n1.setUtcOffset(3.0); // detach

      final n2 = ContextBarNotifier(swe, store, true);
      addTearDown(n2.dispose);
      expect(n2.state.timeZoneId, isNull);
    },
  );

  test('a Julian-calendar wall date resolves on the Gregorian frame', () async {
    // tzdata is Gregorian-indexed. Julian 2021-03-07 == Gregorian 2021-03-20,
    // which is past New York's 2021-03-14 spring-forward, so the offset is
    // EDT (-4). Reading the fields as Gregorian March 7 would wrongly give
    // EST (-5) with no warning — the TZ-002 defect.
    final n = await notifier();
    n.setUtcOffset(0);
    n.setCalendar(Calendar.julian);
    n.setLocalCivil(_c(2021, 3, 7, 12));
    n.setLocation(
      latitude: 40.7,
      longitude: -74.0,
      cityLabel: 'New York',
      timeZoneId: _nyc,
    );
    expect(
      n.state.utcOffset,
      -4.0,
      reason: 'the Gregorian equivalent (2021-03-20) is EDT',
    );
  });

  test('a linked zone re-derives its offset on restore, discarding a stale '
      'persisted value', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // The shape a cross-season restart leaves behind: a linked NY zone with an
    // offset no NY date produces (saved in one DST regime, restored on a "now"
    // Moment in another — jdUt is not persisted). Restore must re-derive it.
    await prefs.setString('ctx_time_zone_id', _nyc);
    await prefs.setDouble('ctx_utc_offset', 9.0);
    final store = PersistenceService(prefs);

    final n = ContextBarNotifier(swe, store, true);
    addTearDown(n.dispose);

    expect(n.state.timeZoneId, _nyc, reason: 'the link restores');
    expect(
      n.state.utcOffset,
      isNot(9.0),
      reason: 'the stale persisted offset must be re-derived, not kept',
    );
    expect(
      n.state.utcOffset,
      anyOf(-5.0, -4.0),
      reason: 'a real New York offset for the fresh Moment',
    );
  });

  test('series-step Moments do not re-derive the Context offset', () async {
    final n = await linkedAt(_c(1985, 7, 15, 14, 30));
    expect(n.state.utcOffset, -4.0);

    // A series steps the Context Moment forward; ~6 months on lands in EST.
    final winterStep = n.state.jdUt + 184;
    final stepZone = resolveTzOffsetForInstant(
      _nyc,
      ju.civilFieldsOn(winterStep, n.state.calendar),
    );
    expect(
      stepZone.offsetHours,
      -5.0,
      reason: 'the winter step is genuinely a different DST regime',
    );

    // The offset is a function of the Context Moment, never a series step.
    expect(n.state.utcOffset, -4.0);
    expect(n.state.timeZoneId, _nyc);
  });
}
