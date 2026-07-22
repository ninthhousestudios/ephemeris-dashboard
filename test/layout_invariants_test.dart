// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Layout invariants for every screen-level surface, swept across viewports
/// and text scales.
///
/// This is the structural counterpart to the golden canaries in
/// `test/goldens/`: it asserts the rules CLAUDE.md calls non-negotiable under
/// "Zoom & Responsive Scaling" and fails with a readable name rather than a
/// pixel diff.
///
/// The scales include fractional values on purpose. Fixed widths and aspect
/// ratios tend to survive 1.0 and 2.0 and break at 1.15 or 1.3, where
/// sub-pixel rounding bites.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/widget_fixtures.dart';

/// Text scale factors to sweep. 1.0 is the baseline; the rest are zoom levels
/// the app's own controls can reach.
const _scales = [1.0, 1.15, 1.3, 1.7, 2.0];

/// Horizontal overflows that exist today, itemised by `size @ scale`.
///
/// This is a defect list, not a suppression, and it is checked **both ways**:
/// an overflow missing from here fails the test, and an entry here that has
/// stopped overflowing also fails, telling you to delete the line. It can only
/// shrink. See yojana swe-dashboard/65.
const _knownOverflows = <String, Set<String>>{
  'app_shell': {
    'mobile @ 1.0x',
    'mobile @ 1.15x',
    'mobile @ 1.7x',
    'mobile @ 2.0x',
    'desktop @ 1.0x',
    'desktop @ 1.15x',
  },
  // AppShell hosts the ContextBar, so it inherits every ContextBar overflow.
  'context_bar': {
    'mobile @ 1.0x',
    'mobile @ 1.15x',
    'mobile @ 1.7x',
    'mobile @ 2.0x',
    'desktop @ 1.0x',
    'desktop @ 1.15x',
  },
  'coordinates_tab': {'mobile @ 2.0x'},
  'dates_tab': {'mobile @ 1.3x'},
  'differential_tab': {'mobile @ 1.15x'},
  'math_tab': {'mobile @ 1.7x'},
};

/// Run [body] with overflow errors diverted into the returned map of
/// `size @ scale` to the messages seen there.
///
/// `FlutterError.onError` **must** be restored before any `expect`, or the
/// test binding asserts on `_pendingExceptionDetails` and flutter_tools then
/// deadlocks on shutdown instead of reporting the failure. Restoring it via
/// `addTearDown` is too late.
Future<Map<String, List<String>>> collectOverflows(
  Future<void> Function(void Function(String) mark) body,
) async {
  final found = <String, List<String>>{};
  final original = FlutterError.onError;
  var where = '';
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      (found[where] ??= []).add(text.split('\n').first);
    } else {
      original?.call(details);
    }
  };
  try {
    await body((label) => where = label);
  } finally {
    FlutterError.onError = original;
  }
  return found;
}

void main() {
  group('no unexpected overflow at any zoom level', () {
    for (final widgetCase in allWidgetCases) {
      testWidgets(widgetCase.name, (tester) async {
        final found = await collectOverflows((mark) async {
          for (final (sizeName, size) in kSizes) {
            for (final scale in _scales) {
              mark('$sizeName @ ${scale}x');
              await pumpAppWidget(
                tester,
                widgetCase.widget,
                size: size,
                isLight: true,
                textScale: scale,
                // AppShell brings its own SingleChildScrollView; everything
                // else is hosted inside one by AppShell in the real app.
                hostInScrollView: widgetCase.name != 'app_shell',
                overrides: widgetCase.overrides,
              );
            }
          }
        });

        final actual = found.keys.toSet();
        final known = _knownOverflows[widgetCase.name] ?? const <String>{};

        final regressions = actual.difference(known);
        expect(
          regressions,
          isEmpty,
          reason:
              'New overflow in ${widgetCase.name} — fix the layout rather than '
              'widening _knownOverflows:\n'
              '${regressions.map((k) => '  $k: ${found[k]!.first}').join('\n')}',
        );

        final fixed = known.difference(actual);
        expect(
          fixed,
          isEmpty,
          reason:
              '${widgetCase.name} no longer overflows at ${fixed.join(', ')} — '
              'delete those entries from _knownOverflows.',
        );
      });
    }
  });

  group('still renders at extreme zoom', () {
    // A surface that silently collapsed to an empty box would sail through the
    // overflow sweep above, so pin that each one still paints text at 2x.
    for (final widgetCase in allWidgetCases) {
      testWidgets(widgetCase.name, (tester) async {
        await collectOverflows((mark) async {
          for (final scale in [1.0, 2.0]) {
            mark('desktop @ ${scale}x');
            await pumpAppWidget(
              tester,
              widgetCase.widget,
              size: kDesktop,
              isLight: true,
              textScale: scale,
              hostInScrollView: widgetCase.name != 'app_shell',
              overrides: widgetCase.overrides,
            );
          }
        });
        expect(
          find.byType(Text),
          findsWidgets,
          reason: '${widgetCase.name} rendered no text at 2x',
        );
      });
    }
  });
}
