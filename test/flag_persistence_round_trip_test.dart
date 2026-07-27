// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Flag Bar persistence round trip (swe-dashboard/95).
///
/// The Flag Bar moved onto the same declarative seam as the Context Bar in
/// swe-dashboard/86 but kept no test of its own, so its two fields rode an
/// untested codec path. This mirrors `context_persistence_round_trip_test.dart`:
/// the seam-level checks come from `pref_field_checks.dart`, and what is left
/// here is what is specific to `FlagBarState`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swe_dashboard/core/flag_provider.dart';
import 'package:swe_dashboard/core/flag_state.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/core/swe_constants.dart';

import 'support/pref_field_checks.dart';

const _defaults = FlagBarState();

/// Every persisted field moved off its default. `lockedFlags` is set too, and
/// deliberately: the assertions below pin that it does *not* come back.
const _custom = FlagBarState(
  coordValue: seFlgXyz,
  toggles: {seFlgSpeed, seFlgTruePos},
  lockedFlags: seFlgNoNut,
);

Future<PersistenceService> _storeHolding(FlagBarState s) async {
  SharedPreferences.setMockInitialValues({});
  return PersistenceService(await SharedPreferences.getInstance())
    ..saveFlagBar(s);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every pref field carries an off-default value through the store', () {
    return expectEveryFieldCarriesAnOffDefaultValue(
      flagBarPrefFields,
      defaults: _defaults,
      custom: _custom,
    );
  });

  test("each row's getter and setter address the same field", () {
    return expectGetterAndSetterAgree(
      flagBarPrefFields,
      defaults: _defaults,
      custom: _custom,
    );
  });

  test('the persisted state survives save → restore', () async {
    final store = await _storeHolding(_custom);
    // lockedFlags excluded: it is a pure function of the Context, so the store
    // must not be a second source of truth for it.
    expect(store.restoreFlagBar(_defaults), _custom.copyWith(lockedFlags: 0));
  });

  test('locked flags are not persisted', () async {
    final store = await _storeHolding(_custom);
    expect(store.restoreFlagBar(_defaults).lockedFlags, 0);
  });

  test('the notifier restores on construction', () async {
    final store = await _storeHolding(_custom);
    final notifier = FlagBarNotifier(store)..restoreFromPersistence();
    addTearDown(notifier.dispose);

    expect(notifier.state.coordValue, _custom.coordValue);
    expect(notifier.state.toggles, _custom.toggles);
    expect(notifier.state.lockedFlags, 0);
  });
}
