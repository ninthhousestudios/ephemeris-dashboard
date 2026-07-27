// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Pref keys are unique across every state owner (swe-dashboard/95).
///
/// Two rows sharing a key silently collide: the later save wins and both rows
/// restore from the same slot, so one setting quietly tracks another. Nothing
/// in the type system prevents it — the key is just a string — and the
/// per-owner round-trip tests do not catch it, because each field is only ever
/// checked against itself.
///
/// Owners prefix their keys (`ctx_`, `flag_`), which is what keeps the two
/// lists apart; this pins that convention as well as the uniqueness it buys.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/flag_state.dart';

void main() {
  test('no two pref fields share a key', () {
    final keys = [
      ...contextBarPrefFields.map((f) => f.key),
      ...flagBarPrefFields.map((f) => f.key),
    ];
    final duplicates = [
      for (final key in keys.toSet())
        if (keys.where((k) => k == key).length > 1) key,
    ];

    expect(duplicates, isEmpty, reason: 'pref keys must be unique');
    expect(keys.toSet().length, keys.length);
  });

  test('each owner prefixes its keys', () {
    for (final field in contextBarPrefFields) {
      expect(field.key, startsWith('ctx_'), reason: '${field.key} in context');
    }
    for (final field in flagBarPrefFields) {
      expect(field.key, startsWith('flag_'), reason: '${field.key} in flags');
    }
  });
}
