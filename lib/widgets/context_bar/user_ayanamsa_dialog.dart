// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/user_ayanamsa.dart';

/// Define a new user-defined ayanamsha (SE_SIDM_USER, 255) from the context
/// bar: an optional name, a reference Julian day, the ayanamsha value at that
/// day, and the `jdisut` sub-option (t0 is UT rather than TT). Projection
/// (`eclt0` / `ssyplane`) is set separately via the context bar's Projection
/// selector, which applies to any ayanamsha.
///
/// The entry goes into the same list the Ayanamsa tab edits, and on OK the
/// Context selects it. Returns true on OK, false on cancel.
Future<bool> showUserAyanamsaDialog(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final t0Ctrl = TextEditingController(
    text: const UserAyanamsa(id: 0).t0.toString(),
  );
  final valCtrl = TextEditingController(text: '0.0');
  var t0IsUt = false;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('User-defined Ayanamsa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SE_SIDM_USER (255): ayanamsa specified by a reference '
              'Julian day and the ayanamsa value at that day.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                helperText: 'Left blank, it is numbered "User-defined N"',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: t0Ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              // Tracks the checkbox below, which is the only thing that
              // decides how the engine reads this number.
              decoration: InputDecoration(
                labelText: 't0 (reference Julian Day, ${t0IsUt ? 'UT' : 'TT'})',
                helperText: 'e.g. 2451545.0 for J2000',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'ayanamsa at t0 (degrees)',
              ),
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: t0IsUt,
              onChanged: (v) => setState(() => t0IsUt = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('t0 is UT (jdisut)'),
              subtitle: const Text(
                'Interpret t0 as Universal Time rather than Terrestrial Time',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This ayanamsha can be renamed, edited or deleted on the '
              'Ayanamsa tab, where it is also compared against the built-in '
              'modes.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final t0 = double.tryParse(t0Ctrl.text);
              final val = double.tryParse(valCtrl.text);
              if (t0 == null || val == null) {
                Navigator.of(ctx).pop(false);
                return;
              }
              final name = nameCtrl.text.trim();
              final id = ref
                  .read(userAyanamsasProvider.notifier)
                  .add(
                    name: name.isEmpty ? null : name,
                    t0: t0,
                    value: val,
                    t0IsUt: t0IsUt,
                  );
              ref.read(contextBarProvider.notifier).selectUserAyanamsa(id);
              Navigator.of(ctx).pop(true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
