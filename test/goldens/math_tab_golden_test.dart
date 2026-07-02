import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/math/math_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('MathTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'math_tab',
      const MathTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
