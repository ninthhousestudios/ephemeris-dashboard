// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import 'labeled_dropdown.dart';
import 'user_ayanamsa_dialog.dart';

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
                final ok = await showUserAyanamsaDialog(context, ref);
                if (!ok) return;
              }
              ref.read(contextBarProvider.notifier).setAyanamsa(v);
            },
    );
  }
}
