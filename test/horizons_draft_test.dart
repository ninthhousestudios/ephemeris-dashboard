// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/context_state.dart';
import 'package:swe_dashboard/core/horizons/horizons_request.dart';
import 'package:swe_dashboard/tabs/jpl_horizons/horizons_draft.dart';

ContextBarState _ctx({
  Origin origin = Origin.geocentric,
  double jdUt = 2461273.259193912,
  double longitude = -86.0236,
  double latitude = 40.046,
  double altitude = 0,
}) => ContextBarState(
  utcOffset: 0,
  jdUt: jdUt,
  origin: origin,
  longitude: longitude,
  latitude: latitude,
  altitude: altitude,
);

void main() {
  group('loadedFrom', () {
    test('mirrors a geocentric Context (does not force topocentric)', () {
      final d = const HorizonsDraft().loadedFrom(_ctx());
      expect(d.centerMode, CenterMode.geocentric);
      expect(d.build().center, isA<CoordinateCenter>());
      expect((d.build().center as CoordinateCenter).center, '500@399');
    });

    test('maps a topocentric Context to a site with the Context coords', () {
      final d = const HorizonsDraft().loadedFrom(
        _ctx(origin: Origin.topocentric, altitude: 250),
      );
      expect(d.centerMode, CenterMode.topocentric);
      final center = d.build().center;
      expect(center, isA<TopocentricCenter>());
      expect((center as TopocentricCenter).bodyId, '399');
      // East-longitude, latitude, altitude in km.
      expect(center.siteCoord, '-86.0236,40.046,0.25');
    });

    test('maps heliocentric and barycentric origins', () {
      expect(
        const HorizonsDraft()
            .loadedFrom(_ctx(origin: Origin.heliocentric))
            .centerMode,
        CenterMode.heliocentric,
      );
      expect(
        const HorizonsDraft()
            .loadedFrom(_ctx(origin: Origin.barycentric))
            .centerMode,
        CenterMode.ssb,
      );
    });

    test('emits a bare JD epoch with TLIST_TYPE=JD (no JD prefix)', () {
      final params = const HorizonsDraft()
          .loadedFrom(_ctx())
          .build()
          .toQueryParameters();
      expect(params['TLIST'], "'2461273.259193912'");
      expect(params['TLIST_TYPE'], "'JD'");
    });
  });
}
