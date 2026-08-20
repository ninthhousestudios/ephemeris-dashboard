// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Shared widget-test fixtures: fake Results, the provider overrides that feed
/// them to a tab, and a pump helper. [screenSurfaces] is the list
/// `test/layout_invariants_test.dart` sweeps — a new screen-level surface added
/// there is picked up by the sweep with no other change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:swe_dashboard/core/ephe/bootstrap.dart';
import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
import 'package:swe_dashboard/core/display_format.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/layout/app_shell.dart';
import 'package:swe_dashboard/core/user_ayanamsa.dart';
import 'package:swe_dashboard/tabs/ayanamsa/ayanamsa_provider.dart';
import 'package:swe_dashboard/tabs/ayanamsa/ayanamsa_tab.dart';
import 'package:swe_dashboard/tabs/coordinates/coordinates_tab.dart';
import 'package:swe_dashboard/tabs/crossings/crossings_tab.dart';
import 'package:swe_dashboard/tabs/dates/dates_tab.dart';
import 'package:swe_dashboard/tabs/differential/differential_tab.dart';
import 'package:swe_dashboard/tabs/heliacal/heliacal_provider.dart';
import 'package:swe_dashboard/tabs/heliacal/heliacal_tab.dart';
import 'package:swe_dashboard/tabs/houses/houses_provider.dart';
import 'package:swe_dashboard/tabs/houses/houses_tab.dart';
import 'package:swe_dashboard/tabs/jpl_horizons/jpl_horizons_tab.dart';
import 'package:swe_dashboard/tabs/math/math_tab.dart';
import 'package:swe_dashboard/tabs/nodes_apsides/nodes_apsides_tab.dart';
import 'package:swe_dashboard/tabs/phenomena/phenomena_tab.dart';
import 'package:swe_dashboard/tabs/planets/planets_provider.dart';
import 'package:swe_dashboard/tabs/planets/planets_tab.dart';
import 'package:swe_dashboard/tabs/rise_set/rise_set_tab.dart';
import 'package:swe_dashboard/tabs/stars/stars_tab.dart';
import 'package:swe_dashboard/theme/app_themes.dart';
import 'package:swe_dashboard/widgets/context_bar/context_bar.dart';
import 'package:swe_dashboard/widgets/flag_bar/flag_bar.dart';
import 'package:swe_dashboard/widgets/result_card.dart';

// ── Viewport sizes ──

const Size kMobile = Size(400, 800);
const Size kTablet = Size(800, 1024);
const Size kDesktop = Size(1400, 900);

const kSizes = [
  ('mobile', kMobile),
  ('tablet', kTablet),
  ('desktop', kDesktop),
];

const kThemes = [('light', true), ('dark', false)];

// ── Fake Results ──

final fakePlanetResults = [
  const PlanetResult(
    body: 0,
    bodyName: 'Sun',
    longitude: 4.583333,
    latitude: 0.0002,
    distance: 0.9967,
    speedLon: 0.9856,
    speedLat: 0.0001,
    speedDist: 0.0001,
    returnFlag: 2,
  ),
  const PlanetResult(
    body: 1,
    bodyName: 'Moon',
    longitude: 128.75,
    latitude: 5.15,
    distance: 0.00257,
    speedLon: 13.176,
    speedLat: -0.148,
    speedDist: 0.00003,
    returnFlag: 2,
  ),
  const PlanetResult(
    body: 2,
    bodyName: 'Mercury',
    longitude: 348.92,
    latitude: -1.83,
    distance: 1.234,
    speedLon: 1.45,
    speedLat: 0.12,
    speedDist: -0.003,
    returnFlag: 2,
  ),
  const PlanetResult(
    body: 3,
    bodyName: 'Venus',
    longitude: 52.64,
    latitude: 1.22,
    distance: 0.723,
    speedLon: 1.18,
    speedLat: -0.05,
    speedDist: 0.002,
    returnFlag: 2,
  ),
  const PlanetResult(
    body: 4,
    bodyName: 'Mars',
    longitude: 210.33,
    latitude: -0.78,
    distance: 1.882,
    speedLon: 0.524,
    speedLat: 0.01,
    speedDist: -0.005,
    returnFlag: 2,
  ),
];

