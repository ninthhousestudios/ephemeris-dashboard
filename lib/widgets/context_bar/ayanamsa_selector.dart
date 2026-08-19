// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/user_ayanamsa.dart';
import 'labeled_dropdown.dart';
import 'user_ayanamsa_dialog.dart';

/// One row of the Ayanamsa dropdown: a built-in SE_SIDM_* mode, one of the
/// user-defined ayanamshas (which are ordinary entries here, not a single
/// "User-defined" slot), or the action that defines a new one.
@immutable
class _AyanamsaChoice {
  const _AyanamsaChoice.builtin(this.builtinId)
    : userId = null,
      isAdd = false,
      isMissing = false;

  const _AyanamsaChoice.user(this.userId)
    : builtinId = ayanamsaUserId,
      isAdd = false,
      isMissing = false;

  const _AyanamsaChoice.add()
    : builtinId = ayanamsaUserId,
      userId = null,
      isAdd = true,
      isMissing = false;

  /// The Context selects a user-defined entry that is not in the list — only
  /// reachable from a store written by an older or interrupted run. Shown as
  /// itself rather than silently rendered as some other ayanamsha; picking
  /// anything else clears it.
  const _AyanamsaChoice.missing()
    : builtinId = ayanamsaUserId,
      userId = null,
      isAdd = false,
      isMissing = true;

  final int builtinId;
  final int? userId;
  final bool isAdd;
  final bool isMissing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AyanamsaChoice &&
          builtinId == other.builtinId &&
          userId == other.userId &&
          isAdd == other.isAdd &&
          isMissing == other.isMissing;

  @override
  int get hashCode => Object.hash(builtinId, userId, isAdd, isMissing);
}

/// Ayanamsa mode dropdown (SE_SIDM_* constants).
///
/// Disabled when zodiac is tropical (ayanamsa is forced to "None"). When
/// sidereal, offers the full SE_SIDM_* catalog plus every user-defined
/// ayanamsha — the same list the Ayanamsa tab edits, so one defined in either
/// place is selectable here (swe-dashboard/96).
class AyanamsaSelector extends ConsumerWidget {
  const AyanamsaSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ayanamsa = ref.watch(contextBarProvider.select((s) => s.ayanamsa));
    final userAyanId = ref.watch(
      contextBarProvider.select((s) => s.userAyanId),
    );
    final isTropical = ref.watch(
      contextBarProvider.select((s) => s.zodiacRef == ZodiacRef.tropical),
    );
    final entries = ref.watch(userAyanamsasProvider);

    final selectedUser = ayanamsa == ayanamsaUserId
        ? resolveUserAyanamsa(entries, userAyanId)
        : null;
    final isDangling = ayanamsa == ayanamsaUserId && selectedUser == null;

    final labels = <int, String>{
      for (var i = 0; i < entries.length; i++)
        entries[i].id: userAyanamsaLabel(entries[i], i),
    };

    final choices = <_AyanamsaChoice>[
      const _AyanamsaChoice.builtin(ayanamsaTropicalId),
      for (final e in ayanamsaCatalog)
        if (e.id != ayanamsaUserId) _AyanamsaChoice.builtin(e.id),
      for (final p in ayanamsaPresets) _AyanamsaChoice.builtin(p.id),
      for (final e in entries) _AyanamsaChoice.user(e.id),
      if (isDangling) const _AyanamsaChoice.missing(),
      const _AyanamsaChoice.add(),
    ];

    return LabeledDropdown<_AyanamsaChoice>(
      label: 'Ayanamsa',
      value: switch ((selectedUser, isDangling)) {
        (final u?, _) => _AyanamsaChoice.user(u.id),
        (_, true) => const _AyanamsaChoice.missing(),
        _ => _AyanamsaChoice.builtin(ayanamsa),
      },
      items: choices,
      itemLabel: (c) {
        if (c.isAdd) return 'Add user-defined…';
        if (c.isMissing) return 'User-defined (missing)';
        final userId = c.userId;
        if (userId != null) return labels[userId] ?? 'User-defined';
        return c.builtinId == ayanamsaTropicalId
            ? 'None (Tropical)'
            : ayanamsaName(c.builtinId);
      },
      onChanged: isTropical
          ? null
          : (c) async {
              if (c.isAdd) {
                // The dialog adds the entry and selects it.
                await showUserAyanamsaDialog(context, ref);
                return;
              }
              if (c.isMissing) return;
              final userId = c.userId;
              final notifier = ref.read(contextBarProvider.notifier);
              if (userId != null) {
                notifier.selectUserAyanamsa(userId);
              } else {
                notifier.setAyanamsa(c.builtinId);
              }
            },
    );
  }
}
