// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/calculation/series_settings_provider.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/layout/tab_definitions.dart';
import 'package:swe_dashboard/tabs/planets/planets_provider.dart';
import 'package:swe_dashboard/tabs/planets/planets_tab.dart';
import 'package:swe_dashboard/widgets/quantity_picker.dart';
import 'package:swe_dashboard/widgets/result_card.dart';
import 'package:swe_dashboard/widgets/series_bar.dart';
import 'package:swe_dashboard/widgets/series_view.dart';

import 'goldens/golden_helper.dart';

final _tabId = AppTab.planets.name;

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

/// Two steps a day apart, Sun and Moon, standing in for a real series.
final _fakeSeries = <(Moment, CalcOutcome<List<PlanetResult>>)>[
  (
    Moment(ut: 2451545.0, deltaT: 0),
    CalcOk([_planet('Sun', 280.0), _planet('Moon', 66.0)]),
  ),
  (
    Moment(ut: 2451546.0, deltaT: 0),
    CalcOk([_planet('Sun', 281.0), _planet('Moon', 81.0)]),
  ),
];

void main() {
  /// Pumps the tab the way the app shell does: inside a vertically scrolling,
  /// **unbounded-height** parent. `AppShell.body` is a `SingleChildScrollView`,
  /// so a series surface that expects bounded height throws there and nowhere
  /// else — which is exactly the kind of break a bounded test harness misses.
  Future<ProviderContainer> pumpTab(WidgetTester tester) async {
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
        ...tabOverrides,
        planetsSeriesProvider.overrideWith((ref) => _fakeSeries),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PlanetsTab())),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('the series bar is offered, and mode defaults to single-Moment', (
    tester,
  ) async {
    await pumpTab(tester);

    expect(find.byType(SeriesBar), findsOneWidget);
    expect(find.byType(SeriesView), findsNothing);
    // The single-Moment surface: one card per body.
    expect(find.byType(ResultCard), findsWidgets);
  });

  testWidgets('series mode swaps the cards for the shared grid', (
    tester,
  ) async {
    final container = await pumpTab(tester);
    container.read(seriesSettingsProvider(_tabId).notifier).setEnabled(true);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SeriesView), findsOneWidget);
    expect(find.byType(ResultCard), findsNothing);

    // Columns are (body, quantity) pairs off planetsToExportRows — no
    // Planets-specific grid code produced these.
    expect(find.text('Sun Longitude'), findsOneWidget);
    expect(find.text('Moon Longitude'), findsOneWidget);
    expect(find.byType(QuantityPicker), findsOneWidget);

    // One row per step, labelled with the step's civil date.
    expect(find.textContaining('2000-01-01'), findsOneWidget);
    expect(find.textContaining('2000-01-02'), findsOneWidget);
  });

  testWidgets('hiding a quantity drops it for every body', (tester) async {
    final container = await pumpTab(tester);
    container.read(seriesSettingsProvider(_tabId).notifier).setEnabled(true);
    await tester.pump();

    expect(find.text('Sun Latitude'), findsOneWidget);
    expect(find.text('Moon Latitude'), findsOneWidget);

    // The picker chip and the column heading share the label text.
    await tester.tap(find.widgetWithText(FilterChip, 'Latitude'));
    await tester.pump();

    expect(find.text('Sun Latitude'), findsNothing);
    expect(find.text('Moon Latitude'), findsNothing);
    expect(find.text('Sun Longitude'), findsOneWidget);
  });
}
