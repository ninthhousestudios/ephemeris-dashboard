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
