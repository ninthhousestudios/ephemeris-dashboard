// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// The linked IANA time zone is shown as a visible string in the context bar,
/// not merely in a hover tooltip (swe-dashboard/112).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/context_provider.dart';
import 'package:swe_dashboard/core/timezone_offset.dart';
import 'package:swe_dashboard/widgets/context_bar/context_bar.dart';

import 'support/widget_fixtures.dart';

void main() {
  setUpAll(ensureTimeZonesInitialized);

  void linkParis(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContextBar)),
    );
    container
        .read(contextBarProvider.notifier)
        .setLocation(
          latitude: 48.85,
          longitude: 2.35,
          cityLabel: 'Paris',
          timeZoneId: 'Europe/Paris',
        );
  }

  testWidgets('the full IANA zone string is visible once a city is linked', (
    tester,
  ) async {
    await pumpAppWidget(
      tester,
      const ContextBar(),
      size: const Size(1400, 900),
      isLight: false,
      hostInScrollView: true,
    );

    // Manual offset (no zone) → the label self-hides.
    expect(find.textContaining('Time zone:'), findsNothing);

    linkParis(tester);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Europe/Paris'),
      findsOneWidget,
      reason: 'the zone name must be on-screen, not only in a tooltip',
    );
  });

  testWidgets('the zone label survives 2x zoom without overflow', (
    tester,
  ) async {
    await pumpAppWidget(
      tester,
      const ContextBar(),
      size: const Size(1400, 900),
      isLight: false,
      hostInScrollView: true,
      textScale: 2.0,
    );

    linkParis(tester);
    await tester.pumpAndSettle();

    // A RenderFlex overflow would fail this test via FlutterError.
    expect(find.textContaining('Europe/Paris'), findsOneWidget);
  });
}
