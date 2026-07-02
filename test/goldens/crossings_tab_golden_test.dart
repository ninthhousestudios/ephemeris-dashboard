import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/crossings/crossings_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('CrossingsTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'crossings_tab',
      const CrossingsTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
