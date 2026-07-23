// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';

/// Prompt for SE_SIDM_USER (255) parameters: reference Julian day, the
/// ayanamsha value at that day, and the `jdisut` sub-option (t0 is UT rather
/// than TT). Projection (`eclt0` / `ssyplane`) is set separately via the
/// context bar's Projection selector, which applies to any ayanamsha.
///
/// Writes to the context provider and returns true on OK, false on cancel.
/// Shared by the context-bar ayanamsa dropdown and the Ayanamsa tab chip.
Future<bool> showUserAyanamsaDialog(BuildContext context, WidgetRef ref) async {
  final state = ref.read(contextBarProvider);
  final t0Ctrl = TextEditingController(text: state.userAyanT0.toString());
  final valCtrl = TextEditingController(text: state.userAyanValue.toString());
  var t0IsUt = state.userAyanT0IsUt;

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
              controller: t0Ctrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 't0 (reference Julian Day)',
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
              ref
                  .read(contextBarProvider.notifier)
                  .setUserAyanamsa(t0: t0, value: val, t0IsUt: t0IsUt);
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
