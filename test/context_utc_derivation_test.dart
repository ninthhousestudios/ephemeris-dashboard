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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swe_dashboard/core/calendar.dart';
import 'package:swe_dashboard/core/context_provider.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/ephe/bootstrap.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/jd_utils.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/core/timezone_offset.dart';
import 'package:swe_dashboard/tabs/rise_set/rise_set_provider.dart';

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

  // ── Relocation mode (anchorJd, swe-dashboard/117) ──────────────────────────

  test('relocation mode keeps the instant and re-derives the clock for the '
      'new place', () async {
    // Start linked to New York at a summer wall time (EDT, -4).
    final n = await linkedAt(_c(1985, 7, 15, 14, 30));
    final jdFixed = n.state.jdUt;
    expect(n.state.utcOffset, -4.0);

    n.setAnchorJd(true);
    n.setLocation(
      latitude: 35.7,
      longitude: 139.7,
      cityLabel: 'Tokyo',
      timeZoneId: 'Asia/Tokyo',
    );

    expect(n.state.jdUt, jdFixed, reason: 'the instant is held fixed');
    expect(n.state.timeZoneId, 'Asia/Tokyo');
    expect(n.state.utcOffset, 9.0, reason: 'JST at that instant');
    // The offset must be exactly what the instant→offset resolver gives for the
    // new zone. (That this keeps the Rise/Set search window coherent is a
    // separate claim, checked end-to-end in the localMidnightStart tests below
    // — this assertion alone is only the offset value, swe-dashboard/118.)
    expect(
      n.state.utcOffset,
      resolveTzOffsetForInstant(
        'Asia/Tokyo',
        ju.civilFieldsOn(jdFixed, Calendar.gregorian),
      ).offsetHours,
    );
    // Same instant, new offset → the wall clock shifts. NY 14:30 EDT is
    // 18:30 UTC; Tokyo (+9) reads that as 03:30 the next day.
    expect(wallOf(n.state), (1985, 7, 16, 3, 30));
  });

  test('default mode keeps the wall clock on a place change (relocation off '
      'contrast)', () async {
    final n = await linkedAt(_c(1985, 7, 15, 14, 30));
    expect(n.state.anchorJd, isFalse, reason: 'off by default');
    final jdBefore = n.state.jdUt;

    n.setLocation(
      latitude: 35.7,
      longitude: 139.7,
      cityLabel: 'Tokyo',
      timeZoneId: 'Asia/Tokyo',
    );

    expect(n.state.utcOffset, 9.0, reason: 'JST');
    expect(wallOf(n.state), (1985, 7, 15, 14, 30), reason: 'wall time kept');
    expect(
      n.state.jdUt,
      isNot(closeTo(jdBefore, 1e-9)),
      reason: 'the instant moves so the wall clock can stay put',
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

  // ── Relocation status label coherence (swe-dashboard/118) ──────────────────
  //
  // The status label (contextTzStatusProvider) must show the offset the
  // notifier committed. In anchorJd mode the committed offset is instant-
  // derived; a fall-back fold makes the *reconstructed* wall time ambiguous, so
  // deriving the label from the wall time re-picked the other occurrence and
  // contradicted the UTC field. These read the REAL provider through a
  // container, not a copy of its math.
  Future<({ContextBarNotifier n, ProviderContainer c})> container() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        epheSeedProvider.overrideWithValue(const EpheBootstrap.none()),
      ],
    );
    addTearDown(c.dispose);
    return (n: c.read(contextBarProvider.notifier), c: c);
  }

  // NY fall-back 2021: 02:00 EDT → 01:00 EST on 7 Nov, so local 01:00–02:00
  // occurs twice — first as EDT (−4, 05:xx UTC), then as EST (−5, 06:xx UTC).
  // The second occurrence is the one that exposed the bug (committed −5, wall
  // re-resolved to −4); the first is included so both fold occurrences are
  // covered.
  for (final (hourUtc, label, wantOffset) in const [
    (5, 'first occurrence (EDT)', -4.0),
    (6, 'second occurrence (EST)', -5.0),
  ]) {
    test('anchorJd relocation onto a NY fall-back fold shows the committed '
        'offset, not the re-resolved wall offset — $label', () async {
      final (:n, :c) = await container();
      n.setAnchorJd(true);
      // Link elsewhere, then relocate to NY holding the folded instant fixed.
      n.setLocation(
        latitude: 35.7,
        longitude: 139.7,
        cityLabel: 'Tokyo',
        timeZoneId: 'Asia/Tokyo',
      );
      n.setJd(ju.dateTimeToJd(DateTime.utc(2021, 11, 7, hourUtc, 30)));
      n.setLocation(
        latitude: 40.7,
        longitude: -74.0,
        cityLabel: 'New York',
        timeZoneId: _nyc,
      );

      expect(
        n.state.utcOffset,
        wantOffset,
        reason: 'committed instant-derived offset',
      );
      final status = c.read(contextTzStatusProvider);
      expect(status, isNotNull);
      expect(
        status!.resolution.offsetHours,
        n.state.utcOffset,
        reason: 'the label offset must equal the committed offset at a fold',
      );
      expect(
        status.resolution.warnings,
        contains(TzWarning.ambiguous),
        reason: 'the folded wall clock is still flagged — just not mis-valued',
      );
    });
  }

  // ── Rise/Set search window under relocation (swe-dashboard/118) ────────────
  //
  // utcOffset is a *compute* input for Rise/Set: localMidnightStart anchors the
  // search on the local calendar day (lesson 019f9071), so a relocation must
  // move the window to the new zone's local midnight. Asserting the offset
  // value alone (the old test) would not catch a broken offset→window wiring —
  // these drive the real function the provider feeds riseTrans.
  test('anchorJd relocation moves the Rise/Set local-midnight window to the '
      'new zone', () async {
    // Link NY (EDT −4), then relocate to Tokyo (+9) holding the instant.
    final n = await linkedAt(_c(1985, 7, 15, 14, 30));
    expect(n.state.utcOffset, -4.0);
    final staleWindow = localMidnightStart(n.state.jdUt, n.state.utcOffset);

    n.setAnchorJd(true);
    n.setLocation(
      latitude: 35.7,
      longitude: 139.7,
      cityLabel: 'Tokyo',
      timeZoneId: 'Asia/Tokyo',
    );
    expect(n.state.utcOffset, 9.0, reason: 'JST at the fixed instant');

    final window = localMidnightStart(n.state.jdUt, n.state.utcOffset);
    expect(
      window,
      isNot(staleWindow),
      reason: 'a relocation that left the offset stale would not move the day',
    );
    // The window is local-midnight-in-UT for the NEW zone: reading it back with
    // the +9 offset must land on Tokyo midnight (NY 14:30 EDT = 18:30Z = Tokyo
    // 03:30 on the 16th, whose local midnight is 15:00Z on the 15th).
    final localMid = ju.localCivilOf(
      window,
      calendar: Calendar.gregorian,
      scale: n.state.timeScale,
      offsetHours: 9.0,
    );
    expect((localMid.year, localMid.month, localMid.day), (1985, 7, 16));
    expect(
      (localMid.hour, localMid.minute),
      (0, 0),
      reason: 'window anchors on Tokyo local midnight',
    );
  });

  test(
    'Rise/Set window under anchorJd uses the DST-transition-day offset',
    () async {
      // Relocate onto the NY fall-back day at an instant past the transition
      // (EST −5). The window must anchor on the local day for −5.
      final (:n, :c) = await container();
      n.setAnchorJd(true);
      n.setJd(ju.dateTimeToJd(DateTime.utc(2021, 11, 7, 6, 30)));
      n.setLocation(
        latitude: 40.7,
        longitude: -74.0,
        cityLabel: 'New York',
        timeZoneId: _nyc,
      );
      expect(n.state.utcOffset, -5.0, reason: 'EST after the fall-back');

      final window = localMidnightStart(n.state.jdUt, n.state.utcOffset);
      final localMid = ju.localCivilOf(
        window,
        calendar: Calendar.gregorian,
        scale: n.state.timeScale,
        offsetHours: -5.0,
      );
      expect((localMid.year, localMid.month, localMid.day), (2021, 11, 7));
      expect(
        (localMid.hour, localMid.minute),
        (0, 0),
        reason: 'window anchors on the local day for the committed offset',
      );
    },
  );
}
