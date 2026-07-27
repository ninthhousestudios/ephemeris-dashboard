// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// A civil date typed into the Dates tab must reach the compute.
///
/// The tab has three editors over one Moment (Date, Time, JD) and a single
/// commit that preferred the JD field. Since the JD field still holds the last
/// good value while the user types a date, the civil parse was never reached —
/// the tab looked reactive and quietly computed the old Moment. This pins the
/// commit *by source*, and pins that the civil parse reads the Context
/// Calendar (the same entry is two different Moments on Julian vs Gregorian).
@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/core/calendar.dart';
import 'package:swe_dashboard/core/context_provider.dart';
import 'package:swe_dashboard/core/jd_utils.dart';
import 'package:swe_dashboard/core/swe_utils_provider.dart';
import 'package:swe_dashboard/tabs/dates/dates_provider.dart';
import 'package:swe_dashboard/tabs/dates/dates_tab.dart';

import 'support/widget_fixtures.dart';

void main() {
  /// Types [text] into the Dates tab's Date field and submits it.
  Future<void> enterDate(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> pumpTab(WidgetTester tester) async {
    await pumpAppWidget(
      tester,
      const DatesTab(),
      size: const Size(1400, 900),
      isLight: false,
      hostInScrollView: true,
    );
    return ProviderScope.containerOf(tester.element(find.byType(DatesTab)));
  }

  // 1 Jan 1000 is six days apart on the two calendars, so reading the entry on
  // the wrong one is unmistakable rather than a rounding difference.
  const entry = '1000-01-01';

  testWidgets('a typed Date reaches the override JD', (tester) async {
    final container = await pumpTab(tester);
    expect(container.read(datesOverrideJdProvider), isNull);

    await enterDate(tester, entry);

    final jd = container.read(datesOverrideJdProvider);
    expect(
      jd,
      isNotNull,
      reason: 'the typed date was dropped — the JD field won the commit',
    );

    final civil = JdUtils(
      container.read(sweProvider),
    ).civilFieldsOn(jd!, container.read(contextBarProvider).calendar);
    expect((civil.year, civil.month, civil.day), (1000, 1, 1));
  });

  testWidgets('a typed Date is read on the Context Calendar', (tester) async {
    final container = await pumpTab(tester);

    container.read(contextBarProvider.notifier).setCalendar(Calendar.julian);
    await tester.pumpAndSettle();
    await enterDate(tester, entry);
    final julian = container.read(datesOverrideJdProvider);

    container.read(contextBarProvider.notifier).setCalendar(Calendar.gregorian);
    await tester.pumpAndSettle();
    await enterDate(tester, entry);
    final gregorian = container.read(datesOverrideJdProvider);

    expect(julian, isNotNull);
    expect(
      julian,
      isNot(gregorian),
      reason:
          'the same civil entry gave one Moment on both calendars — the '
          'parse path is ignoring the Context Calendar',
    );
  });
}
