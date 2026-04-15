import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swe_dashboard/widgets/ephe_manager/license_notice.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    required Future<bool> Function(BuildContext, SharedPreferences) onTap,
    required ValueChanged<bool> onResult,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async => onResult(await onTap(ctx, prefs)),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('prompts once, then silently returns true', (tester) async {
    var result = false;

    await pumpHarness(
      tester,
      onTap: maybeShowLicenseNotice,
      onResult: (r) => result = r,
    );

    // First invocation — dialog shown, user accepts.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Ephemeris file license'), findsOneWidget);
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    // Second invocation — no dialog, returns true immediately.
    result = false;
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Ephemeris file license'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('cancel does not persist acceptance', (tester) async {
    var result = true;

    await pumpHarness(
      tester,
      onTap: maybeShowLicenseNotice,
      onResult: (r) => result = r,
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    // Next invocation still prompts — we did not persist a cancel.
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Ephemeris file license'), findsOneWidget);
  });
}