const fakeHousesResult = HousesCalcResult(
  cusps: [
    0, // index 0 unused
    10.5, 42.3, 72.1, 100.8, 130.6, 160.2,
    190.5, 222.3, 252.1, 280.8, 310.6, 340.2,
  ],
  ascmc: [10.5, 280.8, 18.75, 192.3, 15.2, 0, 0, 0, 0, 0],
  hsys: 0x50, // P = Placidus
  hsysName: 'Placidus',
  returnFlag: 0,
);

final fakeAyanamsaResults = [
  const AyanamsaCalcResult(sidMode: 1, name: 'Lahiri', value: 24.179),
  const AyanamsaCalcResult(sidMode: 0, name: 'Fagan/Bradley', value: 24.736),
  const AyanamsaCalcResult(sidMode: 3, name: 'Raman', value: 22.375),
];

const fakeHeliacalResults = [
  HeliacalCalcResult(
    objectName: 'Venus',
    eventType: seHeliacalRising,
    startVisibleJd: 2451545.5,
    bestVisibleJd: 2451545.6,
    endVisibleJd: 2451545.7,
  ),
];

// ── Provider overrides ──

/// Startup bootstrap for widget tests: nothing staged, which is what a test
/// process that never ran `bootstrapEpheSource` actually has. Tests needing
/// the Swiss Ephemeris to look available pass their own override after this
/// one. It is not optional — `epheSeedProvider` throws when unset, so a
/// scope that forgets it fails loudly rather than quietly reporting no files.
///
/// Overrides the *seed*, not `epheBootstrapProvider`: the latter is now a
/// notifier that folds in progressive load events. On the VM the progressive
/// stream is empty, so the live state stays exactly this seed.
final epheBootstrapOverride = epheSeedProvider.overrideWithValue(
  const EpheBootstrap.none(),
);

final planetsResultsOverride = planetsResultsProvider.overrideWith(
  (ref) => CalcOk(fakePlanetResults),
);

final housesResultOverride = housesResultProvider.overrideWith(
  (ref) => const CalcOk(fakeHousesResult),
);

final ayanamsaResultsOverride = ayanamsaResultsProvider.overrideWith(
  (ref) => CalcOk(fakeAyanamsaResults),
);

final heliacalResultOverride = heliacalResultProvider.overrideWith(
  (ref) => const CalcOk(fakeHeliacalResults),
);

/// All overrides needed for tab-level tests.
final tabOverrides = [
  planetsResultsOverride,
  housesResultOverride,
  ayanamsaResultsOverride,
];

// ── The widgets under test ──

/// One pumpable case: a stable [name], the [widget], and the provider
/// [overrides] it needs to render populated rather than empty.
typedef WidgetCase = ({String name, Widget widget, List<Override> overrides});

