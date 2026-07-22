// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';

/// Chip row for choosing which quantities a series grid shows.
///
/// [labels] are field labels taken from the tab's own `ExportRow`s, so the
/// picker knows nothing about any tab: adding a quantity to a tab adds a chip
/// here with no change to this widget.
///
/// The selection is expressed as a *hidden* set, which is what makes all-on
/// the default and keeps a quantity added later switched on.
class QuantityPicker extends StatelessWidget {
  const QuantityPicker({
    super.key,
    required this.labels,
    required this.hiddenLabels,
    required this.onVisibilityChanged,
  });

  final List<String> labels;
  final Set<String> hiddenLabels;
  final void Function(String label, bool visible) onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('Quantities ', style: labelStyle),
            const SizedBox(width: 4),
            ...labels.map(
              (label) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilterChip(
                  label: Text(label),
                  selected: !hiddenLabels.contains(label),
                  onSelected: (visible) => onVisibilityChanged(label, visible),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
