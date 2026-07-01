import 'package:flutter_test/flutter_test.dart';

import 'package:swe_dashboard/tabs/ayanamsa/ayanamsa_provider.dart';
import 'package:swe_dashboard/tabs/ayanamsa/ayanamsa_tab.dart';

import 'golden_helper.dart';

void main() {
  testWidgets('AyanamsaTab list mode goldens', (tester) async {
    await generateGoldens(
      tester,
      'ayanamsa_tab_list',
      const AyanamsaTab(),
      overrides: [
        ...tabOverrides,
        ayanamsaCompareModeProvider.overrideWith((ref) => false),
      ],
      allowOverflow: true,
    );
  });

  testWidgets('AyanamsaTab compare mode goldens', (tester) async {
    await generateGoldens(
      tester,
      'ayanamsa_tab_compare',
      const AyanamsaTab(),
      overrides: [
        ...tabOverrides,
        ayanamsaCompareModeProvider.overrideWith((ref) => true),
      ],
      allowOverflow: true,
    );
  });
}
