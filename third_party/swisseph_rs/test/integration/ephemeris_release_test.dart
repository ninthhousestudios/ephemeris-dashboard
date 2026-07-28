// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Pins the ephemeris data release that this suite's Swiss-file goldens were
/// recorded against.
///
/// `ephe/` is a symlink to an untracked directory, so the data release is
/// invisible to git: refreshing it silently invalidates every golden taken
/// from a `.se1` file. That is not hypothetical — the 2026-07-19 DE431 ->
/// DE441 upgrade moved the J2000 Sun longitude by ~2.9e-8 deg, 28x the 1e-9
/// positional agreement class, and surfaced only as an unexplained numeric
/// drift in a single test (swisseph-rs-dart/50).
///
/// This test converts that into a legible failure: it reads the release
/// provenance out of the data files themselves and compares it against the
/// release recorded below. A data swap then fails here, naming the file and
/// both release strings, instead of as a bare tolerance failure somewhere
/// downstream.
///
/// The inventory of which goldens depend on which file lives in
/// `docs/ephemeris-data-releases.md`. Updating the pin below is a deliberate
/// act: it means re-recording those goldens against the new release.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

/// Header line 1 of a `.se1` file: the Swiss Ephemeris file format version.
const _pinnedFileFormat = 'SWISSEPH  3';

/// Header line 3 of a `.se1` file: the Astrodienst build and its JPL source.
const _pinnedRelease =
    'Created for Astrodienst in Switzerland 2026/05/26, '
    'based on JPL Ephemeris DE441.';

/// `.se1` files this suite's Swiss-file goldens are computed from, each with
/// the reason it is pinned. All Swiss-file goldens query JD 2451545.0
/// (J2000.0), which lands in the 1800–2400 AD segment — the `_18` files.
const _pinnedSe1Files = <String, String>{
  'sepl_18.se1':
      'planetary file — the J2000 Sun goldens in ephemeris_test.dart and '
      'web_test.dart resolve the Earth from here',
  'semo_18.se1':
      'lunar file — a geocentric Sun needs the Earth-Moon barycentre '
      'correction from here',
  'seas_18.se1':
      'asteroid file — no golden depends on it today, but it ships as part '
      'of the same Astrodienst release, so pinning it catches a partial '
      'refresh of ephe/',
};

/// `sefstars.txt` carries no version line, so it is pinned by content digest.
/// Consumed by the fixed-star tests in fixstar_config_test.dart.
const _pinnedFixedStarDigest =
    '1f5cddffe9f9eec6a8802bef2714fefb650b9d714726283ce6fc1a319fe59bed';

/// Reads the three `\r\n`-terminated ASCII header lines that open a `.se1`
/// file: format version, file name, release provenance.
List<String> _readSe1Header(File file) {
  // 512 bytes comfortably spans the header; the binary payload follows.
  final raw = file.openSync().readSync(512);
  final text = ascii.decode(raw, allowInvalid: true);
  final lines = text.split('\r\n');
  if (lines.length < 3) {
    fail('${file.path}: not a Swiss Ephemeris data file (no \\r\\n header)');
  }
  return [lines[0].trim(), lines[1].trim(), lines[2].trim()];
}

void main() {
  final ephePath = Platform.environment['SWE_EPHE_PATH'];

  group(
    'ephemeris data release pin',
    () {
      for (final entry in _pinnedSe1Files.entries) {
        final name = entry.key;
        final reason = entry.value;

        test('$name is the pinned release', () {
          final file = File('$ephePath/$name');
          if (!file.existsSync()) {
            fail(
              'ephemeris data file missing: $ephePath/$name\n'
              'Pinned because: $reason\n'
              'SWE_EPHE_PATH points at an incomplete ephemeris directory.',
            );
          }

          final header = _readSe1Header(file);

          expect(
            header[0],
            _pinnedFileFormat,
            reason:
                'ephemeris FILE FORMAT changed for $name.\n'
                '  pinned:  $_pinnedFileFormat\n'
                '  on disk: ${header[0]}\n'
                'This is a Swiss Ephemeris format change, not just a data '
                'refresh — expect more than numeric drift.',
          );

          expect(
            header[1],
            name,
            reason:
                '$name reports itself as "${header[1]}" — the file at this '
                'path is not the file it claims to be.',
          );

          expect(
            header[2],
            _pinnedRelease,
            reason:
                'EPHEMERIS DATA RELEASE CHANGED for $name.\n'
                '  pinned:  $_pinnedRelease\n'
                '  on disk: ${header[2]}\n'
                'Pinned because: $reason\n'
                'The Swiss-file goldens in this suite were recorded against '
                'the pinned release. A different JPL ephemeris moves '
                'positions by more than the 1e-9 deg positional agreement '
                'class, so downstream tolerance failures are expected and '
                'are NOT a binding regression. Re-record the goldens listed '
                'in docs/ephemeris-data-releases.md against the new release, '
                'then update _pinnedRelease in this file.',
          );
        });
      }

      test('sefstars.txt is the pinned catalogue', () {
        final file = File('$ephePath/sefstars.txt');
        if (!file.existsSync()) {
          fail(
            'fixed star catalogue missing: $ephePath/sefstars.txt\n'
            'SWE_EPHE_PATH points at an incomplete ephemeris directory.',
          );
        }

        final digest = sha256.convert(file.readAsBytesSync()).toString();

        expect(
          digest,
          _pinnedFixedStarDigest,
          reason:
              'FIXED STAR CATALOGUE CHANGED (sefstars.txt).\n'
              '  pinned:  $_pinnedFixedStarDigest\n'
              '  on disk: $digest\n'
              'sefstars.txt carries no version line, so it is pinned by '
              'content digest. Star positions, magnitudes, or catalogue '
              'membership have changed; the fixed-star tests in '
              'fixstar_config_test.dart read from here. Confirm the new '
              'catalogue is intended, then update _pinnedFixedStarDigest.',
        );
      });
    },
    skip: ephePath == null ? 'SWE_EPHE_PATH not set' : null,
  );
}
