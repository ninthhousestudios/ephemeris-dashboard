import 'package:flutter/material.dart';

import '../../core/flag_definitions.dart';

/// A mutually exclusive group of flag options displayed as ChoiceChips.
class FlagGroupWidget extends StatelessWidget {
  const FlagGroupWidget({
    super.key,
    required this.group,
    required this.selectedValue,
    required this.onSelected,
  });

  final FlagGroup group;
  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${group.label}:',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        ...group.members.map(
          (m) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Tooltip(
              message: m.tooltip,
              child: ChoiceChip(
                label: Text(m.label),
                selected: selectedValue == m.value,
                onSelected: (_) => onSelected(m.value),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
