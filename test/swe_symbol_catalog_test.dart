// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephemeris/swe_symbol_catalog.dart';

void main() {
  test('TracedFunction has 39 values', () {
    expect(TracedFunction.values, hasLength(39));
  });

  test('TracedFunction names are unique', () {
    final names = TracedFunction.values.map((e) => e.name).toSet();
    expect(names, hasLength(TracedFunction.values.length));
  });

  test('all context-setter functions are present', () {
    expect(
      TracedFunction.values,
      containsAll([
        TracedFunction.sweSetEphePath,
        TracedFunction.sweSetSidMode,
        TracedFunction.sweSetTopo,
        TracedFunction.sweSetJplFile,
      ]),
    );
  });

  test('all calculation functions are present', () {
    expect(
      TracedFunction.values,
      containsAll([
        TracedFunction.sweCalcUt,
        TracedFunction.sweCalcPctr,
        TracedFunction.sweHouses,
        TracedFunction.sweGetAyanamsaUt,
        TracedFunction.sweGetAyanamsaExUt,
        TracedFunction.sweDeltat,
        TracedFunction.sweSidtime,
        TracedFunction.sweNodApsUt,
        TracedFunction.sweFixstar2Ut,
        TracedFunction.swePhenoUt,
        TracedFunction.sweRiseTrans,
        TracedFunction.sweHeliacalUt,
        TracedFunction.sweSolcrossUt,
        TracedFunction.sweMooncrossUt,
        TracedFunction.sweMooncrossNodeUt,
        TracedFunction.sweHeliocrossUt,
      ]),
    );
  });
}
