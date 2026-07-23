// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calculation/series_settings_provider.dart';
import 'house_system_dropdown.dart';

/// The body tabs' house-position controls, hosted on the Series row
/// (swe-dashboard/58). Mode-aware:
///
/// - **Card mode:** a "House position" toggle; while on it reveals the app-wide
///   house-system dropdown.
/// - **Series mode:** house position is a picker quantity, so there is no
///   toggle — but the system still needs choosing, so the dropdown shows
///   whenever the House/House Pos quantity is not hidden.
///
/// [toggleProvider] is the tab's own card-view show/hide flag; everything else
/// is shared, so the three body tabs wire this in one line.
class HousePosControls extends ConsumerWidget {
  const HousePosControls({
    super.key,
    required this.tabId,
    required this.toggleProvider,
  });

  final String tabId;
  final StateProvider<bool> toggleProvider;

  static const _labels = {'House', 'House Pos'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final seriesEnabled = ref.watch(
      seriesSettingsProvider(tabId).select((s) => s.enabled),
    );

    if (seriesEnabled) {
      final hidden = ref.watch(
        seriesSettingsProvider(tabId).select((s) => s.hiddenLabels),
      );
      // Show the chooser while house position is an active quantity.
      final active = _labels.any((l) => !hidden.contains(l));
      if (!active) return const SizedBox.shrink();
      return _systemChooser(theme);
    }

    final showHousePos = ref.watch(toggleProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChip(
          label: const Text('House position'),
          avatar: const Icon(Icons.home_work_outlined, size: 16),
          selected: showHousePos,
          onSelected: (v) => ref.read(toggleProvider.notifier).state = v,
          visualDensity: VisualDensity.compact,
        ),
        if (showHousePos) ...[const SizedBox(width: 12), _systemChooser(theme)],
      ],
    );
  }

  Widget _systemChooser(ThemeData theme) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'System ',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 4),
      const HouseSystemDropdown(width: 200),
    ],
  );
}
