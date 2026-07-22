// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Parity of the Planets series against `swetest`.
///
/// The expected values are swetest 2.10.03 output over this repo's own
/// `assets/ephe`, captured with:
///
/// ```
/// swetest -edir./assets/ephe -p0123456789 -b1.1.2026 -ut0:00 -n3 -s1 -fPlbRs -head
/// swetest -edir./assets/ephe -p0          -b30.12.2025 -ut0:00 -n3 -s1 -fTJlbRs -head
/// swetest -edir./assets/ephe -p0          -b15.1.2026  -ut0:00 -n4 -s1mo -fTJl   -head
/// ```
///
/// Reading that same directory, `swisseph_rs` reproduces swetest 2.10.03 to
/// swetest's printed precision, so the tolerances below are just the reference
/// values' rounding (yojana swe-dashboard/62).
///
/// The `.se1` set matters: `assets/ephe`, an Astrodienst DE431 build and a
/// local DE441 rebuild disagree with each other by up to ~5e-5° (Uranus). The
/// expected values above must be recaptured against whichever directory this
/// test configures.
///
/// On top of parity, this file pins that the series lands on the right Moments
/// and reproduces the tab's own calculation at each of them — see
/// "every step equals the single-Moment calculation", which is exact.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;
import 'package:swe_dashboard/core/calculation/calc_outcome.dart';
import 'package:swe_dashboard/core/calculation/moment.dart';
import 'package:swe_dashboard/core/calculation/run_tab_calc.dart';
import 'package:swe_dashboard/core/calculation/series_settings.dart';
import 'package:swe_dashboard/core/calculation/series_spec.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/ephemeris/rust_eph.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/tabs/planets/planets_provider.dart';

/// 1 Jan 2026, 00:00 UT.
const double _jd20260101 = 2461041.5;

/// Slack against the captured swetest output. Reading the same `assets/ephe`,
/// `swisseph_rs` and swetest 2.10.03 agree to swetest's printed precision, so
/// these are just the reference values' own rounding (7 dp on degrees, 9 dp on
/// AU) with a little headroom.
const double _degTol = 1e-6;
const double _auTol = 1e-8;

/// Sun … Pluto, in swetest's `-p0123456789` order.
const _bodies = [
  seSun,
  seMoon,
  seMercury,
  seVenus,
  seMars,
  seJupiter,
  seSaturn,
  seUranus,
  seNeptune,
  sePluto,
];

/// (longitude, latitude, distance AU, longitude speed) per body, per step.
const _swetestDaily = <List<List<double>>>[
  [
    [280.5685873, 0.0001816, 0.983326664, 1.0188682],
    [66.7155968, 5.0491024, 0.002413438, 14.9877459],
    [268.6516198, -0.5700608, 1.377558982, 1.5254229],
    [279.2064826, -0.5050742, 1.709952073, 1.2583174],
    [282.6881580, -0.8911136, 2.410698769, 0.7663630],
    [111.3576110, 0.2391386, 4.242665866, -0.1305568],
    [356.1672462, -2.2587402, 9.715234674, 0.0583277],
    [57.9493055, -0.1975963, 18.755292997, -0.0274411],
    [359.5067907, -1.3323963, 30.057955273, 0.0124421],
    [302.7187503, -3.7707677, 36.327959664, 0.0301389],
  ],
  [
    [281.5874519, 0.0001786, 0.983311924, 1.0188602],
    [81.7533909, 4.9720112, 0.002408909, 15.0612532],
    [270.1799947, -0.6788648, 1.384847088, 1.5313295],
    [280.4647721, -0.5422420, 1.710209221, 1.2582644],
    [283.4548556, -0.8973298, 2.409903787, 0.7670312],
    [111.2266191, 0.2415794, 4.240197981, -0.1314132],
    [356.2263503, -2.2554801, 9.731251277, 0.0598757],
    [57.9222047, -0.1973171, 18.766951570, -0.0267604],
    [359.5195167, -1.3317628, 30.074949226, 0.0130070],
    [302.7489796, -3.7714403, 36.335042692, 0.0303158],
  ],
  [
    [282.6063080, 0.0001660, 0.983303780, 1.0188518],
    [96.7826248, 4.5524198, 0.002415679, 14.9693607],
    [271.7142768, -0.7848495, 1.391583153, 1.5372447],
    [281.7230071, -0.5790037, 1.710428532, 1.2582086],
    [284.2222158, -0.9034703, 2.409091274, 0.7676880],
    [111.0948117, 0.2440025, 4.238041638, -0.1321880],
    [356.2869889, -2.2522479, 9.747194109, 0.0613971],
    [57.8957840, -0.1970364, 18.778833096, -0.0260812],
    [359.5327999, -1.3311331, 30.091880167, 0.0135569],
    [302.7793763, -3.7721412, 36.341852224, 0.0304742],
  ],
];

/// Sun, 30.12.2025 → 01.01.2026 — the backward series read in reverse.
const _swetestSunBackward = <List<double>>[
  [280.5685873, 0.0001816, 0.983326664, 1.0188682], // 01.01.2026, step 0
  [279.5497148, 0.0001749, 0.983347815, 1.0188761], // 31.12.2025, step -1
  [278.5308338, 0.0001593, 0.983375107, 1.0188851], // 30.12.2025, step -2
];

