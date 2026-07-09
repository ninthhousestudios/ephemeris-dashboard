// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/layout/app_shell.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('AppShell goldens', (tester) async {
    await generateGoldens(
      tester,
      'app_shell',
      const AppShell(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
