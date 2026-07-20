// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import 'labeled_dropdown.dart';

/// Ayanamsa mode dropdown (SE_SIDM_* constants).
///
/// Disabled when zodiac is tropical (ayanamsa is forced to "None").
/// When sidereal, offers the full SE_SIDM_* catalog.
class AyanamsaSelector extends ConsumerWidget {
  const AyanamsaSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayanamsa = ref.watch(contextBarProvider.select((s) => s.ayanamsa));
    final isTropical = ref.watch(
      contextBarProvider.select((s) => s.zodiacRef == ZodiacRef.tropical),
    );

    final ids = <int>[ayanamsaTropicalId, ...ayanamsaCatalog.map((e) => e.id)];

    return LabeledDropdown<int>(
      label: 'Ayanamsa',
      value: ayanamsa,
      items: ids,
      itemLabel: (id) =>
          id == ayanamsaTropicalId ? 'None (Tropical)' : ayanamsaName(id),
      onChanged: isTropical
          ? null
          : (v) async {
              if (v == ayanamsaUserId) {
                final ok = await _promptUserAyanamsa(context, ref);
                if (!ok) return;
              }
              ref.read(contextBarProvider.notifier).setAyanamsa(v);
            },
    );
  }

  Future<bool> _promptUserAyanamsa(BuildContext context, WidgetRef ref) async {
    final state = ref.read(contextBarProvider);
    final t0Ctrl = TextEditingController(text: state.userAyanT0.toString());
    final valCtrl = TextEditingController(text: state.userAyanValue.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                labelText: 't0 (reference Julian Day UT)',
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
                  .setUserAyanamsa(t0: t0, value: val);
              Navigator.of(ctx).pop(true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
