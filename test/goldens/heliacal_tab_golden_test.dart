// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/heliacal/heliacal_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('HeliacalTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'heliacal_tab',
      const HeliacalTab(),
      overrides: [...tabOverrides, heliacalResultOverride],
      allowOverflow: true,
    );
  });
}
