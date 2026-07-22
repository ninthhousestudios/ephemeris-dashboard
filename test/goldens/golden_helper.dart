// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Golden canaries. Only the two composed surfaces — AppShell and ContextBar —
/// carry baselines; everything else is covered structurally by
/// `test/layout_invariants_test.dart`, which diffs as text rather than pixels.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/widget_fixtures.dart';

/// Fraction of pixels allowed to differ — 0.01 is 1%, not 1.0. `diffPercent`
/// is a 0..1 fraction, so a threshold of 1.0 accepts every image including a
/// size mismatch, which is what this comparator used to do.
const double _pixelTolerance = 0.01;

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _pixelTolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

void setupTolerantComparator() {
  if (goldenFileComparator is _TolerantComparator) return;
  final basedir = (goldenFileComparator as LocalFileComparator).basedir;
  // `LocalFileComparator` takes the URI of a *test file* and uses its parent
  // as the basedir. Handing it a directory therefore walks one level up —
  // which is how the baselines ended up in `test/` instead of `test/goldens/`.
  goldenFileComparator = _TolerantComparator(
    basedir.resolve('golden_helper.dart'),
  );
}

/// Generate all 6 goldens (3 sizes x 2 themes) for a widget.
///
/// [allowOverflow] suppresses overflow errors. Both canaries need it: the
/// context bar is deliberately wider than a 400px mobile viewport and
/// horizontal-scrolls. Overflow is asserted on properly, across every surface
/// and text scale, in `test/layout_invariants_test.dart`.
Future<void> generateGoldens(
  WidgetTester tester,
  String widgetName,
  Widget widget, {
  List<Override> overrides = const [],
  bool allowOverflow = false,
}) async {
  setupTolerantComparator();
  final originalOnError = FlutterError.onError;
  if (allowOverflow) {
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) {
        originalOnError?.call(details);
      }
    };
  }
  addTearDown(() => FlutterError.onError = originalOnError);

  for (final (sizeName, size) in kSizes) {
    for (final (themeName, isLight) in kThemes) {
      await pumpAppWidget(
        tester,
        widget,
        size: size,
        isLight: isLight,
        overrides: overrides,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('${widgetName}_${sizeName}_$themeName.png'),
      );
    }
  }
}
