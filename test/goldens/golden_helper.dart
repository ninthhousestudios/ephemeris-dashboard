import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:swe_dashboard/core/calc_session.dart';
import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
import 'package:swe_dashboard/core/display_format.dart';
import 'package:swe_dashboard/core/persistence.dart';
import 'package:swe_dashboard/tabs/ayanamsa/ayanamsa_provider.dart';
import 'package:swe_dashboard/tabs/houses/houses_provider.dart';
import 'package:swe_dashboard/tabs/planets/planets_provider.dart';
import 'package:swe_dashboard/theme/app_themes.dart';
import 'package:swe_dashboard/widgets/result_card.dart';

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    return result.passed || result.diffPercent <= 1.0;
  }
}

void setupTolerantComparator() {
  final testUrl = (goldenFileComparator as LocalFileComparator).basedir;
  goldenFileComparator = _TolerantComparator(testUrl);
}

// ── Size constants ──

const Size kMobile = Size(400, 800);
const Size kTablet = Size(800, 1024);
const Size kDesktop = Size(1400, 900);

const _sizes = [
  ('mobile', kMobile),
  ('tablet', kTablet),
  ('desktop', kDesktop),
];

const _themes = [('light', true), ('dark', false)];

// ── Fake data ──

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

final fakeHousesResult = HousesCalcResult(
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

// ── Provider overrides ──

final calcSessionOverride = calcSessionProvider.overrideWith((ref) {
  final notifier = CalcSessionNotifier();
  notifier.calculate(
    activate: {
      'planets',
      'houses',
      'ayanamsa',
      'stars',
      'dates',
      'riseSet',
      'eclipses',
      'heliacal',
      'crossings',
      'coordinates',
      'phenomena',
      'nodesApsides',
      'differential',
      'planetocentric',
      'tableView',
      'math',
    },
  );
  return notifier;
});

final planetsResultsOverride = planetsResultsProvider.overrideWith(
  (ref) => CalcOk(fakePlanetResults),
);

final housesResultOverride = housesResultProvider.overrideWith(
  (ref) => CalcOk(fakeHousesResult),
);

final ayanamsaResultsOverride = ayanamsaResultsProvider.overrideWith(
  (ref) => fakeAyanamsaResults,
);

/// All overrides needed for tab-level tests.
final tabOverrides = [
  calcSessionOverride,
  planetsResultsOverride,
  housesResultOverride,
  ayanamsaResultsOverride,
];

// ── Pumping helpers ──

/// Pump a widget in a test harness with the given size and theme.
Future<void> pumpGoldenWidget(
  WidgetTester tester,
  Widget widget, {
  required Size size,
  required bool isLight,
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
      overrides: [sharedPrefsProvider.overrideWithValue(prefs), ...overrides],
      child: MaterialApp(
        theme: isLight ? AppThemes.light : AppThemes.dark,
        home: Scaffold(body: widget),
      ),
    ),
  );
  await tester.pump();
}

/// Generate all 6 goldens (3 sizes x 2 themes) for a widget.
///
/// Set [allowOverflow] to true for desktop-first widgets that overflow
/// at mobile widths. The goldens still capture the visual state.
Future<void> generateGoldens(
  WidgetTester tester,
  String widgetName,
  Widget widget, {
  List<Override> overrides = const [],
  bool allowOverflow = false,
}) async {
  setupTolerantComparator();
  final originalOnError = FlutterError.onError;
  if (allowOverflow) {
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) {
        originalOnError?.call(details);
      }
    };
  }
  addTearDown(() => FlutterError.onError = originalOnError);

  for (final (sizeName, size) in _sizes) {
    for (final (themeName, isLight) in _themes) {
      await pumpGoldenWidget(
        tester,
        widget,
        size: size,
        isLight: isLight,
        overrides: overrides,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('${widgetName}_${sizeName}_$themeName.png'),
      );
    }
  }
}

// ── Convenience: build a ResultCard with fake fields ──

ResultCard fakeResultCard({
  String title = 'Sun',
  String subtitle = 'calcUt(0)',
  String flagHex = '0x2',
  DisplayFormat format = DisplayFormat.dms,
  bool showActions = false,
}) {
  return ResultCard(
    title: title,
    subtitle: subtitle,
    flagHex: flagHex,
    onCode: showActions ? () {} : null,
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
