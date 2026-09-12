// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';

/// Relocation-mode toggle: when on, changing the location keeps the instant
/// ([ContextBarState.anchorJd]) fixed and re-derives the local clock for the new
/// place, instead of keeping the wall-clock time. Sits by the location fields
/// because that is the action it steers.
class AnchorJdToggle extends ConsumerWidget {
  const AnchorJdToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchorJd = ref.watch(contextBarProvider.select((s) => s.anchorJd));
    final notifier = ref.read(contextBarProvider.notifier);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Tooltip(
      message:
          'Relocation mode.\n'
          'On: changing the place keeps the Julian Day (the instant) fixed and '
          're-derives the local clock for the new place — the angles and house '
          'cusps move, body longitudes stay. A relocation chart.\n'
          'Off: the entered local (wall-clock) time is kept and the instant '
          'moves.',
      child: InkWell(
        onTap: () => notifier.setAnchorJd(!anchorJd),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: anchorJd,
                  onChanged: (v) => notifier.setAnchorJd(v ?? false),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(child: Text('Keep JD when changing location')),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 14, color: onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
