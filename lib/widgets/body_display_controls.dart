// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calculation/series_settings_provider.dart';
import 'house_system_dropdown.dart';

/// The body tabs' card-view display controls, hosted on the Series row
/// (swe-dashboard/58, /69). Two toggles — horizontal coordinates and house
/// position — plus, while house position is on, the app-wide house-system
/// dropdown. Mode-aware:
///
/// - **Card mode:** the "Horizontal coords" and "House position" toggles; the
///   house-system dropdown appears while house position is on.
/// - **Series mode:** both quantities are picker columns, so neither has a
///   toggle — but the house system still needs choosing, so the dropdown shows
///   whenever the House/House Pos quantity is not hidden.
///
/// [housePosToggle] and [horizontalToggle] are the tab's own card-view
/// show/hide flags; everything else is shared, so the three body tabs wire this
/// in one line.
class BodyDisplayControls extends ConsumerWidget {
  const BodyDisplayControls({
    super.key,
    required this.tabId,
    required this.housePosToggle,
    required this.horizontalToggle,
  });

  final String tabId;
  final StateProvider<bool> housePosToggle;
  final StateProvider<bool> horizontalToggle;

  static const _houseLabels = {'House', 'House Pos'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final seriesEnabled = ref.watch(
      seriesSettingsProvider(tabId).select((s) => s.enabled),
    );

    if (seriesEnabled) {
      // Both quantities are picker columns in series mode, so neither toggles
      // here. Only the house-system chooser needs a home — shown while house
      // position is an active quantity.
      final hidden = ref.watch(
        seriesSettingsProvider(tabId).select((s) => s.hiddenLabels),
      );
      final active = _houseLabels.any((l) => !hidden.contains(l));
      if (!active) return const SizedBox.shrink();
      return _systemChooser(theme);
    }

    final showHorizontal = ref.watch(horizontalToggle);
    final showHousePos = ref.watch(housePosToggle);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChip(
          label: const Text('Horizontal coords'),
          avatar: const Icon(Icons.explore_outlined, size: 16),
          selected: showHorizontal,
          onSelected: (v) => ref.read(horizontalToggle.notifier).state = v,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('House position'),
          avatar: const Icon(Icons.home_work_outlined, size: 16),
          selected: showHousePos,
          onSelected: (v) => ref.read(housePosToggle.notifier).state = v,
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
