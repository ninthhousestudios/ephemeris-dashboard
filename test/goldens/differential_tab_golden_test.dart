// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/differential/differential_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('DifferentialTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'differential_tab',
      const DifferentialTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
