// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephe/bootstrap.dart';
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

  group('miss vs failure (swe-dashboard/90)', () {
    // Staging must never report "this build ships no ephemeris files" when
    // what actually happened is "a staging step broke". These assert the
    // distinction at the value level; the classification itself lives in
    // staging_io's _execute.

    test('a bootstrap that found nothing is not, by itself, a failure', () {
      const bootstrap = EpheBootstrap.none();
      expect(bootstrap.hasEpheFiles, isFalse);
      expect(bootstrap.stagingFailed, isFalse);
    });

    test('hasEpheFiles false + stagingFailed true is a distinct state', () {
      const bootstrap = EpheBootstrap(
        bundledPath: null,
        managedPath: '/support/ephe',
        webFilenames: [],
        failures: [
          StagingFailure(
            'extract bundled assets to app support',
            'asset extraction failed: PathAccessException',
          ),
        ],
      );

      // Same Moshier outcome as EpheBootstrap.none() ...
      expect(bootstrap.hasEpheFiles, isFalse);
      // ... but distinguishable, which is the entire point.
      expect(bootstrap.stagingFailed, isTrue);
      expect(bootstrap.failures.single.probeName, contains('extract'));
    });

    test('a failure does not imply the app has no ephemeris files', () {
      // An early probe can break and a later one still win. The app works;
      // it still has a real problem worth reporting.
      const bootstrap = EpheBootstrap(
        bundledPath: '/opt/app/data/ephe',
        managedPath: '/support/ephe',
        webFilenames: [],
        failures: [
          StagingFailure(
            'swisseph_rs pub cache (dev mode)',
            'unreadable package config: FormatException',
          ),
        ],
      );
      expect(bootstrap.hasEpheFiles, isTrue);
      expect(bootstrap.stagingFailed, isTrue);
    });

    test('a failure names the probe, so the report says what broke', () {
      const failure = StagingFailure('probe name', 'what went wrong');
      expect(failure.toString(), 'probe name: what went wrong');
    });
  });

  group('runProbePlan classification', () {
    late Directory tmp;
    late Directory originalCwd;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ephe_plan_');
      // PackageConfigProbe reads .dart_tool/package_config.json relative to
      // the CWD. Every case below writes one, so the probe never falls
      // through to walking up from the test runner's executable — which
      // would find this repo's own config and make results host-dependent.
      originalCwd = Directory.current;
      Directory.current = tmp;
    });

    tearDown(() {
      Directory.current = originalCwd;
      tmp.deleteSync(recursive: true);
    });

    void writePackageConfig(String contents) {
      Directory('${tmp.path}/.dart_tool').createSync(recursive: true);
      File(
        '${tmp.path}/.dart_tool/package_config.json',
      ).writeAsStringSync(contents);
    }

    test(
      'a valid config without swisseph_rs is a miss, not a failure',
      () async {
        writePackageConfig('{"configVersion":2,"packages":[]}');

        // The control: nothing found, nothing broken.
        final (path, failures) = await runProbePlan(const [
          PackageConfigProbe(),
        ]);

        expect(path, isNull);
        expect(failures, isEmpty);
      },
    );

    test('a malformed package config is a failure, not a miss', () async {
      writePackageConfig('{ this is not json');

      final (path, failures) = await runProbePlan(const [PackageConfigProbe()]);

      // Before swe-dashboard/90 this was indistinguishable from the control
      // above: a bare catch turned it into "no ephemeris files".
      expect(path, isNull);
      expect(failures, hasLength(1));
      expect(failures.single.probeName, 'swisseph_rs pub cache (dev mode)');
      expect(failures.single.message, contains('unreadable package config'));
    });

    test('a config with the wrong shape is a failure, not a miss', () async {
      // Valid JSON, but `packages` is not a list — the cast throws.
      writePackageConfig('{"configVersion":2,"packages":{}}');

      final (path, failures) = await runProbePlan(const [PackageConfigProbe()]);

      expect(path, isNull);
      expect(failures, hasLength(1));
      expect(failures.single.message, contains('unreadable package config'));
    });

    test('a failing probe does not stop a later one from winning', () async {
      writePackageConfig('{ this is not json');
      final good = Directory('${tmp.path}/good')..createSync();
      File('${good.path}/sepl_18.se1').writeAsStringSync('x');

      final (path, failures) = await runProbePlan([
        const PackageConfigProbe(),
        DirectoryProbe('later probe', good.path),
      ]);

      // Working app, real problem — both reported.
      expect(path, good.path);
      expect(failures, hasLength(1));
    });

    test(
      'an unreadable directory is a miss — DirectoryProbe never fails',
      () async {
        // isValidEpheDir swallows its own I/O errors by design, so a directory
        // probe cannot produce a StagingFailure.
        final (path, failures) = await runProbePlan([
          DirectoryProbe('gone', '${tmp.path}/nonexistent'),
        ]);

        expect(path, isNull);
        expect(failures, isEmpty);
      },
    );
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
