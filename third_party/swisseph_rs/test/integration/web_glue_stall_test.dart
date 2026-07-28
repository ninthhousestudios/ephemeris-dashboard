// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:swisseph_rs/src/loader_timeouts.dart' as loader;
import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Covers the last of the loader's three stall paths: a glue <script> that
// fires neither load nor error, because the server accepted the request and
// then went silent.
//
// The other two paths (web_stall_test.dart) are staged with a served fixture
// whose Emscripten factory returns a pending promise. That cannot reach this
// one -- the factory does not exist yet when this timeout fires -- and no
// served file can, since a file that arrives fires load and a file that does
// not fires error. So this test stands up a service worker that accepts a
// marked URL and never responds.
//
// Lives in its own file so the worker's registration cannot bleed into the
// other web suites' loads.

const _stalledGlue = 'fixtures/__stall__glue';

void main() {
  setUpAll(() async {
    final container = web.window.navigator.serviceWorker;
    // Registered from this directory, not from fixtures/, on purpose. A
    // worker's default scope is the directory it is served from, and a worker
    // can only control pages *inside* its scope -- so one under fixtures/
    // would cover the stalled URL but not this page, leaving the page
    // uncontrolled and `ready` unresolved forever. Scoping it here covers
    // both. (Scoping it wider would need a Service-Worker-Allowed header,
    // which package:test's server cannot send.)
    await container.register('stall_sw.js'.toJS).toDart;
    await container.ready.toDart;

    // `ready` resolves when a worker is active, which is not the same as this
    // page being controlled by it. Until controller is set, fetches bypass the
    // worker and the stalled URL would simply 404 -- the test would fail for
    // the wrong reason, or worse, pass for one.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (container.controller == null) {
      if (DateTime.now().isAfter(deadline)) {
        fail(
          'service worker never took control of the page; the stall fixture '
          'is not in effect',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });

  tearDownAll(() async {
    final registration = await web.window.navigator.serviceWorker.ready.toDart;
    await registration.unregister().toDart;
  });

  setUp(() {
    loader.debugSetLoaderTimeouts(glueLoad: const Duration(milliseconds: 200));
  });
  tearDown(loader.debugResetLoaderTimeouts);

  test('a glue script that never loads or errors times out', () async {
    await expectLater(
      initializeWasm(_stalledGlue),
      throwsA(
        isA<TimeoutException>().having(
          (e) => e.message,
          'message',
          allOf(contains('__stall__glue.js'), contains('never completed')),
        ),
      ),
    );
  });

  test('a timed-out glue tag is dropped from the DOM', () {
    // The tag cannot be aborted -- a <script> load has no cancel -- so the
    // loader removes it instead. Leaving it would accumulate dead elements
    // across retries, and a stale tag also feeds wasm_ffi's isImported()
    // src-matching dedup, which would then skip injecting the real load.
    final scripts = web.document.querySelectorAll('script[src]');
    var stalled = 0;
    for (var i = 0; i < scripts.length; i++) {
      final src = (scripts.item(i)! as web.HTMLScriptElement).src;
      if (src.contains('__stall__')) stalled++;
    }
    expect(stalled, 0, reason: 'the abandoned glue tag should be removed');
  });

  test('the stalled attempt did not poison a later one', () async {
    // The stall path has to release the single-flight latch like every other
    // failure, otherwise one hung fetch is terminal for the isolate.
    loader.debugResetLoaderTimeouts();
    await initializeWasm('../../wasm/swisseph_ffi');

    final eph = Ephemeris(const EphemerisConfig());
    addTearDown(eph.close);
    final r = eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed);
    expect(r.longitude, closeTo(280.36891967534336, 1e-9));
  });
}
