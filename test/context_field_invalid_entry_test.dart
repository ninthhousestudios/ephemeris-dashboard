// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// A rejected context-bar entry must never just vanish.
///
/// Every entry field in the bar commits on blur, and a value it cannot parse
/// snaps back to the canonical Moment. Reverting in silence reads as the app
/// eating the keystrokes, so each field also names what it rejected. This pins
/// both halves — the revert and the report — for all three fields, so the next
/// field added to the bar has a pattern with a test behind it rather than one
/// that has to be remembered (the JD field is here because it was the one that
/// had the revert and not the report).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/widgets/context_bar/context_date_field.dart';
import 'package:swe_dashboard/widgets/context_bar/context_jd_field.dart';
import 'package:swe_dashboard/widgets/context_bar/context_time_field.dart';

import 'support/widget_fixtures.dart';

void main() {
  /// Types [text] into the field, blurs it (which is what commits), and returns
  /// the text the field settled on.
  Future<String> enterAndBlur(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
    // Blur by moving focus away — the same path as tabbing or clicking off.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    return tester
        .widget<TextField>(find.byType(TextField).first)
        .controller!
        .text;
  }

  Future<void> pump(WidgetTester tester, Widget field) =>
      pumpAppWidget(tester, field, size: const Size(1400, 900), isLight: false);

  final cases = <({String name, Widget field, String bad, String fragment})>[
    (
      name: 'JD',
      field: const ContextJdField(),
      bad: '..',
      fragment: 'not a valid Julian Day',
    ),
    (
      name: 'Date',
      field: const ContextDateField(),
      // 29 Feb 1990 is not a date on any calendar the bar offers.
      bad: '1990-02-29',
      fragment: 'not a valid',
    ),
    (
      name: 'Time',
      field: const ContextTimeField(),
      bad: '99:99:99',
      fragment: 'not a valid time',
    ),
  ];

  for (final c in cases) {
    testWidgets('${c.name} field reverts and reports an unparseable entry', (
      tester,
    ) async {
      await pump(tester, c.field);
      final before = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!
          .text;
      expect(before, isNotEmpty, reason: '${c.name} field did not seed');

      final after = await enterAndBlur(tester, c.bad);

      expect(
        after,
        before,
        reason: '${c.name} field kept the rejected entry instead of reverting',
      );
      expect(
        find.textContaining(c.fragment),
        findsOneWidget,
        reason: '${c.name} field reverted without telling the user why',
      );
    });

    testWidgets('${c.name} field reverts an empty entry without complaint', (
      tester,
    ) async {
      await pump(tester, c.field);
      final before = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!
          .text;

      final after = await enterAndBlur(tester, '');

      expect(after, before);
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'clearing a field is not an error',
      );
    });
  }
}
