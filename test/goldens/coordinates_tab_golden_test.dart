import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/coordinates/coordinates_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('CoordinatesTab goldens', (tester) async {
    await generateGoldens(
      tester,
      'coordinates_tab',
      const CoordinatesTab(),
      overrides: tabOverrides,
      allowOverflow: true,
    );
  });
}
