// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';

/// Reusable labeled dropdown with consistent layout.
/// Fixed-width label + expanding dropdown, for grid alignment.
class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    super.key,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isDense: true,
                isExpanded: true,
                style: Theme.of(context).textTheme.bodySmall,
                items: items
                    .map(
                      (v) =>
                          DropdownMenuItem(value: v, child: Text(itemLabel(v))),
                    )
                    .toList(),
                onChanged: onChanged == null
                    ? null
                    : (v) {
                        if (v != null) onChanged!(v);
                      },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
