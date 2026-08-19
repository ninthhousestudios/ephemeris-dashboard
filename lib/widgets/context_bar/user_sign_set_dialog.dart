// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sign_names.dart';

/// Create and manage user-defined sign-name sets from the context bar.
///
/// A tabbed popup, sign-names' equivalent of the Ayanamsa tab's user-defined
/// section (there is no Sign-names tab, so the management surface lives here):
///
///   * **New** — an optional set name and the 12 sign names (the equal 30°
///     divisions, index 0 = the 0–30° sign), pre-filled with the zodiac names.
///     A field left blank falls back to its zodiac name so no slot renders
///     empty. On *Add* the set joins the app-wide list and the selection points
///     at it.
///   * **Manage** — every existing set as an expandable editor: rename, re-edit
///     the 12 names (committed live to [UserSignSetNotifier.update]), or delete
///     it ([UserSignSetNotifier.removeById]). Deleting the selected set
///     reconciles the selection back to Zodiac via [signNameSelectionProvider].
///
/// [initialTab] selects which tab opens (0 = New, 1 = Manage). Returns true
/// only when a set was added (the New tab's *Add*); Manage-tab edits apply
/// immediately and return false on close. Mirrors [showUserAyanamsaDialog].
Future<bool> showUserSignSetDialog(
  BuildContext context,
  WidgetRef ref, {
  int initialTab = 0,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _SignSetDialog(initialTab: initialTab),
  );
  return result ?? false;
}

class _SignSetDialog extends ConsumerStatefulWidget {
  const _SignSetDialog({required this.initialTab});

  final int initialTab;

  @override
  ConsumerState<_SignSetDialog> createState() => _SignSetDialogState();
}

class _SignSetDialogState extends ConsumerState<_SignSetDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this, initialIndex: widget.initialTab)
        // The action row differs per tab (Add on New, only Close on Manage), so
        // rebuild when the tab changes.
        ..addListener(() => setState(() {}));

  // New-tab controllers: an optional set name plus the 12 sign names,
  // pre-filled with the zodiac names.
  final TextEditingController _nameCtrl = TextEditingController();
  late final List<TextEditingController> _nameCtrls = [
    for (final n in zodiacNames) TextEditingController(text: n),
  ];

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    for (final c in _nameCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addNew() {
    final names = [
      for (var i = 0; i < 12; i++)
        _nameCtrls[i].text.trim().isEmpty
            ? zodiacNames[i]
            : _nameCtrls[i].text.trim(),
    ];
    final name = _nameCtrl.text.trim();
    final id = ref
        .read(userSignSetsProvider.notifier)
        .add(name: name.isEmpty ? null : name, names: names);
    ref.read(signNameSelectionProvider.notifier).selectUserSet(id);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final sets = ref.watch(userSignSetsProvider);
    final onNewTab = _tabs.index == 0;

    return AlertDialog(
      title: const Text('Sign-name sets'),
      content: SizedBox(
        width: 360,
        // TabBarView needs a bounded height; scale with the screen (not a fixed
        // pixel count) so each tab's own scroll view stays usable under zoom.
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'New'),
                Tab(text: 'Manage'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [_buildNewTab(), _buildManageTab(sets)],
              ),
            ),
          ],
        ),
      ),
      actions: onNewTab
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: _addNew, child: const Text('Add')),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Close'),
              ),
            ],
    );
  }

  Widget _buildNewTab() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '12 names for the equal 30° signs, in order from 0°. Blank '
            'fields fall back to the zodiac name.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Set name (optional)',
              helperText: 'Left blank, it is numbered "Sign set N"',
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < 12; i++) ...[
            TextField(
              controller: _nameCtrls[i],
              decoration: InputDecoration(
                labelText: '${i * 30}°–${(i + 1) * 30}°',
                isDense: true,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildManageTab(List<UserSignSet> sets) {
    if (sets.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Text(
          'No sign-name sets yet.\nCreate one on the New tab.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView(
      children: [
        for (var i = 0; i < sets.length; i++)
          _ManageSetEditor(
            // Key by id so the per-set controllers rebind correctly when the
            // list is reordered by a deletion.
            key: ValueKey(sets[i].id),
            entry: sets[i],
            index: i,
          ),
      ],
    );
  }
}

/// One expandable row on the Manage tab: rename, re-edit the 12 names, or delete
/// an existing [UserSignSet]. Edits commit live to [UserSignSetNotifier.update]
/// on every keystroke (mirroring the Ayanamsa tab's editor), so a chart naming
/// this set updates immediately.
class _ManageSetEditor extends ConsumerStatefulWidget {
  const _ManageSetEditor({super.key, required this.entry, required this.index});

  final UserSignSet entry;
  final int index;

  @override
  ConsumerState<_ManageSetEditor> createState() => _ManageSetEditorState();
}

class _ManageSetEditorState extends ConsumerState<_ManageSetEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.entry.name ?? '',
  );
  late final List<TextEditingController> _names = [
    for (final n in widget.entry.names) TextEditingController(text: n),
  ];

  @override
  void dispose() {
    _name.dispose();
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  void _commit() {
    final name = _name.text.trim();
    final names = [
      for (var i = 0; i < 12; i++)
        _names[i].text.trim().isEmpty ? zodiacNames[i] : _names[i].text.trim(),
    ];
    ref
        .read(userSignSetsProvider.notifier)
        .update(
          widget.entry.id,
          // Blank means "no name": the entry falls back to its numbered label.
          name: name.isEmpty ? null : name,
          names: names,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = userSignSetLabel(widget.entry, widget.index);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(label, style: theme.textTheme.bodyMedium),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Set name (optional)',
            isDense: true,
          ),
          onChanged: (_) => _commit(),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < 12; i++) ...[
          TextField(
            controller: _names[i],
            decoration: InputDecoration(
              labelText: '${i * 30}°–${(i + 1) * 30}°',
              isDense: true,
            ),
            onChanged: (_) => _commit(),
          ),
          const SizedBox(height: 4),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => ref
                .read(userSignSetsProvider.notifier)
                .removeById(widget.entry.id),
          ),
        ),
      ],
    );
  }
}
