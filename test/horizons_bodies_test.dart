// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/horizons/horizons_bodies.dart';

void main() {
  group('horizonsBodies', () {
    HorizonsBody bodyLabelled(String label) =>
        horizonsBodies.firstWhere((b) => b.label == label);

    test('major bodies use a bare NAIF id', () {
      expect(bodyLabelled('Sun').command, '10');
      expect(bodyLabelled('Moon').command, '301');
      expect(bodyLabelled('Mars').command, '499');
      expect(bodyLabelled('Pluto').command, '999');
    });

    test('minor bodies use the <number>; small-body form', () {
      // The trailing ';' forces small-body search, so '1;' is Ceres, not the
      // Mercury barycenter (id 1).
      expect(bodyLabelled('Ceres').command, '1;');
      expect(bodyLabelled('Chiron').command, '2060;');
      expect(bodyLabelled('Eris').command, '136199;');
      for (final body in horizonsBodyGroups.last.bodies) {
        expect(body.command, endsWith(';'));
        expect(int.tryParse(body.command.replaceAll(';', '')), isNotNull);
      }
    });

    test('commands are unique across the catalogue', () {
      final commands = horizonsBodies.map((b) => b.command).toList();
      expect(commands.toSet().length, commands.length);
    });

    test('flattened list equals the groups concatenated', () {
      final fromGroups = [for (final g in horizonsBodyGroups) ...g.bodies];
      expect(horizonsBodies.length, fromGroups.length);
    });
  });
}
