// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ayanamsa_catalog.dart';
import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/sign_names.dart';
import '../../core/true_sidereal.dart';
import 'true_sidereal_set_dialog.dart';
import 'user_sign_set_dialog.dart';

/// One row of the Sign Names dropdown: a built-in [SignScheme], one of the
/// user-defined 12-name sets (or the actions to add/manage them), or one of the
/// True Sidereal sets (or the action to manage them).
@immutable
class _SchemeChoice {
  const _SchemeChoice.scheme(this.scheme)
    : userSetId = null,
      trueSetId = null,
      isAdd = false,
      isManage = false,
      isManageTrue = false;

  const _SchemeChoice.user(this.userSetId)
    : scheme = SignScheme.userDefined,
      trueSetId = null,
      isAdd = false,
      isManage = false,
      isManageTrue = false;

  const _SchemeChoice.add()
    : scheme = SignScheme.userDefined,
      userSetId = null,
      trueSetId = null,
      isAdd = true,
      isManage = false,
      isManageTrue = false;

  const _SchemeChoice.manage()
    : scheme = SignScheme.userDefined,
      userSetId = null,
      trueSetId = null,
      isAdd = false,
      isManage = true,
      isManageTrue = false;

  const _SchemeChoice.trueSidereal(this.trueSetId)
    : scheme = SignScheme.trueSidereal,
      userSetId = null,
      isAdd = false,
      isManage = false,
      isManageTrue = false;

  const _SchemeChoice.manageTrue()
    : scheme = SignScheme.trueSidereal,
      userSetId = null,
      trueSetId = null,
      isAdd = false,
      isManage = false,
      isManageTrue = true;

  final SignScheme scheme;
  final int? userSetId;
  final int? trueSetId;
  final bool isAdd;
  final bool isManage;
  final bool isManageTrue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SchemeChoice &&
          scheme == other.scheme &&
          userSetId == other.userSetId &&
          trueSetId == other.trueSetId &&
          isAdd == other.isAdd &&
          isManage == other.isManage &&
          isManageTrue == other.isManageTrue;

  @override
  int get hashCode =>
      Object.hash(scheme, userSetId, trueSetId, isAdd, isManage, isManageTrue);
}

/// Sign-name mode selector: a pure display concern, sibling to the Clock and
/// Calendar selectors. None / Zodiac / Aditya, the True Sidereal sets (greyed
/// until a True Sidereal Context unlocks them), then the user-defined 12-name
/// sets and their add/manage actions.
class SignNameSelector extends ConsumerWidget {
  const SignNameSelector({super.key});

  static const _trueSiderealTooltip =
      'Unlocks under Zodiac: Sidereal + Ayanamsa: True Sidereal';
  static const _adityaTooltip = 'Unlocks under Zodiac: Tropical';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(signNameSelectionProvider);
    final sets = ref.watch(userSignSetsProvider);
    final trueSets = ref.watch(userTrueSiderealSetsProvider);
    final activeTrue = ref.watch(activeTrueSiderealSetProvider);
    final zodiac = ref.watch(contextBarProvider.select((s) => s.zodiacRef));
    final ayanamsa = ref.watch(contextBarProvider.select((s) => s.ayanamsa));
    // Aditya is a tropical relabelling; True Sidereal needs its own ayanamsha.
    final canAditya = zodiac == ZodiacRef.tropical;
    final canTrueSidereal =
        zodiac == ZodiacRef.sidereal && ayanamsa == ayanamsaTrueSiderealId;

    // A boundary star that would not resolve at the chart date: surface it here
    // (the mode's own control) rather than repeating it on every card. Only
    // meaningful while True Sidereal is the chosen mode and unlocked.
    final binningError =
        (sel.scheme == SignScheme.trueSidereal && canTrueSidereal)
        ? ref.watch(trueSiderealBinningProvider).error
        : null;

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
    final _SchemeChoice value;
    if (selectedUser != null) {
      value = _SchemeChoice.user(selectedUser.id);
    } else if (sel.scheme == SignScheme.trueSidereal && activeTrue != null) {
      value = _SchemeChoice.trueSidereal(activeTrue.id);
    } else {
      value = _SchemeChoice.scheme(
        sel.scheme == SignScheme.userDefined ||
                sel.scheme == SignScheme.trueSidereal
            ? SignScheme.zodiac
            : sel.scheme,
      );
    }

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
      for (var i = 0; i < trueSets.length; i++)
        _item(
          theme,
          _SchemeChoice.trueSidereal(trueSets[i].id),
          'True Sidereal · ${trueSiderealSetLabel(trueSets[i], i)}',
          enabled: canTrueSidereal,
          disabledTooltip: _trueSiderealTooltip,
        ),
      for (final s in sets)
        _item(theme, _SchemeChoice.user(s.id), labels[s.id] ?? 'Sign set'),
      // Actions last: add, then the two manage entries — sign-name sets, then
      // True Sidereal sets at the very bottom.
      _item(theme, const _SchemeChoice.add(), 'Add sign-name set…'),
      // Manage (rename/edit/delete) only makes sense once a set exists.
      if (sets.isNotEmpty)
        _item(theme, const _SchemeChoice.manage(), 'Manage sign-name sets…'),
      _item(
        theme,
        const _SchemeChoice.manageTrue(),
        'Manage True Sidereal sets…',
      ),
    ];

    final row = Row(
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
                  if (c.isManageTrue) {
                    // True Sidereal sets have their own dialog (boundary stars +
                    // 13 constellation names). Open it on Manage.
                    await showTrueSiderealSetDialog(
                      context,
                      ref,
                      initialTab: 1,
                    );
                    return;
                  }
                  final notifier = ref.read(signNameSelectionProvider.notifier);
                  final userId = c.userSetId;
                  final trueId = c.trueSetId;
                  if (userId != null) {
                    notifier.selectUserSet(userId);
                  } else if (trueId != null) {
                    // The set-id selection lives in its own provider; the scheme
                    // selection just records that True Sidereal is chosen.
                    ref
                        .read(activeTrueSiderealSetIdProvider.notifier)
                        .select(trueId);
                    notifier.selectScheme(SignScheme.trueSidereal);
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

    if (binningError == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            binningError,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
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
