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
