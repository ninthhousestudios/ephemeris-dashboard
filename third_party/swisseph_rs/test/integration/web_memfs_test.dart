// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:swisseph_rs/swisseph_rs.dart';
import 'package:test/test.dart';

// The web MEMFS path -- stage .se1 bytes, then read them back through the
// engine -- used to be covered only by a test that fetches a real ephemeris
// file from ephe/. That symlink points outside the served root, so the test
// skipped rather than failed, and a MEMFS path broken end to end (see
// swisseph-rs-dart/52: a duplicate glue tag stripping the factory wrapper)
// showed up in a green run as a skip.
//
// These assertions need no fixture, so they cannot skip. They do not check
// ephemeris *values* -- that is what the sepl_18.se1 test in web_test.dart is
// for -- they check that bytes written by loadEpheFile() are visible to the
// engine, which is the part the loader can silently break.
//
// This lives in its own file because it needs a browser context where nothing
// has been staged into /ephe yet: the "before" half of the differential is
// only meaningful on a virgin MEMFS.
void main() {
  setUpAll(() async {
    await initializeWasm('../../wasm/swisseph_ffi');
  });

  test('staged bytes are what the engine finds at /ephe', () {
    // Before staging, /ephe holds nothing the engine can use.
    expect(
      () => Ephemeris(
        const EphemerisConfig(
          ephemerisSource: EphemerisSource.swiss,
          ephePath: '/ephe',
        ),
      ),
      throwsA(isA<FileNotFoundException>()),
      reason: 'nothing is staged yet, so the engine must find no planet file',
    );

    // Deliberately not a valid .se1. The engine is expected to reject it --
    // the point is *which* way it fails: anything other than "file not found"
    // proves it opened and read the bytes MEMFS handed it.
    loadEpheFile('sepl_18.se1', Uint8List.fromList(List.filled(512, 0x5a)));

    expect(
      () => Ephemeris(
        const EphemerisConfig(
          ephemerisSource: EphemerisSource.swiss,
          ephePath: '/ephe',
        ),
      ),
      isNot(throwsA(isA<FileNotFoundException>())),
      reason:
          'the staged file exists in MEMFS, so a "not found" here means the '
          'engine is not seeing loadEpheFile() writes at all',
    );
  });
}
