// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/planets/planets_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('PlanetsTab goldens (post-calculate)', (tester) async {
    await generateGoldens(
      tester,
      'planets_tab',
      const PlanetsTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
