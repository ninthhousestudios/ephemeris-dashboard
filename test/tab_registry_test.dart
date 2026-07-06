import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/layout/tab_definitions.dart';
import 'package:swe_dashboard/layout/tab_registry.dart';

void main() {
  test('every AppTab has a TabDescriptor', () {
    for (final tab in AppTab.values) {
      expect(
        tabDescriptorMap.containsKey(tab),
        isTrue,
        reason: 'Missing TabDescriptor for ${tab.name}',
      );
    }
  });

  test('no duplicate tabs in registry', () {
    final tabs = tabRegistry.map((d) => d.tab).toList();
    expect(tabs.toSet().length, tabs.length);
  });

  test('registry order matches AppTab.values', () {
    final registryTabs = tabRegistry.map((d) => d.tab).toList();
    expect(registryTabs, AppTab.values);
  });
}
