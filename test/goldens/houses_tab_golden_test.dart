// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/houses/houses_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('HousesTab goldens (post-calculate)', (tester) async {
    await generateGoldens(
      tester,
      'houses_tab',
      const HousesTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
