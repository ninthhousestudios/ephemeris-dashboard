// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/sign_names.dart';
import 'user_sign_set_dialog.dart';

/// One row of the Sign Names dropdown: a built-in [SignScheme], one of the
/// user-defined sign sets, the action that defines a new one, or the action
/// that opens the manage surface for the existing ones.
@immutable
class _SchemeChoice {
  const _SchemeChoice.scheme(this.scheme)
    : userSetId = null,
      isAdd = false,
      isManage = false;

  const _SchemeChoice.user(this.userSetId)
    : scheme = SignScheme.userDefined,
      isAdd = false,
      isManage = false;

  const _SchemeChoice.add()
    : scheme = SignScheme.userDefined,
      userSetId = null,
      isAdd = true,
      isManage = false;

  const _SchemeChoice.manage()
    : scheme = SignScheme.userDefined,
      userSetId = null,
      isAdd = false,
      isManage = true;

  final SignScheme scheme;
  final int? userSetId;
  final bool isAdd;
  final bool isManage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SchemeChoice &&
          scheme == other.scheme &&
          userSetId == other.userSetId &&
          isAdd == other.isAdd &&
          isManage == other.isManage;

  @override
  int get hashCode => Object.hash(scheme, userSetId, isAdd, isManage);
}

/// Sign-name mode selector: a pure display concern, sibling to the Clock and
/// Calendar selectors. None / Zodiac / Aditya, then every user-defined set,
/// then "Add sign-name set…". True Sidereal appears greyed until a True
/// Sidereal Context unlocks it (rendering lands in swe-dashboard/102).
class SignNameSelector extends ConsumerWidget {
  const SignNameSelector({super.key});

  static const _trueSiderealTooltip =
      'Unlocks under Zodiac: Sidereal + Ayanamsa: True Sidereal';
  static const _adityaTooltip = 'Unlocks under Zodiac: Tropical';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(signNameSelectionProvider);
    final sets = ref.watch(userSignSetsProvider);
    final zodiac = ref.watch(contextBarProvider.select((s) => s.zodiacRef));
    final ayanamsa = ref.watch(contextBarProvider.select((s) => s.ayanamsa));
    // Aditya is a tropical relabelling; True Sidereal needs its own ayanamsha.
    final canAditya = zodiac == ZodiacRef.tropical;
    final canTrueSidereal =
        zodiac == ZodiacRef.sidereal && ayanamsa == ayanamsaTrueSiderealId;

    final labels = <int, String>{
      for (var i = 0; i < sets.length; i++)
        sets[i].id: userSignSetLabel(sets[i], i),
    };

    // The selected user set, resolved. Null when the selection is not
    // user-defined, or (briefly, pre-reconcile) points at a removed set — in
    // which case the dropdown shows Zodiac rather than an absent value.
    final selectedUser = sel.scheme == SignScheme.userDefined
        ? resolveUserSignSet(sets, sel.userSetId)
        : null;
    final value = selectedUser != null
        ? _SchemeChoice.user(selectedUser.id)
        : _SchemeChoice.scheme(
            sel.scheme == SignScheme.userDefined
                ? SignScheme.zodiac
                : sel.scheme,
          );

    final theme = Theme.of(context);

    final items = <DropdownMenuItem<_SchemeChoice>>[
      _item(theme, const _SchemeChoice.scheme(SignScheme.none), 'None'),
      _item(theme, const _SchemeChoice.scheme(SignScheme.zodiac), 'Zodiac'),
      _item(
        theme,
        const _SchemeChoice.scheme(SignScheme.aditya),
        'Aditya',
        enabled: canAditya,
        disabledTooltip: _adityaTooltip,
      ),
      _item(
        theme,
        const _SchemeChoice.scheme(SignScheme.trueSidereal),
        'True Sidereal',
        enabled: canTrueSidereal,
        disabledTooltip: _trueSiderealTooltip,
      ),
      for (final s in sets)
        _item(theme, _SchemeChoice.user(s.id), labels[s.id] ?? 'Sign set'),
      _item(theme, const _SchemeChoice.add(), 'Add sign-name set…'),
      // Manage (rename/edit/delete) only makes sense once a set exists.
      if (sets.isNotEmpty)
        _item(theme, const _SchemeChoice.manage(), 'Manage sign-name sets…'),
    ];

    return Row(
      children: [
        Text(
          'Signs ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
              child: DropdownButton<_SchemeChoice>(
                value: value,
                isDense: true,
                isExpanded: true,
                style: theme.textTheme.bodySmall,
                items: items,
                onChanged: (c) async {
                  if (c == null) return;
                  if (c.isAdd) {
                    // The dialog adds the set and selects it.
                    await showUserSignSetDialog(context, ref);
                    return;
                  }
                  if (c.isManage) {
                    // Same dialog, opened on the Manage tab; edits/deletes
                    // apply live and the selection is left as-is.
                    await showUserSignSetDialog(context, ref, initialTab: 1);
                    return;
                  }
                  final notifier = ref.read(signNameSelectionProvider.notifier);
                  final userId = c.userSetId;
                  if (userId != null) {
                    notifier.selectUserSet(userId);
                  } else {
                    notifier.selectScheme(c.scheme);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  DropdownMenuItem<_SchemeChoice> _item(
    ThemeData theme,
    _SchemeChoice choice,
    String label, {
    bool enabled = true,
    String? disabledTooltip,
  }) {
    Widget child = Text(label);
    if (!enabled) {
      child = Text(label, style: TextStyle(color: theme.disabledColor));
      if (disabledTooltip != null) {
        child = Tooltip(message: disabledTooltip, child: child);
      }
    }
    return DropdownMenuItem<_SchemeChoice>(
      value: choice,
      enabled: enabled,
      child: child,
    );
  }
}
