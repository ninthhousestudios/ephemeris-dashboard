// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Context Bar persistence round trip (swe-dashboard/80 A1, swe-dashboard/86).
///
/// Save and restore fold over one list — `contextBarPrefFields`, beside the
/// state class. Before that they were three hand-synced lists of field names,
/// and a field dropped from any one of them was silent: the setting simply
/// forgot itself on restart. That is how `projection`, `userAyanT0IsUt` (saved
/// and loaded, never applied) and `jplFilename` (never saved) got lost.
///
/// One list makes the two directions agree by construction, so these tests no
/// longer name fields one by one. They iterate `contextBarPrefFields` itself:
/// every row, present and future, is checked to carry a value from [_custom]
/// through the store and back. What a new field still needs is an off-default
/// value in [_custom] — omit it and the round trip for that row proves nothing,
/// which is exactly what the first test fails on.
///
/// The Moment (`jdUt`) is deliberately not persisted — the app always starts at
/// "now" — so it is absent from the pref list and pinned equal in both states
/// here.
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

import 'support/pref_field_checks.dart';

/// All defaults, with the Moment pinned so the comparison is about the rest.
const _defaults = ContextBarState(utcOffset: 0.0, jdUt: 2451545.0);

/// Every persisted field moved off its default.
const _custom = ContextBarState(
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

/// A fresh store holding [s].
Future<PersistenceService> _storeHolding(ContextBarState s) async {
  SharedPreferences.setMockInitialValues({});
  return PersistenceService(await SharedPreferences.getInstance())
    ..saveContextBar(s);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every pref field carries an off-default value through the store', () {
    return expectEveryFieldCarriesAnOffDefaultValue(
      contextBarPrefFields,
      defaults: _defaults,
      custom: _custom,
    );
  });

  test("each row's getter and setter address the same field", () {
    return expectGetterAndSetterAgree(
      contextBarPrefFields,
      defaults: _defaults,
      custom: _custom,
    );
  });

  test('the whole state survives save → restore', () async {
    final store = await _storeHolding(_custom);
    // This is the one that pins the pref list to the state class: a field
    // added to ContextBarState and to _custom but given no pref row comes back
    // as its default here, and the whole-state comparison fails.
    expect(store.restoreContextBar(_defaults), _custom);
  });

  test('the notifier restores on construction', () async {
    final store = await _storeHolding(_custom);

    // The notifier restores in its constructor, starting from its own
    // defaults — i.e. exactly the fresh-launch path.
    // hasEpheFiles: true — the Ephemeris Source is only round-trippable when
    // .se1 files were staged, and passing it explicitly means this assertion
    // no longer depends on whether the test process happens to have any.
    final notifier = ContextBarNotifier(
      SweUtils(EphemerisRunner()),
      store,
      true,
    );
    addTearDown(notifier.dispose);

    // jdUt is not persisted: the notifier starts at "now", so compare the rest.
    expect(notifier.state.copyWith(jdUt: _custom.jdUt), _custom);
  });

  test(
    'a cleared JPL filename does not resurrect the previous choice',
    () async {
      final store = await _storeHolding(_custom);
      store.saveContextBar(_custom.copyWith(jplFilename: null));

      // Restored onto the defaults — the fresh-launch path, where nothing but
      // the store could supply a filename.
      expect(store.restoreContextBar(_defaults).jplFilename, isNull);
    },
  );
}
