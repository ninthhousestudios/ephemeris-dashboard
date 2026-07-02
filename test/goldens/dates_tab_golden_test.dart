import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/dates/dates_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('DatesTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'dates_tab',
      const DatesTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
