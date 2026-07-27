// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Owner-agnostic checks every `PrefField` list must pass (swe-dashboard/95).
///
/// The Context Bar and the Flag Bar persist through the same seam, so the
/// checks that are about the *seam* rather than about a particular state class
/// live here and are called from both round-trip tests. They drive the fields
/// directly; the owners' own tests cover the `PersistenceService` fold on top.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swe_dashboard/core/pref_field.dart';

Future<SharedPreferences> _storeHolding<S>(
  List<PrefField<S>> fields,
  S state,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  for (final field in fields) {
    field.save(prefs, state);
  }
  return prefs;
}

/// Restoring one field onto [defaults] must change the state — which happens
/// exactly when that field stored something *and* stored something non-default.
/// Those are the two halves of a meaningful round trip, checked per field with
/// no list of field names to keep in sync with anything.
///
/// A new field that nobody gave an off-default value in [custom] fails here,
/// because its round trip would otherwise prove nothing.
Future<void> expectEveryFieldCarriesAnOffDefaultValue<S>(
  List<PrefField<S>> fields, {
  required S defaults,
  required S custom,
}) async {
  final prefs = await _storeHolding(fields, custom);

  for (final field in fields) {
    expect(
      field.restore(prefs, defaults),
      isNot(defaults),
      reason:
          '${field.key} restored to the default — give it an off-default '
          'value in the custom state, or it is not actually round-tripped',
    );
  }
}

/// Each row's getter and setter must address the *same* state field.
///
/// A row that reads `latitude` and writes `longitude` is a copy-paste error the
/// old string-keyed persistence could not make and this shape can: both
/// directions type-check. Feeding the restore's own output back through the
/// same field catches it — a crossed row reads the *unwritten* field the second
/// time, so what it saves back is the default and the value does not survive.
///
/// A whole-state round trip catches most crossings on its own. What it misses,
/// and this does not, is a crossed pair whose custom values happen to be equal:
/// the swap is then invisible in the restored state. Verified by crossing
/// `latitude`/`altitude` with both set to 51.5 — only this check failed.
/// The cheaper benefit is diagnostic: this one names the offending key.
Future<void> expectGetterAndSetterAgree<S>(
  List<PrefField<S>> fields, {
  required S defaults,
  required S custom,
}) async {
  final first = await _storeHolding(fields, custom);

  // Computed while the first store is still populated: in tests
  // SharedPreferences hands back one cached instance, so the second store
  // below is the same object with a cleared backing map.
  final restored = [for (final field in fields) field.restore(first, defaults)];

  SharedPreferences.setMockInitialValues({});
  final second = await SharedPreferences.getInstance();

  for (var i = 0; i < fields.length; i++) {
    final field = fields[i];
    field.save(second, restored[i]);
    expect(
      field.restore(second, defaults),
      restored[i],
      reason:
          "${field.key}'s getter and setter do not address the same field: "
          'what it restores is not what it saves back',
    );
  }
}
