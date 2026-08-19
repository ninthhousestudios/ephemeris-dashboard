// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Switching to a tab whose series was left on by a past run must defer its
/// first run behind the "Calculating…" placeholder, exactly like toggling the
/// Series chip does — otherwise the tab computes on the frame it appears and
/// looks frozen (the case the SeriesBar-driven flag alone does not cover).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:swe_dashboard/core/active_tab.dart';
import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/calculation/series_settings_provider.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/layout/app_shell.dart';
import 'package:swe_dashboard/layout/tab_definitions.dart';
import 'package:swe_dashboard/tabs/planets/planets_provider.dart';
import 'package:swe_dashboard/widgets/series_view.dart';

import 'support/widget_fixtures.dart';

PlanetResult _planet(String name, double longitude) => PlanetResult(
  body: 0,
  bodyName: name,
  longitude: longitude,
  latitude: 0.5,
  distance: 1.0,
  speedLon: 1.0,
  speedLat: 0.0,
  speedDist: 0.0,
  returnFlag: 2,
);

final _fakeSeries = <(Moment, CalcOutcome<List<PlanetResult>>)>[
  (Moment(ut: 2451545.0, deltaT: 0), CalcOk([_planet('Sun', 280.0)])),
];

void main() {
  testWidgets('switching to a persisted-series tab shows Calculating… first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        epheBootstrapOverride,
        ...tabOverrides,
        planetsSeriesProvider.overrideWith((ref) => _fakeSeries),
      ],
    );
    addTearDown(container.dispose);

    // Start off the Planets tab, with its series already on (as a past run left
    // it) — the state the SeriesBar flag never sees, because nothing touched it.
    container.read(activeTabProvider.notifier).state = AppTab.dates;
    container
        .read(seriesSettingsProvider(AppTab.planets.name).notifier)
        .setEnabled(true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();
    expect(find.text('Calculating…'), findsNothing);

    // Switch to Planets: the shell arms the flag before the tab mounts, so its
    // first frame is the placeholder, not the run.
    container.read(activeTabProvider.notifier).state = AppTab.planets;
    await tester.pump();
    expect(find.text('Calculating…'), findsOneWidget);
    // The placeholder cleared the flag as it painted — the run is no longer held.
    expect(
      container.read(seriesCalculatingProvider(AppTab.planets.name)),
      isFalse,
    );

    await tester.pumpAndSettle();
    expect(find.text('Calculating…'), findsNothing);
    expect(find.byType(SeriesView), findsOneWidget);
  });

  testWidgets('switching back to an already-computed series tab does not '
      're-arm', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        epheBootstrapOverride,
        ...tabOverrides,
        planetsSeriesProvider.overrideWith((ref) => _fakeSeries),
      ],
    );
    addTearDown(container.dispose);

    container.read(activeTabProvider.notifier).state = AppTab.dates;
    container
        .read(seriesSettingsProvider(AppTab.planets.name).notifier)
        .setEnabled(true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    // First visit arms and settles.
    container.read(activeTabProvider.notifier).state = AppTab.planets;
    await tester.pumpAndSettle();

    // Leave and come back: the series is cached, so the second visit renders the
    // grid straight away with no placeholder frame.
    container.read(activeTabProvider.notifier).state = AppTab.dates;
    await tester.pumpAndSettle();
    container.read(activeTabProvider.notifier).state = AppTab.planets;
    await tester.pump();

    expect(find.text('Calculating…'), findsNothing);
    expect(find.byType(SeriesView), findsOneWidget);
  });
}
