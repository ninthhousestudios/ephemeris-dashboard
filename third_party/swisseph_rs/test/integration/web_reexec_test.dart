// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Regression test for swisseph-rs-dart/52.
//
// getEmscriptenFS() -- and therefore loadEpheFile() and the whole Swiss-file
// web path -- depends on a wrapper around the Emscripten factory that captures
// the module into globalThis.__swissephRsModule. The loader used to install
// that wrapper by assigning over globalThis.SwissEphRs once, after its own
// glue tag loaded. That assignment survives exactly until the glue executes
// again: the glue's top-level `var SwissEphRs = ...` re-assigns, and the
// wrapper is gone.
//
// Which happened routinely. wasm_ffi's isImported() dedup compares a script
// element's *resolved* .src against the string it was handed with endsWith, so
// any relative modulePath containing "../" fails to match, and wasm_ffi
// injects a second glue tag. A host page loading the glue itself does it too.
//
// The fix makes the capture an accessor on globalThis, so every assignment
// re-wraps it. This test asserts that directly: re-execute the glue, then
// check the factory is still on the wrapper's call path. Test one below is the
// negative control -- it fails against the assignment-based loader.
//
// The wrapper stays installed but stops *publishing* once initialization
// succeeds (__swissephRsArmed), so test two pins the other half: a factory
// call after init produces a second Emscripten module with its own heap, and
// must not be allowed to redirect __swissephRsModule at it -- that would leave
// MEMFS staging writing into a filesystem the bound engine never reads.
//
// Own file: initializeWasm() is single-flight per isolate, and this test
// deliberately dirties the global glue state.

int _captureCount() =>
    globalContext
        .getProperty<JSNumber?>('__swissephRsCaptures'.toJS)
        ?.toDartInt ??
    0;

String _glueSrc() {
  final scripts = web.document.querySelectorAll('script[src]');
  for (var i = 0; i < scripts.length; i++) {
    final src = (scripts.item(i)! as web.HTMLScriptElement).src;
    if (src.contains('swisseph_ffi')) return src;
  }
  fail('no glue script tag found');
}

Future<void> _reexecuteGlue() async {
  final script = web.HTMLScriptElement()
    ..type = 'text/javascript'
    ..src = _glueSrc()
    ..async = true;
  final loaded = Completer<void>();
  unawaited(
    script.onLoad.first.then((_) {
      if (!loaded.isCompleted) loaded.complete();
    }),
  );
  unawaited(
    script.onError.first.then((_) {
      if (!loaded.isCompleted) {
        loaded.completeError(StateError('glue re-execution failed to load'));
      }
    }),
  );
  web.document.head!.appendChild(script);
  await loaded.future.timeout(const Duration(seconds: 30));
}

void main() {
  setUpAll(() async {
    await initializeWasm('../../wasm/swisseph_ffi');
  });

  test('the wrapper survives the glue re-executing', () async {
    final captured = globalContext.getProperty<JSAny?>(
      '__swissephRsModule'.toJS,
    );
    expect(captured, isNotNull, reason: 'initializeWasm() must have captured');
    final before = _captureCount();

    await _reexecuteGlue();

    // Drive the factory the way wasm_ffi does. Every resolution the wrapper
    // sees bumps the liveness counter, so an increment proves the re-executed
    // glue's assignment went *through* the accessor rather than over it. With
    // the previous assignment-based install, the second glue execution left
    // the raw factory behind and this counter never moves -- on that loader it
    // does not even exist.
    final factory = globalContext.getProperty<JSFunction>('SwissEphRs'.toJS);
    await (factory.callAsFunction(null, JSObject())! as JSPromise<JSObject>)
        .toDart;

    expect(
      _captureCount(),
      greaterThan(before),
      reason:
          'the glue re-executed and un-wrapped the factory, so nothing '
          'captures the module and getEmscriptenFS() is dead',
    );
  });

  test('a factory call after initialization cannot redirect MEMFS', () async {
    // Calling the factory builds a *second* Emscripten module, with its own
    // heap. wasm_ffi is bound to the first one -- wasm.wasmLibrary,
    // Memory.global and every bound function address it -- so publishing the
    // second would point getEmscriptenFS() at a filesystem the engine never
    // reads. Staged .se1 files would vanish from the engine's view with
    // nothing to show for it. Hence __swissephRsArmed: the wrapper stays on
    // the call path, but stops publishing once initialization has claimed its
    // module.
    final claimed = globalContext.getProperty<JSObject>(
      '__swissephRsModule'.toJS,
    );
    final before = _captureCount();

    final factory = globalContext.getProperty<JSFunction>('SwissEphRs'.toJS);
    final rogue =
        await (factory.callAsFunction(null, JSObject())! as JSPromise<JSObject>)
            .toDart;

    expect(
      _captureCount(),
      greaterThan(before),
      reason: 'the wrapper must still have seen this resolution',
    );
    expect(
      rogue,
      isNot(same(claimed)),
      reason: 'the factory really did build a second, distinct module',
    );
    expect(
      globalContext.getProperty<JSObject>('__swissephRsModule'.toJS),
      same(claimed),
      reason:
          'a post-initialization factory call redirected the capture; MEMFS '
          'now writes into a heap the bound engine never reads',
    );
  });

  test('loadEpheFile still works after the glue re-executes', () {
    // The consequence the wrapper exists for, asserted end to end.
    loadEpheFile('reexec_probe.se1', Uint8List.fromList([1, 2, 3]));
  });
}
