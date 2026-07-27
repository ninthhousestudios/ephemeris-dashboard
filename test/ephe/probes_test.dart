// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephe/probes.dart';
import 'package:swe_dashboard/core/ephe/staging_io.dart';

PlatformFacts _facts({
  bool macOS = false,
  bool linux = false,
  bool windows = false,
  bool android = false,
  bool iOS = false,
  String exeDir = '/opt/app',
  String cwd = '/home/dev/project',
}) => (
  isMacOS: macOS,
  isLinux: linux,
  isWindows: windows,
  isAndroid: android,
  isIOS: iOS,
  exeDir: exeDir,
  cwd: cwd,
);

void main() {
  group('nativeEpheProbes ordering', () {
    test('linux tries release bundle, then dev assets, then pub cache', () {
      final probes = nativeEpheProbes(_facts(linux: true));

      expect(probes, [
        const DirectoryProbe('release bundle (CMake)', '/opt/app/data/ephe'),
        const DirectoryProbe(
          'release bundle (flutter_assets)',
          '/opt/app/data/flutter_assets/assets/ephe',
        ),
        const DirectoryProbe(
          'project assets (dev mode)',
          '/home/dev/project/assets/ephe',
        ),
        const PackageConfigProbe(),
      ]);
    });

    test('windows matches linux', () {
      expect(
        nativeEpheProbes(_facts(windows: true)),
        nativeEpheProbes(_facts(linux: true)),
      );
    });

    test('macOS only extracts assets — never reads the bundle or CWD', () {
      // .se1 files cannot live inside a signed app bundle (codesign rejects
      // them) and the sandbox blocks CWD/.dart_tool reads.
      expect(nativeEpheProbes(_facts(macOS: true)), [
        const AssetExtractionProbe(),
      ]);
    });

    test('mobile checks the release bundle first, then extracts assets', () {
      // The release-bundle probes are not macOS-gated, so mobile inherits
      // them. They cost two directory stats and always miss on a real
      // device — asset extraction is what actually stages the files.
      for (final facts in [_facts(android: true), _facts(iOS: true)]) {
        expect(nativeEpheProbes(facts), [
          const DirectoryProbe('release bundle (CMake)', '/opt/app/data/ephe'),
          const DirectoryProbe(
            'release bundle (flutter_assets)',
            '/opt/app/data/flutter_assets/assets/ephe',
          ),
          const AssetExtractionProbe(),
        ]);
      }
    });

    test('asset extraction is always last — it creates its own target', () {
      for (final facts in [
        _facts(macOS: true),
        _facts(android: true),
        _facts(iOS: true),
      ]) {
        final probes = nativeEpheProbes(facts);
        expect(probes.last, isA<AssetExtractionProbe>());
        expect(probes.whereType<AssetExtractionProbe>(), hasLength(1));
      }
    });

    test('an unrecognised platform still tries the release bundle', () {
      // Only the release-bundle probes are un-gated. If they miss there is
      // nothing left to try and staging returns null — the Moshier case.
      expect(nativeEpheProbes(_facts()), [
        const DirectoryProbe('release bundle (CMake)', '/opt/app/data/ephe'),
        const DirectoryProbe(
          'release bundle (flutter_assets)',
          '/opt/app/data/flutter_assets/assets/ephe',
        ),
      ]);
    });
  });

  group('isValidEpheDir', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('ephe_probe_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('rejects a directory that does not exist', () {
      expect(isValidEpheDir('${tmp.path}/nope'), isFalse);
    });

    test('rejects an empty directory', () {
      expect(isValidEpheDir(tmp.path), isFalse);
    });

    test('rejects a directory with no .se1 files', () {
      File('${tmp.path}/sefstars.txt').writeAsStringSync('not an se1');
      expect(isValidEpheDir(tmp.path), isFalse);
    });

    test('accepts a directory holding at least one .se1', () {
      File('${tmp.path}/sepl_18.se1').writeAsStringSync('x');
      expect(isValidEpheDir(tmp.path), isTrue);
    });

    test('rejects a path that is a file, not a directory', () {
      final f = File('${tmp.path}/sepl_18.se1')..writeAsStringSync('x');
      expect(isValidEpheDir(f.path), isFalse);
    });
  });
}
