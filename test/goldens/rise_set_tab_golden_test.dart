// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/rise_set/rise_set_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('RiseSetTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'rise_set_tab',
      const RiseSetTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
