// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:test/test.dart';

import 'src/api_walker.dart';
import 'src/oracle_map.dart';

void main() {
  late List<PublicSymbol> symbols;

  setUpAll(() async {
    symbols = await walkPublicApi();
  });

  group('Counterpart totality', () {
    test('every public symbol declares its Rust counterpart', () {
      final missing = <String>[];
      for (final sym in symbols) {
        if (sym.requiresCounterpart && !sym.hasCounterpart) {
          missing.add('${sym.qualifiedName} (${sym.kind.name})');
        }
      }
      expect(
        missing,
        isEmpty,
        reason:
            'Public symbols missing /// Counterpart: declaration:\n'
            '  ${missing.join('\n  ')}',
      );
    });

    test('detection mechanism catches a missing declaration', () {
      const phantom = PublicSymbol(
        'Phantom.missing',
        SymbolKind.method,
        '/// No counterpart here',
      );
      expect(phantom.hasCounterpart, isFalse);

      const real = PublicSymbol(
        'Ephemeris.calcUt',
        SymbolKind.method,
        '/// Counterpart: swisseph::Ephemeris::calc_ut',
      );
      expect(real.hasCounterpart, isTrue);
    });
  });

  group('Oracle-map totality', () {
    test(
      'every Ephemeris method and top-level function has an oracle-map entry',
      () {
        final targets = symbols.where((s) => s.isOracleMapTarget).toList();

        final oracleMapTargetNames = <String>{};
        for (final s in targets) {
          final enclosingType = s.qualifiedName.split('.').first;
          if (enclosingType == 'Ephemeris' || !s.qualifiedName.contains('.')) {
            oracleMapTargetNames.add(s.qualifiedName);
          }
        }

        final unmapped = <String>[];
        for (final name in oracleMapTargetNames) {
          if (!oracleMap.containsKey(name)) {
            unmapped.add(name);
          }
        }
        expect(
          unmapped,
          isEmpty,
          reason:
              'Public methods missing oracle-map entries:\n'
              '  ${unmapped.join('\n  ')}',
        );
      },
    );

    test('no stale entries in oracle map', () {
      final targets = symbols.where((s) => s.isOracleMapTarget).toList();

      final oracleMapTargetNames = <String>{};
      for (final s in targets) {
        final enclosingType = s.qualifiedName.split('.').first;
        if (enclosingType == 'Ephemeris' || !s.qualifiedName.contains('.')) {
          oracleMapTargetNames.add(s.qualifiedName);
        }
      }

      final stale = <String>[];
      for (final key in oracleMap.keys) {
        if (!oracleMapTargetNames.contains(key)) {
          stale.add(key);
        }
      }
      expect(
        stale,
        isEmpty,
        reason:
            'Oracle-map entries with no matching public method:\n'
            '  ${stale.join('\n  ')}',
      );
    });

    test('every engineTrusted entry has a reason', () {
      final missingReason = <String>[];
      for (final entry in oracleMap.entries) {
        if (entry.value.kind == OracleKind.engineTrusted &&
            (entry.value.reason == null || entry.value.reason!.isEmpty)) {
          missingReason.add(entry.key);
        }
      }
      expect(
        missingReason,
        isEmpty,
        reason: 'engineTrusted entries without a reason',
      );
    });

    test('detection mechanism catches an unmapped method', () {
      const phantomName = 'Ephemeris.phantomMethod';
      expect(
        oracleMap.containsKey(phantomName),
        isFalse,
        reason: 'Phantom method should not be in oracle map',
      );
    });
  });
}
