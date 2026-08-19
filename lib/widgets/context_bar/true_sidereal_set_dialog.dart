// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/true_sidereal.dart';
import '../star_search_field.dart';

/// Create and manage True Sidereal sets from the context bar's Signs selector.
///
/// A True Sidereal set is a full boundary-star assignment (which catalog star is
/// each of the 13 constellations' first/last edge) plus editable constellation
/// names. The sign-names' 12-name sets have their own dialog
/// ([showUserSignSetDialog]); this is the 13-constellation, boundary-star
/// counterpart, and mirrors its two-tab shape:
///
///   * **New** — an optional set name and the 13 constellations, pre-filled with
///     Chimenti's default (names + 26 edge stars). Each edge star is chosen from
///     the fixed-star catalog. On *Add* the set joins the app-wide list and
///     becomes the active set.
///   * **Manage** — every existing set as an expandable editor: rename, re-pick
///     edge stars, rename constellations (committed live), mark active, or
///     delete.
///
/// [initialTab] selects which tab opens (0 = New, 1 = Manage). Returns true only
/// when a set was added.
Future<bool> showTrueSiderealSetDialog(
  BuildContext context,
  WidgetRef ref, {
  int initialTab = 0,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _TrueSiderealDialog(initialTab: initialTab),
  );
  return result ?? false;
}

class _TrueSiderealDialog extends ConsumerStatefulWidget {
  const _TrueSiderealDialog({required this.initialTab});

  final int initialTab;

  @override
  ConsumerState<_TrueSiderealDialog> createState() =>
      _TrueSiderealDialogState();
}

class _TrueSiderealDialogState extends ConsumerState<_TrueSiderealDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  )..addListener(() => setState(() {}));

  // New-tab working state: an optional name plus the 13 constellations,
  // seeded from the Chimenti default.
  String? _newName;
  late List<TrueSiderealConstellation> _newConstellations =
      defaultTrueSiderealSet().constellations;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _addNew() {
    final id = ref
        .read(userTrueSiderealSetsProvider.notifier)
        .add(name: _newName, constellations: _newConstellations);
    ref.read(activeTrueSiderealSetIdProvider.notifier).select(id);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final sets = ref.watch(userTrueSiderealSetsProvider);
    final onNewTab = _tabs.index == 0;

    return AlertDialog(
      title: const Text('True Sidereal sets'),
      content: SizedBox(
        width: 420,
        height: MediaQuery.of(context).size.height * 0.7,
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
    return _ConstellationSetEditor(
      // Key so the editor is rebuilt fresh if the default ever changes; a
      // constant key keeps its own controllers alive across dialog rebuilds.
      key: const ValueKey('new'),
      initialName: null,
      initialConstellations: defaultTrueSiderealSet().constellations,
      intro:
          'The 13 constellations in ecliptic order and their two edge (boundary) '
          'stars. Boundaries are the midpoints of adjacent edge stars, computed '
          'at the chart date. Pre-filled with Chimenti\'s default.',
      onChanged: (name, cons) {
        _newName = name;
        _newConstellations = cons;
      },
    );
  }

  Widget _buildManageTab(List<TrueSiderealSet> sets) {
    if (sets.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Text(
          'No True Sidereal sets yet.\nCreate one on the New tab.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final activeId = ref.watch(activeTrueSiderealSetIdProvider);
    final active = ref.watch(activeTrueSiderealSetProvider);
    return ListView(
      children: [
        for (var i = 0; i < sets.length; i++)
          _ManageSetTile(
            key: ValueKey(sets[i].id),
            entry: sets[i],
            index: i,
            isActive: sets[i].id == (activeId ?? active?.id),
          ),
      ],
    );
  }
}

/// One expandable row on the Manage tab: mark active, rename, re-pick edge
/// stars/constellation names (live-committed), or delete.
class _ManageSetTile extends ConsumerWidget {
  const _ManageSetTile({
    super.key,
    required this.entry,
    required this.index,
    required this.isActive,
  });

  final TrueSiderealSet entry;
  final int index;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text(
              trueSiderealSetLabel(entry, index),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                'active',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => ref
                  .read(activeTrueSiderealSetIdProvider.notifier)
                  .select(entry.id),
              child: const Text('Use'),
            ),
        ],
      ),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        _ConstellationSetEditor(
          initialName: entry.name,
          initialConstellations: entry.constellations,
          onChanged: (name, cons) => ref
              .read(userTrueSiderealSetsProvider.notifier)
              .update(entry.id, name: name, constellations: cons),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: () => ref
                .read(userTrueSiderealSetsProvider.notifier)
                .removeById(entry.id),
          ),
        ),
      ],
    );
  }
}

