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
