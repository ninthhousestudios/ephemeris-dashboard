// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';

import '../../core/flag_definitions.dart';
import 'flag_toggle.dart';

/// A labeled cluster of independent (non-exclusive) flag toggles.
///
/// Unlike [FlagGroupWidget] (mutually exclusive ChoiceChips), every member is
/// an independent [FlagToggle]; the label just visually groups related flags,
/// e.g. the position corrections. Rendered as a single non-wrapping [Row] so
/// the label stays attached to its chips — the flag bar scrolls horizontally.
class FlagToggleGroup extends StatelessWidget {
  const FlagToggleGroup({
    super.key,
    required this.label,
    required this.defs,
    required this.activeValues,
    required this.onToggle,
  });

  final String label;
  final List<FlagDef> defs;
  final Set<int> activeValues;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        ...defs.map(
          (def) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FlagToggle(
              def: def,
              active: activeValues.contains(def.value),
              onToggle: () => onToggle(def.value),
            ),
          ),
        ),
      ],
    );
  }
}
