// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/swe_constants.dart';
import 'package:swe_dashboard/core/ephemeris/fake_ephemeris.dart';
import 'package:swe_dashboard/tabs/phenomena/phenomena_provider.dart';

PhenoResult _result(int body) => PhenoResult(
  phaseAngle: body * 10.0,
  phase: 0.5,
  elongation: body * 15.0,
  apparentDiameter: 0.01,
  apparentMagnitude: -1.0 + body,
);

void main() {
  group('computePhenomena', () {
    test('computes phenomena for multiple bodies via fake Ephemeris', () {
      final fake = FakeEphemeris()
        ..onPhenoUt = (jdUt, body, flags) => _result(body);

      final results = computePhenomena(
        eph: fake,
        jdUt: 2451545.0,
        iflag: 0,
        bodies: [seSun, seMoon, seMars],
        getName: (body) => 'Body $body',
      );

      expect(results, hasLength(3));
      expect(results[0].phaseAngle, seSun * 10.0);
      expect(results[1].elongation, seMoon * 15.0);
      expect(results[2].apparentMagnitude, -1.0 + seMars);
      expect(results[0].bodyName, 'Body $seSun');
    });

    test('per-body SweException produces NaN row without failing batch', () {
      final fake = FakeEphemeris()
        ..onPhenoUt = (jdUt, body, flags) {
          if (body == seMoon) {
            throw const InvalidArgException('no phenomena for Moon');
          }
          return _result(body);
        };

      final results = computePhenomena(
        eph: fake,
        jdUt: 2451545.0,
        iflag: 0,
        bodies: [seSun, seMoon, seMars],
        getName: (body) => 'Body $body',
      );

      expect(results, hasLength(3));
      expect(results[0].phaseAngle, isNot(isNaN));
      expect(results[1].phaseAngle, isNaN);
      expect(results[1].elongation, isNaN);
      expect(results[2].phaseAngle, isNot(isNaN));
    });

    test('empty body list returns empty results', () {
      final fake = FakeEphemeris()
        ..onPhenoUt = (jdUt, body, flags) => _result(body);

      final results = computePhenomena(
        eph: fake,
        jdUt: 2451545.0,
        iflag: 0,
        bodies: [],
        getName: (body) => 'Body $body',
      );

      expect(results, isEmpty);
    });
  });
}
