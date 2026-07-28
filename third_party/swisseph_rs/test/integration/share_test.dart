// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:isolate';

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

/// Isolate entry point — materializes a shared handle, computes, closes.
Future<List<double>> _workerCalc(int token) async {
  final eph = Ephemeris.fromShareToken(token);
  final r = eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed);
  eph.close();
  return [r.longitude, r.longitudeSpeed, r.distance];
}

void main() {
  group('Ephemeris.share()', () {
    test('worker calcs while constructing isolate closes first', () async {
      final eph = Ephemeris(const EphemerisConfig());
      final baseline = eph.calcUt(
        const JdUt1(2451545.0),
        Body.sun,
        CalcFlags.speed,
      );
      final token = eph.share();

      // Close original before worker materializes — any-close-order proven.
      eph.close();

      final result = await Isolate.run(() => _workerCalc(token));
      expect(result[0], baseline.longitude);
      expect(result[1], baseline.longitudeSpeed);
      expect(result[2], baseline.distance);
    });

    test('worker calcs then constructing isolate closes last', () async {
      final eph = Ephemeris(const EphemerisConfig());
      addTearDown(eph.close);
      final baseline = eph.calcUt(
        const JdUt1(2451545.0),
        Body.sun,
        CalcFlags.speed,
      );
      final token = eph.share();

      // Worker closes first, original still usable.
      final result = await Isolate.run(() => _workerCalc(token));
      expect(result[0], baseline.longitude);

      // Original still works after worker closed its handle.
      final afterResult = eph.calcUt(
        const JdUt1(2451545.0),
        Body.sun,
        CalcFlags.speed,
      );
      expect(afterResult.longitude, baseline.longitude);
    });

    test(
      'N share/close cycles: refcount stable, last close releases',
      () async {
        final eph = Ephemeris(const EphemerisConfig());
        const n = 100;

        for (var i = 0; i < n; i++) {
          final token = eph.share();
          final shared = Ephemeris.fromShareToken(token);
          final r = shared.calcUt(
            const JdUt1(2451545.0),
            Body.sun,
            CalcFlags.speed,
          );
          expect(r.longitude, closeTo(280.36, 0.01));
          shared.close();
        }

        // Original still works after 100 share/close cycles.
        final r = eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed);
        expect(r.longitude, closeTo(280.36, 0.01));
        eph.close();
      },
    );

    test('dropped unclosed share does not invalidate siblings', () async {
      final eph = Ephemeris(const EphemerisConfig());
      addTearDown(eph.close);

      // Create a shared handle and let it go out of scope without close().
      // NativeFinalizer will reclaim it eventually; the original must survive.
      void leakShare() {
        final token = eph.share();
        // ignore: unused_local_variable
        final leaked = Ephemeris.fromShareToken(token);
        // No close() — NativeFinalizer backstop will handle it.
      }

      leakShare();

      // Original still works — the leaked share's finalizer hasn't
      // invalidated the engine (Arc refcount protects it).
      final r = eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed);
      expect(r.longitude, closeTo(280.36, 0.01));
    });

    test('use-after-close on shared handle throws StateError', () {
      final eph = Ephemeris(const EphemerisConfig());
      addTearDown(eph.close);
      final token = eph.share();
      final shared = Ephemeris.fromShareToken(token);
      shared.close();
      expect(
        () => shared.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed),
        throwsStateError,
      );
    });
  });
}
