// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Context Bar persistence round trip (swe-dashboard/80, A1).
///
/// `saveContextBar` / `loadContextBar` / `restoreFromPersistence` are three
/// lists of field names kept in lockstep by hand, so a field dropped from any
/// one of them is silent: the setting simply forgets itself on restart. That
/// is how `projection`, `userAyanT0IsUt` (saved and loaded, never applied) and
/// `jplFilename` (never saved) got lost.
///
/// The table below is the pin. Every persisted `ContextBarState` field belongs
/// in it — **add a field to the state, add a row here.** Each row is checked
/// twice: the custom value must differ from the default (or the round trip
/// would prove nothing), and it must survive save → restore.
///
/// The Moment (`jdUt`) is deliberately not persisted — the app
/// always starts at "now" — so it is absent from the table.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swe_dashboard/core/calendar.dart';
import 'package:swe_dashboard/core/context_provider.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/ephemeris/runner.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/core/swe_utils.dart';
import 'package:swe_dashboard/core/time_scale.dart';

/// Every persisted field, by name, as an accessor.
final _persistedFields = <String, Object? Function(ContextBarState)>{
  'utcOffset': (s) => s.utcOffset,
  'calendar': (s) => s.calendar,
  'timeScale': (s) => s.timeScale,
  'latitude': (s) => s.latitude,
  'longitude': (s) => s.longitude,
  'altitude': (s) => s.altitude,
  'cityLabel': (s) => s.cityLabel,
  'origin': (s) => s.origin,
  'zodiacRef': (s) => s.zodiacRef,
  'eqRef': (s) => s.eqRef,
  'ayanamsa': (s) => s.ayanamsa,
  'lastSiderealAyanamsa': (s) => s.lastSiderealAyanamsa,
  'userAyanT0': (s) => s.userAyanT0,
  'userAyanValue': (s) => s.userAyanValue,
  'userAyanT0IsUt': (s) => s.userAyanT0IsUt,
  'projection': (s) => s.projection,
  'epheSource': (s) => s.epheSource,
  'jplFilename': (s) => s.jplFilename,
};

/// All defaults, with the Moment pinned so the comparison is about the rest.
final _defaults = ContextBarState(utcOffset: 0.0, jdUt: 2451545.0);

/// Every persisted field moved off its default.
final _custom = ContextBarState(
  utcOffset: 5.5,
  jdUt: 2451545.0,
  calendar: Calendar.julian,
  timeScale: TimeScale.tt,
  latitude: 51.5,
  longitude: -0.1278,
  altitude: 35.0,
  cityLabel: 'London',
  origin: Origin.topocentric,
  zodiacRef: ZodiacRef.sidereal,
  eqRef: EqRef.meanEquinoxJ2000,
  ayanamsa: 255,
  lastSiderealAyanamsa: 3,
  userAyanT0: 2415020.0,
  userAyanValue: 22.5,
  userAyanT0IsUt: true,
  projection: SiderealProjection.solarSystemPlane,
  epheSource: EpheSource.jpl,
  jplFilename: 'de440.eph',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the custom state is off-default in every persisted field', () {
    for (final entry in _persistedFields.entries) {
      expect(
        entry.value(_custom),
        isNot(entry.value(_defaults)),
        reason:
            '${entry.key} must be non-default for the round trip to test it',
      );
    }
  });

  test('every persisted field survives save → restore', () async {
    SharedPreferences.setMockInitialValues({});
    final persistence = PersistenceService(
      await SharedPreferences.getInstance(),
    );
    persistence.saveContextBar(_custom);

    // The notifier restores in its constructor, starting from its own
    // defaults — i.e. exactly the fresh-launch path.
    // hasEpheFiles: true — the Ephemeris Source is only round-trippable when
    // .se1 files were staged, and passing it explicitly means this assertion
    // no longer depends on whether the test process happens to have any.
    final notifier = ContextBarNotifier(
      SweUtils(EphemerisRunner()),
      persistence,
      true,
    );
    addTearDown(notifier.dispose);
    final restored = notifier.state;

    for (final entry in _persistedFields.entries) {
      expect(
        entry.value(restored),
        entry.value(_custom),
        reason: '${entry.key} did not survive the round trip',
      );
    }
  });

  test(
    'a cleared JPL filename does not resurrect the previous choice',
    () async {
      SharedPreferences.setMockInitialValues({});
      final persistence = PersistenceService(
        await SharedPreferences.getInstance(),
      );
      persistence.saveContextBar(_custom);
      persistence.saveContextBar(_custom.copyWith(jplFilename: null));

      expect(persistence.loadContextBar().containsKey('jplFilename'), isFalse);
    },
  );
}
