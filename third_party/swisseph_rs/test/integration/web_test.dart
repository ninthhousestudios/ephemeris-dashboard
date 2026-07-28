// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

extension type _Response(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
  external bool get ok;
}

@JS('fetch')
external JSPromise<_Response> _jsFetch(JSString url);

Future<Uint8List> _fetchBytes(String url) async {
  final response = await _jsFetch(url.toJS).toDart;
  if (!response.ok) throw StateError('Fetch failed: $url');
  final buffer = await response.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

void main() {
  setUpAll(() async {
    await initializeWasm('../../wasm/swisseph_ffi');
  });

  group('Moshier (no files)', () {
    late Ephemeris eph;

    setUp(() {
      eph = Ephemeris(const EphemerisConfig());
    });
    tearDown(() => eph.close());

    test('Sun at J2000 — positional agreement', () {
      final r = eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed);
      expect(r.longitude, closeTo(280.36891967534336, 1e-9));
      expect(r.longitudeSpeed, closeTo(1.0194320944233946, 1e-9));
      expect(r.distance, closeTo(0.9833276448202026, 1e-12));
    });

    test('Moon returns reasonable longitude', () {
      final r = eph.calcUt(const JdUt1(2451545.0), Body.moon, CalcFlags.speed);
      expect(r.longitude, greaterThanOrEqualTo(0));
      expect(r.longitude, lessThan(360));
      expect(r.longitudeSpeed, closeTo(13.0, 2.0));
    });

    test('houses Placidus', () {
      final r = eph.houses(
        const JdUt1(2451545.0),
        47.37,
        8.55,
        HouseSystem.placidus,
      );
      expect(r.cusps.length, 13);
      for (var i = 1; i < r.cusps.length; i++) {
        expect(r.cusps[i], greaterThanOrEqualTo(0));
        expect(r.cusps[i], lessThan(360));
      }
    });

    test('eclipse search', () {
      final r = eph.solEclipseWhenGlob(const JdUt1(2451545.0), CalcFlags.speed);
      expect(r.timeMaximum, greaterThan(2451545.0));
    });
  });

  group('lifecycle', () {
    test('constructs with Moshier', () {
      final eph = Ephemeris(const EphemerisConfig());
      eph.close();
    });

    test('close() is idempotent', () {
      final eph = Ephemeris(const EphemerisConfig());
      eph.close();
      eph.close();
    });

    test('use-after-close throws StateError', () {
      final eph = Ephemeris(const EphemerisConfig());
      eph.close();
      expect(
        () => eph.calcUt(const JdUt1(2451545.0), Body.sun, CalcFlags.speed),
        throwsStateError,
      );
    });
  });

  group('native-only surface', () {
    test('share() throws UnsupportedError', () {
      final eph = Ephemeris(const EphemerisConfig());
      addTearDown(eph.close);
      expect(() => eph.share(), throwsUnsupportedError);
    });
  });

  group('Swiss-file path (MEMFS)', () {
    test('missing staged file throws FileNotFoundException', () {
      expect(
        () => Ephemeris(
          const EphemerisConfig(
            ephemerisSource: EphemerisSource.swiss,
            ephePath: '/nonexistent',
          ),
        ),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    // Positional agreement class (1e-9 deg), same as the native Swiss-file
    // golden in ephemeris_test.dart — the web leg is held to the numbers, not
    // merely to "returned something Sun-shaped".
    //
    // These three values are bit-identical across the C Swiss Ephemeris
    // oracle, the native Dart binding, and this web build. That is the claim
    // worth pinning: MEMFS staging feeds the engine the same bytes a native
    // ephePath does, so the web seam introduces no numerical drift at all.
    //
    // Data-dependent golden — recorded against the SE3 / DE441 release pinned
    // by ephemeris_release_test.dart. If ephe/ is upgraded, re-record from the
    // oracle; do not loosen the tolerance
    // (docs/ephemeris-data-releases.md).
    //
    // Both files are required: a geocentric Sun resolves the Earth from the
    // planetary file and the Earth-Moon barycentre correction from the lunar
    // one. Staging only sepl_18.se1 fails with "no planet or moon ephemeris
    // files found".
    test('loadEpheFile → construct → calc', () async {
      for (final name in ['sepl_18.se1', 'semo_18.se1']) {
        final Uint8List bytes;
        try {
          bytes = await _fetchBytes('../../ephe/$name');
        } on StateError {
          // Deliberately not a skip. This is the only web-side Swiss-file
          // coverage there is; when it was gated behind markTestSkipped the
          // suite reported "All tests passed" while never once exercising the
          // MEMFS path (swisseph-rs-dart/57). An unpopulated ephe/ is a setup
          // fault and should say so.
          fail(
            'ephe/$name is not being served by the test server.\n'
            'ephe/ must be a real directory inside the package root — a '
            'symlink is not followed and every fetch 404s. See '
            '"Populating ephe/" in docs/ephemeris-data-releases.md.',
          );
        }
        loadEpheFile(name, bytes);
      }

      final eph = Ephemeris(
        const EphemerisConfig(
          ephemerisSource: EphemerisSource.swiss,
          ephePath: '/ephe',
        ),
      );
      addTearDown(eph.close);
      final r = eph.calcUt(
        const JdUt1(2451545.0),
        Body.sun,
        CalcFlags.speed | CalcFlags.swiEph,
      );
      expect(r.longitude, closeTo(280.3689186698997, 1e-9));
      expect(r.longitudeSpeed, closeTo(1.0194341629435535, 1e-9));
      expect(r.distance, closeTo(0.9833276253625055, 1e-9));
    });

    test('the Emscripten module is captured, with one glue tag', () {
      // Regression test: wasm_ffi's isImported() dedup matches a script
      // element's *resolved* .src against the string it is handed, with
      // endsWith. Hand it a relative path -- as this file's modulePath is --
      // and the match fails, so it injects its own glue tag and the module is
      // instantiated twice.
      //
      // That is no longer fatal: the capture is an accessor on globalThis, so
      // a re-executing glue re-arms it rather than stripping it off (see
      // web_reexec_test.dart). It is still waste worth pinning, and the
      // capture assertion beside it is free -- any staging call at all proves
      // the module was captured.
      loadEpheFile('capture_probe.se1', Uint8List.fromList([1, 2, 3]));

      final scripts = web.document.querySelectorAll('script[src]');
      var glueTags = 0;
      for (var i = 0; i < scripts.length; i++) {
        final src = (scripts.item(i)! as web.HTMLScriptElement).src;
        if (src.contains('swisseph_ffi')) glueTags++;
      }
      expect(
        glueTags,
        1,
        reason:
            'a second glue tag re-executes the glue and un-wraps the '
            'factory, even though the module still loads',
      );
    });

    test('loadEpheFile rejects path traversal', () {
      expect(
        () => loadEpheFile('../etc/passwd', Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => loadEpheFile('foo/bar.se1', Uint8List(0)),
        throwsArgumentError,
      );
      expect(() => loadEpheFile('..', Uint8List(0)), throwsArgumentError);
      expect(() => loadEpheFile('', Uint8List(0)), throwsArgumentError);
    });
  });
}
