// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/nodes_apsides/nodes_apsides_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('NodesApsidesTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'nodes_apsides_tab',
      const NodesApsidesTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
