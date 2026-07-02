import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/stars/stars_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('StarsTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'stars_tab',
      const StarsTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
