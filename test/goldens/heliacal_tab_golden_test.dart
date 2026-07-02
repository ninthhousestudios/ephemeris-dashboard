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
