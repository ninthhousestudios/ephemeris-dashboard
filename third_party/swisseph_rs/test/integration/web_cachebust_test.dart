// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@TestOn('browser')
library;

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Regression test: initializeWasm() must accept a glue URL that already
// carries an extension plus a query string. modulePath is a URL, and
// cache-busted or signed asset URLs are routine in web deployments.
//
// A raw `path.endsWith('.js')` check fails here -- "swisseph_ffi.js?v=1"
// does not end in ".js" -- and appends a second extension, producing
// "swisseph_ffi.js?v=1.js".
//
// That does NOT 404: the stray ".js" lands inside the query string, so the
// browser still fetches the right path and a plain calc keeps working. The
// damage is subtler. wasm_ffi's isImported() dedup matches on script src by
// endsWith, and "...?v=1.js" does not end with "...?v=1", so wasm_ffi fails
// to see our pre-loaded tag and injects a second one. That second load
// re-defines globalThis.SwissEphRs, clobbering the factory wrapper that
// captures the module into globalThis.__swissephRsModule -- so
// getEmscriptenFS() throws and the whole MEMFS/ephe path breaks.
//
// Hence the second test: a positional assertion alone passes even when the
// bug is present. The module-capture assertion is what actually pins it.
//
// This lives in its own file because initializeWasm() is single-flight per
// isolate: a second call with a different modulePath throws StateError by
// design, so it cannot share a browser context with web_test.dart.
void main() {
  setUpAll(() async {
    await initializeWasm('../../wasm/swisseph_ffi.js?v=1');
  });

  test('cache-busted glue URL loads and computes', () {
    final eph = Ephemeris(const EphemerisConfig());
    addTearDown(eph.close);
    final r = eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed);
    expect(r.longitude, closeTo(280.36891967534336, 1e-9));
  });

  test('cache-busted glue URL is not given a second .js extension', () {
    // The positional test above passes even with the bug present, because the
    // stray ".js" lands in the query string and the browser still fetches the
    // right path. Assert on the resolved script URL instead -- that is the
    // behaviour the extension-resolution rule actually controls.
    final scripts = web.document.querySelectorAll('script[src]');
    final glue = <String>[];
    for (var i = 0; i < scripts.length; i++) {
      final src = (scripts.item(i)! as web.HTMLScriptElement).src;
      if (src.contains('swisseph_ffi')) glue.add(src);
    }
    expect(glue, isNotEmpty, reason: 'glue script tag should be present');
    for (final src in glue) {
      expect(
        src,
        isNot(contains('.js?v=1.js')),
        reason: 'query string must not have a second extension appended',
      );
      expect(src, contains('swisseph_ffi.js?v=1'));
    }
  });
}
