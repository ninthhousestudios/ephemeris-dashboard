// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/tabs/ayanamsa/ayanamsa_provider.dart';

void main() {
  group('UserAyanamsaNotifier — arbitrary editable entries', () {
    test('add appends entries with distinct, stable ids', () {
      final n = UserAyanamsaNotifier()
        ..add()
        ..add();
      expect(n.state.length, 2);
      expect(n.state[0].id, isNot(n.state[1].id));
      // Default seed is J2000 so a fresh entry is swetest-comparable, not 0.
      expect(n.state[0].t0, 2451545.0);
    });

    test('update mutates only the matching entry, by id', () {
      final n = UserAyanamsaNotifier()
        ..add()
        ..add();
      final firstId = n.state[0].id;
      final secondId = n.state[1].id;

      n.update(firstId, t0: 2440000, value: 23.5, t0IsUt: true);

      final first = n.state.firstWhere((u) => u.id == firstId);
      final second = n.state.firstWhere((u) => u.id == secondId);
      expect(first.t0, 2440000);
      expect(first.value, 23.5);
      expect(first.t0IsUt, isTrue);
      // Untouched entry keeps its defaults.
      expect(second.t0, 2451545.0);
      expect(second.t0IsUt, isFalse);
    });

    test('partial update leaves unspecified fields intact', () {
      final n = UserAyanamsaNotifier()..add();
      final id = n.state[0].id;
      n
        ..update(id, t0IsUt: true)
        ..update(id, value: 24.1); // must not reset t0IsUt
      expect(n.state[0].t0IsUt, isTrue);
      expect(n.state[0].value, 24.1);
    });

    test('removeById drops one entry and keeps the rest', () {
      final n = UserAyanamsaNotifier()
        ..add()
        ..add();
      final keep = n.state[1].id;
      n.removeById(n.state[0].id);
      expect(n.state.map((u) => u.id), [keep]);
    });

    test('ids are not reused after removal', () {
      final n = UserAyanamsaNotifier()..add();
      final firstId = n.state[0].id;
      n
        ..removeById(firstId)
        ..add();
      expect(n.state.single.id, isNot(firstId));
    });
  });
}
