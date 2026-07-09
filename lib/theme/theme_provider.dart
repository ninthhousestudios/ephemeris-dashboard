// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/persistence.dart';

final themeProvider = StateProvider<ThemeMode>((ref) {
  final persistence = ref.read(persistenceProvider);
  return persistence.loadTheme();
});

/// Global UI scale factor (1.0 = 100%). Ctrl+= / Ctrl+- to adjust.
final scaleFactorProvider = StateProvider<double>((ref) {
  final persistence = ref.read(persistenceProvider);
  return persistence.loadZoom();
});

const _scaleStep = 0.05;
const _scaleMin = 0.6;
const _scaleMax = 2.0;

void zoomIn(WidgetRef ref) {
  ref
      .read(scaleFactorProvider.notifier)
      .update((s) => (s + _scaleStep).clamp(_scaleMin, _scaleMax));
  ref.read(persistenceProvider).saveZoom(ref.read(scaleFactorProvider));
}

void zoomOut(WidgetRef ref) {
  ref
      .read(scaleFactorProvider.notifier)
      .update((s) => (s - _scaleStep).clamp(_scaleMin, _scaleMax));
  ref.read(persistenceProvider).saveZoom(ref.read(scaleFactorProvider));
}

void zoomReset(WidgetRef ref) {
  ref.read(scaleFactorProvider.notifier).state = 1.0;
  ref.read(persistenceProvider).saveZoom(1.0);
}