/// Editor for one set's payload: an optional name and the 13 constellations,
/// each with an editable name and two edge-star pickers. Reports the whole
/// payload through [onChanged] on every edit, so the New tab can read the latest
/// and the Manage tab can commit live.
class _ConstellationSetEditor extends StatefulWidget {
  const _ConstellationSetEditor({
    super.key,
    required this.initialName,
    required this.initialConstellations,
    required this.onChanged,
    this.intro,
  });

  final String? initialName;
  final List<TrueSiderealConstellation> initialConstellations;
  final void Function(String? name, List<TrueSiderealConstellation> cons)
  onChanged;
  final String? intro;

  @override
  State<_ConstellationSetEditor> createState() =>
      _ConstellationSetEditorState();
}

class _ConstellationSetEditorState extends State<_ConstellationSetEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? '',
  );
  late final List<TrueSiderealConstellation> _cons = [
    ...widget.initialConstellations,
  ];
  late final List<TextEditingController> _nameCtrls = [
    for (final c in _cons) TextEditingController(text: c.name),
  ];

  @override
  void dispose() {
    _name.dispose();
    for (final c in _nameCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final name = _name.text.trim();
    widget.onChanged(name.isEmpty ? null : name, List.of(_cons));
  }

  void _setFirst(int i, String star) {
    setState(() => _cons[i] = _cons[i].copyWith(firstStar: star));
    _emit();
  }

  void _setLast(int i, String star) {
    setState(() => _cons[i] = _cons[i].copyWith(lastStar: star));
    _emit();
  }

  void _setName(int i, String name) {
    _cons[i] = _cons[i].copyWith(
      name: name.trim().isEmpty ? _cons[i].name : name,
    );
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.intro != null) ...[
            Text(widget.intro!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Set name (optional)',
              helperText: 'Left blank, it is numbered "True Sidereal set N"',
              isDense: true,
            ),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _cons.length; i++)
            _ConstellationRow(
              nameController: _nameCtrls[i],
              constellation: _cons[i],
              onName: (v) => _setName(i, v),
              onFirst: (s) => _setFirst(i, s),
              onLast: (s) => _setLast(i, s),
            ),
        ],
      ),
    );
  }
}

/// One constellation: editable name and its first/last edge stars, each shown
/// with the current value and a search field to replace it.
class _ConstellationRow extends StatelessWidget {
  const _ConstellationRow({
    required this.nameController,
    required this.constellation,
    required this.onName,
    required this.onFirst,
    required this.onLast,
  });

  final TextEditingController nameController;
  final TrueSiderealConstellation constellation;
  final ValueChanged<String> onName;
  final ValueChanged<String> onFirst;
  final ValueChanged<String> onLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(constellation.name, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        'first ${constellation.firstStar} · last ${constellation.lastStar}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Constellation name',
            isDense: true,
          ),
          onChanged: onName,
        ),
        const SizedBox(height: 8),
        _EdgeStarPicker(
          label: 'First edge star (lower longitude)',
          current: constellation.firstStar,
          onSelect: onFirst,
        ),
        const SizedBox(height: 8),
        _EdgeStarPicker(
          label: 'Last edge star (higher longitude)',
          current: constellation.lastStar,
          onSelect: onLast,
        ),
      ],
    );
  }
}

class _EdgeStarPicker extends StatelessWidget {
  const _EdgeStarPicker({
    required this.label,
    required this.current,
    required this.onSelect,
  });

  final String label;
  final String current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label — current: $current',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        StarSearchField(dense: true, onSelect: onSelect),
      ],
    );
  }
}
