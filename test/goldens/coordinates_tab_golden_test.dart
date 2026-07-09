// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/coordinates/coordinates_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('CoordinatesTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'coordinates_tab',
      const CoordinatesTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