/// Sun longitude at monthly steps from 15.1.2026, with the step's JD.
const _swetestSunMonthly = <(double, double)>[
  (2461055.5, 294.8329123),
  (2461086.5, 326.3027686),
  (2461114.5, 354.4098062),
  (2461145.5, 25.0406818),
];

void main() {
  late RustEph eph;

  setUp(() {
    eph = RustEph(
      const rs.EphemerisConfig(
        // `EphemerisConfig` defaults to Moshier; without this the engine
        // silently ignores `assets/ephe` and the SEFLG_SWIEPH request below.
        ephemerisSource: rs.EphemerisSource.swiss,
        ephePath: 'assets/ephe',
      ),
    );
  });

  tearDown(() {
    eph.close();
  });

  /// The series exactly as the Planets tab computes it, minus Riverpod:
  /// `computeSeries` over the tab's own `computePlanets`.
  List<(Moment, CalcOutcome<List<PlanetResult>>)> series({
    double startUt = _jd20260101,
    double stepValue = 1,
    StepUnit stepUnit = StepUnit.days,
    int rowCount = 3,
    List<int> bodies = _bodies,
  }) {
    final settings = SeriesSettings(
      enabled: true,
      stepValue: stepValue,
      stepUnit: stepUnit,
      rowCount: rowCount,
    );
    return computeSeries(
      eph,
      settings.specFrom(Moment.fromUt(startUt, eph)),
      (e, moment) => computePlanets(
        eph: e,
        moment: moment,
        // swetest's default: Swiss Ephemeris files, geocentric, tropical.
        // `computePlanets` adds SEFLG_SPEED itself.
        iflag: seFlgSwiEph,
        origin: Origin.geocentric,
        bodies: bodies,
        getName: (body) => 'Body $body',
      ),
    );
  }

  List<PlanetResult> ok((Moment, CalcOutcome<List<PlanetResult>>) step) =>
      switch (step.$2) {
        CalcOk(value: final v) => v,
        CalcError(message: final m) => fail('step failed: $m'),
      };

  test('daily series matches swetest -p0123456789 -n3 -s1', () {
    final steps = series();
    expect(steps, hasLength(3));

    for (var i = 0; i < steps.length; i++) {
      expect(steps[i].$1.ut, closeTo(_jd20260101 + i, 1e-9), reason: 'step $i');
      final results = ok(steps[i]);
      expect(results, hasLength(_bodies.length));

      for (var b = 0; b < _bodies.length; b++) {
        final expected = _swetestDaily[i][b];
        final r = results[b];
        final where = 'step $i body ${_bodies[b]}';
        expect(r.errorMessage, isNull, reason: where);
        expect(
          r.longitude,
          closeTo(expected[0], _degTol),
          reason: '$where lon',
        );
        expect(r.latitude, closeTo(expected[1], _degTol), reason: '$where lat');
        expect(r.distance, closeTo(expected[2], _auTol), reason: '$where dist');
        expect(
          r.speedLon,
          closeTo(expected[3], _degTol),
          reason: '$where speed',
        );
      }
    }
  });

  test('every step equals the single-Moment calculation at that Moment', () {
    // Exact, not close: series mode is the tab's own calculation repeated, so
    // a step must be bit-identical to what the tab shows with the Context set
    // to that Moment. This is the assertion the loose swetest tolerances
    // above cannot make.
    final steps = series(rowCount: 30);
    expect(steps, hasLength(30));

    for (var i = 0; i < steps.length; i++) {
      final direct = ok(series(startUt: _jd20260101 + i, rowCount: 1).single);
      final stepped = ok(steps[i]);
      for (var b = 0; b < _bodies.length; b++) {
        final where = 'step $i body ${_bodies[b]}';
        expect(stepped[b].longitude, direct[b].longitude, reason: '$where lon');
        expect(stepped[b].latitude, direct[b].latitude, reason: '$where lat');
        expect(stepped[b].distance, direct[b].distance, reason: '$where dist');
        expect(stepped[b].speedLon, direct[b].speedLon, reason: '$where speed');
      }
    }
  });

  test('backward series steps back through the calendar', () {
    final steps = series(stepValue: -1, bodies: const [seSun]);

    for (var i = 0; i < steps.length; i++) {
      expect(steps[i].$1.ut, closeTo(_jd20260101 - i, 1e-9), reason: 'step $i');
      final sun = ok(steps[i]).single;
      final expected = _swetestSunBackward[i];
      expect(
        sun.longitude,
        closeTo(expected[0], _degTol),
        reason: 'step $i lon',
      );
      expect(
        sun.latitude,
        closeTo(expected[1], _degTol),
        reason: 'step $i lat',
      );
      expect(
        sun.distance,
        closeTo(expected[2], _auTol),
        reason: 'step $i dist',
      );
      expect(
        sun.speedLon,
        closeTo(expected[3], _degTol),
        reason: 'step $i speed',
      );
    }
  });

  test('monthly series lands on the calendar date, not a 30.44-day drift', () {
    final steps = series(
      startUt: 2461055.5, // 15.1.2026 00:00 UT
      stepUnit: StepUnit.months,
      rowCount: 4,
      bodies: const [seSun],
    );

    for (var i = 0; i < steps.length; i++) {
      final (expectedJd, expectedLon) = _swetestSunMonthly[i];
      expect(steps[i].$1.ut, closeTo(expectedJd, 1e-9), reason: 'step $i JD');
      expect(
        ok(steps[i]).single.longitude,
        closeTo(expectedLon, _degTol),
        reason: 'step $i lon',
      );
    }
  });
}