/// Every screen-level surface in the app. The golden canaries take two of
/// these; the layout invariants sweep all of them.
final List<WidgetCase> allWidgetCases = [
  (name: 'app_shell', widget: const AppShell(), overrides: tabOverrides),
  (name: 'context_bar', widget: const ContextBar(), overrides: const []),
  (name: 'flag_bar', widget: const FlagBar(), overrides: const []),
  (name: 'result_card', widget: fakeResultCard(), overrides: const []),
  (
    name: 'ayanamsa_tab_list',
    widget: const AyanamsaTab(),
    overrides: [
      ...tabOverrides,
      ayanamsaCompareModeProvider.overrideWith((ref) => false),
    ],
  ),
  // The inline user-defined editors only render when the list is non-empty, so
  // an empty one left the row the mobile label clipping lived on (name, t0 and
  // value boxes side by side) out of the sweep entirely — swe-dashboard/96.
  (
    name: 'ayanamsa_tab_user_defined',
    widget: const AyanamsaTab(),
    overrides: [
      ...tabOverrides,
      ayanamsaCompareModeProvider.overrideWith((ref) => false),
      userAyanamsasProvider.overrideWith(
        (ref) => UserAyanamsaNotifier(
          initial: const [
            UserAyanamsa(id: 0, t0: 2451545.0, value: 23.85),
            UserAyanamsa(id: 1, name: 'Named entry', t0IsUt: true),
          ],
        ),
      ),
    ],
  ),
  (
    name: 'ayanamsa_tab_compare',
    widget: const AyanamsaTab(),
    overrides: [
      ...tabOverrides,
      ayanamsaCompareModeProvider.overrideWith((ref) => true),
    ],
  ),
  (
    name: 'coordinates_tab',
    widget: const CoordinatesTab(),
    overrides: tabOverrides,
  ),
  (
    name: 'crossings_tab',
    widget: const CrossingsTab(),
    overrides: tabOverrides,
  ),
  (name: 'dates_tab', widget: const DatesTab(), overrides: tabOverrides),
  (
    name: 'differential_tab',
    widget: const DifferentialTab(),
    overrides: tabOverrides,
  ),
  (
    name: 'heliacal_tab',
    widget: const HeliacalTab(),
    overrides: [...tabOverrides, heliacalResultOverride],
  ),
  (name: 'houses_tab', widget: const HousesTab(), overrides: tabOverrides),
  (
    name: 'jpl_horizons_tab',
    widget: const JplHorizonsTab(),
    overrides: tabOverrides,
  ),
  (name: 'math_tab', widget: const MathTab(), overrides: tabOverrides),
  (
    name: 'nodes_apsides_tab',
    widget: const NodesApsidesTab(),
    overrides: tabOverrides,
  ),
  (
    name: 'phenomena_tab',
    widget: const PhenomenaTab(),
    overrides: tabOverrides,
  ),
  (name: 'planets_tab', widget: const PlanetsTab(), overrides: tabOverrides),
  (name: 'rise_set_tab', widget: const RiseSetTab(), overrides: tabOverrides),
  (name: 'stars_tab', widget: const StarsTab(), overrides: tabOverrides),
];

// ── Pumping ──

/// Pump [widget] inside the app's MaterialApp at a given viewport, theme and
/// text scale.
///
/// [textScale] drives `MediaQuery.textScalerOf`, which is how the app's
/// browser-style zoom works — see the "Zoom & Responsive Scaling" section of
/// CLAUDE.md.
/// Set [hostInScrollView] to reproduce how `AppShell` hosts its children: its
/// `body` is a `SingleChildScrollView`, so the ContextBar, FlagBar and tab
/// content all get unbounded height and scroll. Pumping a tab into a
/// fixed-height Scaffold instead reports a bottom overflow for any tab taller
/// than the viewport, which is a fact about the harness and not about the app.
/// `AppShell` itself brings its own scroll view and must not be double-wrapped.
Future<void> pumpAppWidget(
  WidgetTester tester,
  Widget widget, {
  required Size size,
  required bool isLight,
  double textScale = 1.0,
  bool hostInScrollView = false,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        epheBootstrapOverride,
        ...overrides,
      ],
      child: MaterialApp(
        theme: isLight ? AppThemes.light : AppThemes.dark,
        // `MaterialApp` lerps theme changes over `kThemeAnimationDuration`.
        // Callers reuse one tester across variants and pump zero-duration
        // frames, so without this the theme freezes at the first pump's value.
        themeAnimationDuration: Duration.zero,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: hostInScrollView
              ? SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [widget],
                  ),
                )
              : widget,
        ),
      ),
    ),
  );
  await tester.pump();
}

// ── Convenience: build a ResultCard with fake fields ──

ResultCard fakeResultCard({
  String title = 'Sun',
  String subtitle = 'calcUt(0)',
  String flagHex = '0x2',
  DisplayFormat format = DisplayFormat.dms,
}) {
  return ResultCard(
    title: title,
    subtitle: subtitle,
    flagHex: flagHex,
    fields: const [
      ResultField(label: 'Longitude', value: "4° 35' 00.00\"", rawValue: 4.583),
      ResultField(label: 'Latitude', value: "0° 00' 00.72\"", rawValue: 0.0002),
      ResultField(label: 'Distance', value: '0.99670000 AU', rawValue: 0.9967),
      ResultField(
        label: 'Spd Lon',
        value: "0° 59' 08.16\"/day",
        rawValue: 0.9856,
      ),
      ResultField(
        label: 'Spd Lat',
        value: "0° 00' 00.36\"/day",
        rawValue: 0.0001,
      ),
      ResultField(
        label: 'Spd Dist',
        value: "0° 00' 00.36\"/day",
        rawValue: 0.0001,
      ),
    ],
  );
}
