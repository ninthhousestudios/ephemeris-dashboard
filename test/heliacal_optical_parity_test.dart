// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Parity of the Ephemeris seam's `heliacalUt` against `swetest -opt`
/// (swe-dashboard/80, A2).
///
/// `swe_heliacal_ut` reads the four optical-instrument arguments only when
/// SE_HELFLAG_OPTICAL_PARAMS (512) is set in helflag; without it they are
/// zeroed on entry, so the Magnification / Aperture / Transmission /
/// Monocular-Binocular inputs the tab collects are silently inert. The
/// telescope case below moves the heliacal rising by four days and stretches
/// visibility from 28 to 529 minutes, so it fails loudly if the flag is
/// dropped again.
///
/// Reference: swetest 2.10.03 over this repo's own `assets/ephe`:
///
/// ```
/// swetest -edir./assets/ephe -p3 -b1.1.2026 -ut0:00 -geopos13.4,52.5,0 \
///         -hev1 -at1013.25,25,50,0.2 -opt36,1,1,0,0,0      # naked eye
/// #   Venus heliacal rising : 2026/11/01 05:17:11.2 UT (2461345.72027),
/// #                           opt 05:27:43.2, end 05:44:58.2, dur 27.8 min
///
/// swetest ... -opt36,1,0,50,100,0.8                        # 50x/100mm scope
/// #   Venus heliacal rising : 2026/10/28 05:46:53.6 UT (2461341.74090),
/// #                           opt 10:08:23.6, end 14:35:29.6, dur 528.6 min
/// ```
///
/// swetest prints only the start JD; the optimum and end JDs below are that
/// day's 00:00 UT (2461345.5 / 2461341.5) plus the printed clock times.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:swisseph_rs/swisseph_rs.dart' as rs;
import 'package:swe_dashboard/core/ephemeris/rust_eph.dart';
import 'package:swe_dashboard/core/swe_constants.dart';

/// Hours-minutes-seconds of a UT day as a fraction of a day.
double _hms(int h, int m, double s) => (h + m / 60.0 + s / 3600.0) / 24.0;

void main() {
  late RustEph eph;

  setUp(() {
    eph = RustEph(
      const rs.EphemerisConfig(
        ephemerisSource: rs.EphemerisSource.swiss,
        ephePath: 'assets/ephe',
      ),
    );
  });

  tearDown(() => eph.close());

  // Berlin, searching from 2026-01-01 00:00 UT for Venus' heliacal rising.
  const geolon = 13.4;
  const geolat = 52.5;
  const jdStart = 2461041.5; // 2026-01-01 00:00 UT
  const atmo = AtmoConditions(
    pressure: 1013.25,
    temperature: 25.0,
    humidity: 50.0,
    extinction: 0.2,
  );

  HeliacalResult venusRising(ObserverConditions observer) => eph.heliacalUt(
    jdStart,
    geolon: geolon,
    geolat: geolat,
    geoalt: 0,
    atmo: atmo,
    observer: observer,
    objectName: 'Venus',
    typeEvent: seHeliacalRising,
    flags: seFlgSwiEph,
  );

  // swetest rounds the printed JD to 5 decimals — 0.86 s.
  const tol = 2e-5;

  test('naked eye matches swetest -opt36,1,1,0,0,0', () {
    final r = venusRising(
      const ObserverConditions(
        age: 36,
        snellenRatio: 1,
        monoNoBino: 1,
        telescopeMag: 0,
        telescopeDia: 0,
        transmission: 0,
      ),
    );
    const day = 2461345.5; // 2026-11-01
    expect(r.startVisible, closeTo(day + _hms(5, 17, 11.2), tol));
    expect(r.bestVisible, closeTo(day + _hms(5, 27, 43.2), tol));
    expect(r.endVisible, closeTo(day + _hms(5, 44, 58.2), tol));
  });

  test('a 50x/100mm telescope matches swetest -opt36,1,0,50,100,0.8', () {
    final r = venusRising(
      const ObserverConditions(
        age: 36,
        snellenRatio: 1,
        monoNoBino: 0, // monocular
        telescopeMag: 50,
        telescopeDia: 100,
        transmission: 0.8,
      ),
    );
    const day = 2461341.5; // 2026-10-28
    expect(
      r.startVisible,
      closeTo(day + _hms(5, 46, 53.6), tol),
      reason: 'the optical parameters never reached swe_heliacal_ut',
    );
    expect(r.bestVisible, closeTo(day + _hms(10, 8, 23.6), tol));
    expect(r.endVisible, closeTo(day + _hms(14, 35, 29.6), tol));
  });
}
