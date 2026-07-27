// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/body_catalog.dart';
import 'package:swe_dashboard/core/body_selection.dart';
import 'package:swe_dashboard/core/ephe/scanner.dart';
import 'package:swe_dashboard/core/ephe/types.dart';
import 'package:swe_dashboard/core/swe_constants.dart';

/// The selection → declared-Ephemeris-Source-files aggregation, which before
/// swe-dashboard/85 was only ever exercised through the running app.
///
/// No engine, no widgets: `ProviderContainer` plus a fake ephemeris scan.
void main() {
  /// A scan reporting [filenames] as installed. Only `filename` and `status`
  /// are consulted by the aggregation.
  EphemerisScan scanOf(List<String> filenames) => EphemerisScan(
    [
      for (final f in filenames)
        EpheFile(
          filename: f,
          family: BodyFamily.numberedAsteroid,
          startJd: 0,
          endJd: 0,
          startYear: 0,
          endYear: 0,
          sizeBytes: 1 << 20,
          status: EpheFileStatus.installed,
        ),
    ],
    DateTime(2026),
    '/ephe',
  );

  ProviderContainer containerWith(List<String> installed) {
    final container = ProviderContainer(
      overrides: [
        ephemerisScanProvider.overrideWith((ref) async => scanOf(installed)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Pumps the async scan through so `valueOrNull` is populated.
  Future<void> settle(ProviderContainer container) async {
    await container.read(ephemerisScanProvider.future);
  }

  const erosMpc = 433;
  const erosFile = 'se00433s.se1';
  const erosBody = seAstOffset + erosMpc;

  group('registry', () {
    test('every selection has a distinct (tab, role) id', () {
      final ids = BodySelection.values.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every selection starts on its declared initial value', () {
      final container = containerWith(const []);
      for (final selection in BodySelection.values) {
        expect(
          container.read(bodySelectionProvider(selection)),
          selection.initial,
          reason: selection.id,
        );
      }
    });

    test('single-body roles hold exactly one body', () {
      for (final selection in const [
        BodySelection.nodesApsidesBody,
        BodySelection.crossingsHelioBody,
        BodySelection.differentialBodyA,
        BodySelection.differentialBodyB,
        BodySelection.eclipsesOccultPlanet,
        BodySelection.planetocentricCenter,
      ]) {
        expect(selection.initial, hasLength(1), reason: selection.id);
      }
    });
  });

  group('asteroid aggregation', () {
    test('is empty when nothing selected declares an asteroid', () async {
      final container = containerWith([erosFile]);
      await settle(container);
      expect(container.read(selectedAsteroidMpcProvider), isEmpty);
    });

    test('picks up an asteroid from ANY selection in the registry', () async {
      // The point of the inversion: not a hand-listed subset of tabs. Every
      // selection core declares is folded, including the single-body roles
      // that the old hand-maintained list did not all cover.
      for (final selection in BodySelection.values) {
        final container = containerWith([erosFile]);
        await settle(container);
        container.read(bodySelectionProvider(selection).notifier).add(erosBody);
        expect(
          container.read(selectedAsteroidMpcProvider),
          [erosMpc],
          reason: 'selection ${selection.id} did not reach the engine config',
        );
      }
    });

    test('drops an asteroid whose file is not installed', () async {
      final container = containerWith(const []);
      await settle(container);
      container
          .read(bodySelectionProvider(BodySelection.planetsBodies).notifier)
          .add(erosBody);
      expect(container.read(selectedAsteroidMpcProvider), isEmpty);
    });

    test('deduplicates an asteroid selected on two tabs', () async {
      final container = containerWith([erosFile]);
      await settle(container);
      container
          .read(bodySelectionProvider(BodySelection.planetsBodies).notifier)
          .add(erosBody);
      container
          .read(bodySelectionProvider(BodySelection.phenomenaBodies).notifier)
          .add(erosBody);
      expect(container.read(selectedAsteroidMpcProvider), [erosMpc]);
    });

    test('recomputes when a selection changes', () async {
      final container = containerWith([erosFile]);
      await settle(container);
      final notifier = container.read(
        bodySelectionProvider(BodySelection.otherBodies).notifier,
      );
      notifier.add(erosBody);
      expect(container.read(selectedAsteroidMpcProvider), [erosMpc]);
      notifier.remove(erosBody);
      expect(container.read(selectedAsteroidMpcProvider), isEmpty);
    });
  });

  group('planet moon aggregation', () {
    const io = sePlmoonOffset + 501;

    test('picks up a moon from any selection, when installed', () async {
      final container = containerWith(['sepm$io.se1']);
      await settle(container);
      container
          .read(
            bodySelectionProvider(BodySelection.planetocentricBodies).notifier,
          )
          .add(io);
      expect(container.read(selectedPlanetMoonIdsProvider), [io]);
    });

    test('drops a moon whose file is not installed', () async {
      final container = containerWith(const []);
      await settle(container);
      container
          .read(bodySelectionProvider(BodySelection.otherBodies).notifier)
          .add(io);
      expect(container.read(selectedPlanetMoonIdsProvider), isEmpty);
    });

    test('does not mistake an asteroid for a moon', () async {
      final container = containerWith([erosFile, 'sepm501.se1']);
      await settle(container);
      container
          .read(bodySelectionProvider(BodySelection.otherBodies).notifier)
          .add(erosBody);
      expect(container.read(selectedPlanetMoonIdsProvider), isEmpty);
      expect(container.read(selectedAsteroidMpcProvider), [erosMpc]);
    });
  });

  group('single-body reads', () {
    test('reads the first element, and survives an emptied selection', () {
      final container = containerWith(const []);
      const selection = BodySelection.nodesApsidesBody;
      expect(container.read(singleBodyProvider(selection)), seMoon);

      container
          .read(bodySelectionProvider(selection).notifier)
          .setSingle(seSun);
      expect(container.read(singleBodyProvider(selection)), seSun);

      container.read(bodySelectionProvider(selection).notifier).clear();
      expect(container.read(singleBodyProvider(selection)), seMoon);
    });

    test('setSingle replaces rather than appends', () {
      final container = containerWith(const []);
      const selection = BodySelection.differentialBodyA;
      final notifier = container.read(
        bodySelectionProvider(selection).notifier,
      );
      notifier
        ..setSingle(seMars)
        ..setSingle(seVenus);
      expect(container.read(bodySelectionProvider(selection)), [seVenus]);
    });
  });

  group('catalog', () {
    test('names every body it offers as a chip', () {
      final offered = <int>{
        ...BodyCatalog.full,
        ...BodyCatalog.centaursAndMinors,
        ...BodyCatalog.interpolatedPoints,
        ...BodyCatalog.uranian,
        seEarth,
      };
      for (final body in offered) {
        expect(
          BodyCatalog.names.containsKey(body),
          isTrue,
          reason: 'body $body has no catalog label',
        );
      }
    });

    test('labels a numbered asteroid by name when known', () {
      expect(BodyCatalog.labelFor(erosBody), 'Eros');
      expect(BodyCatalog.labelFor(seAstOffset + 99999), '#99999');
    });

    test('presets draw only on bodies the catalog offers', () {
      for (final preset in BodyCatalog.presets) {
        expect(preset.bodies, isNotEmpty, reason: preset.label);
        for (final body in preset.bodies) {
          expect(BodyCatalog.full, contains(body), reason: preset.label);
        }
      }
    });
  });
}
