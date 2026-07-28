// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@TestOn('browser')
library;

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

// Regression test: a failed initializeWasm() must release the single-flight
// latch so the call can be retried.
//
// initializeWasm() stores its future in a library-global and hands the same
// future to every later caller. If a failed load left that future in place,
// one bad network moment would be terminal for the isolate: every subsequent
// call -- including a deliberate retry against a known-good URL -- would
// await the same dead future and re-throw the same error forever.
//
// Glue loads fail transiently for reasons that clear on their own (a stalled
// proxy, a cold CDN edge that times out once), which is why the TimeoutException
// path added alongside this exists at all. A timeout the caller cannot retry
// past would be a poor trade for the hang it replaces.
//
// The timeout path itself is not covered here: reproducing it needs an
// endpoint that completes the TCP handshake and then never responds, and a
// browser test has no way to stand one up. This covers the same latch release
// via the onError path, which is the half that is stageable (a 404).
//
// This lives in its own file because initializeWasm() is single-flight per
// isolate, and the first call here is required to fail.
void main() {
  test('a failed load does not poison later initializeWasm() calls', () async {
    await expectLater(
      initializeWasm('../../wasm/no-such-glue'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('no-such-glue.js'),
        ),
      ),
    );

    // The latch is released, so a retry runs a real load rather than replaying
    // the failure -- and is free to name a different path.
    await initializeWasm('../../wasm/swisseph_ffi');

    final eph = Ephemeris(const EphemerisConfig());
    addTearDown(eph.close);
    final r = eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed);
    expect(r.longitude, closeTo(280.36891967534336, 1e-9));
  });
}
