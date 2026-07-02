import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/phenomena/phenomena_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('PhenomenaTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'phenomena_tab',
      const PhenomenaTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
