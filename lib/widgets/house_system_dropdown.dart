// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/house_systems.dart';
import '../core/persistence.dart';

/// The single app-wide house-system selector, driving
/// [selectedHouseSystemProvider] and persisting the choice.
///
/// One widget so the Houses tab and the body tabs (which show each body's house
/// position, swe-dashboard/58) present the same control and stay in agreement.
class HouseSystemDropdown extends ConsumerWidget {
  const HouseSystemDropdown({super.key, this.width = 240});

  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hsys = ref.watch(selectedHouseSystemProvider);

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<int>(
        initialValue: hsys,
        isDense: true,
        isExpanded: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          border: OutlineInputBorder(),
        ),
        items: houseSystems
            .map(
              (h) => DropdownMenuItem(
                value: h.code,
                child: Text(
                  '${h.char} — ${h.label}',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) {
            ref.read(selectedHouseSystemProvider.notifier).state = v;
            ref.read(persistenceProvider).saveHouseSystem(v);
          }
        },
      ),
    );
  }
}
