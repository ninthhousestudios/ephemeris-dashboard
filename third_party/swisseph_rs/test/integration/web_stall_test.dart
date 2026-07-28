// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:swisseph_rs/src/loader_timeouts.dart' as loader;
import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

// Covers the loader's stall paths: the instantiation timeout, and the
// generation guard that makes that timeout safe.
//
// Neither was testable while abandoning an attempt required a real stalled
// server. It does not: the loader never observes the socket, it observes the
// Emscripten factory promise, so a served fixture whose factory returns a
// pending promise (fixtures/stalling_glue.js) reproduces the condition
// exactly. The one path still uncovered is the glue <script> timeout, which
// does need an endpoint that handshakes and then goes silent.
//
// This file must stand alone: initializeWasm() is single-flight per isolate
// and the first attempt here is required to fail.

@JS('eval')
external void _jsEval(String code);

const _stallingGlue = 'fixtures/stalling_glue';
const _realGlue = '../../wasm/swisseph_ffi';

void main() {
  setUp(() {
    // 200ms is arbitrary but not tight: the fixture's promise is pending
    // forever, so there is no race with a load that might have succeeded.
    loader.debugSetLoaderTimeouts(
      moduleInstantiate: const Duration(milliseconds: 200),
    );
  });
  tearDown(loader.debugResetLoaderTimeouts);

  test('a module that never finishes initializing times out', () async {
    await expectLater(
      initializeWasm(_stallingGlue),
      throwsA(
        isA<TimeoutException>().having(
          (e) => e.message,
          'message',
          allOf(contains(_stallingGlue), contains('never finished')),
        ),
      ),
    );
  });

  test('an abandoned attempt cannot publish before a later one exists', () async {
    // The narrow window the generation guard originally left open. Bumping the
    // stamp at the *start of the next attempt* only parks an orphan once a
    // successor exists; an orphan that resolves in between still matched its
    // own generation and published. Nothing about the "publish over a later
    // one" test below reaches this ordering -- it releases the fixture after a
    // retry has already bumped the stamp, which is the case that always
    // worked.
    await expectLater(
      initializeWasm(_stallingGlue),
      throwsA(isA<TimeoutException>()),
    );

    // No retry. The abandoned attempt resolves into a world where it is still
    // the most recent one to have run.
    _jsEval('globalThis.__stallRelease({ __isFake: true });');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      globalContext.has('__swissephRsModule'),
      isFalse,
      reason:
          'the abandoned attempt published its module with no successor to '
          'be parked behind',
    );
  });

  test('an abandoned attempt cannot publish over a later one', () async {
    // The failure this pins is not the hang -- it is what the fix for the hang
    // makes possible. `.timeout()` does not cancel, so the abandoned
    // DynamicLibrary.open stays parked on the factory promise. If that promise
    // ever resolved, the orphan would publish its own module, and further into
    // open(), its own Memory.global and WasmTable.global over the successful
    // attempt's -- half the pointer arithmetic against one heap and half
    // against another. Silent memory corruption, strictly worse than the hang.
    //
    // The guard is a generation stamp in the factory wrapper. Nothing about a
    // passing suite would notice its removal without this test.
    await expectLater(
      initializeWasm(_stallingGlue),
      throwsA(isA<TimeoutException>()),
    );
    expect(
      globalContext.has('__stallRelease'),
      isTrue,
      reason:
          'the abandoned attempt should be parked on a live promise, '
          'otherwise there is nothing to resolve late',
    );

    loader.debugResetLoaderTimeouts();
    await initializeWasm(_realGlue);
    final real = globalContext.getProperty('__swissephRsModule'.toJS)!;

    // Resolve the abandoned attempt now, after a later one has already won.
    _jsEval('globalThis.__stallRelease({ __isFake: true });');
    await Future<void>.delayed(Duration.zero);

    final current = globalContext.getProperty('__swissephRsModule'.toJS)!;
    expect(
      (current as JSObject).has('__isFake'),
      isFalse,
      reason: 'the orphaned attempt overwrote the live module',
    );
    expect(identical(current, real), isTrue);

    // And the winning module is still usable, which is the point of guarding.
    final eph = Ephemeris(const EphemerisConfig());
    addTearDown(eph.close);
    final r = eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed);
    expect(r.longitude, closeTo(280.36891967534336, 1e-9));
  });
}
