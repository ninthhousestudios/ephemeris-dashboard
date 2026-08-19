// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../core/user_ayanamsa.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../../widgets/result_card_grid.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import 'ayanamsa_provider.dart';

/// The engine mode token shown for a result. Presets carry a negative
/// pseudo-id but run under SE_SIDM_USER, so they read as `USER`, not the id.
String _sidModeLabel(int sidMode) => sidMode < 0 ? 'USER' : '$sidMode';

class AyanamsaTab extends ConsumerStatefulWidget {
  const AyanamsaTab({super.key});

  @override
  ConsumerState<AyanamsaTab> createState() => _AyanamsaTabState();
}

class _AyanamsaTabState extends ConsumerState<AyanamsaTab> {
  void _toggleAyanamsa(int sidMode) {
    final current = ref.read(selectedAyanamsasProvider);
    final updated = current.contains(sidMode)
        ? current.where((m) => m != sidMode).toList()
        : [...current, sidMode];
    ref.read(selectedAyanamsasProvider.notifier).state = updated;
  }

  /// Remove a result card: user-defined entries (userId set) drop from the
  /// user list; built-in entries toggle out of the selection.
  void _removeResult(AyanamsaCalcResult r) {
    if (r.userId != null) {
      ref.read(userAyanamsasProvider.notifier).removeById(r.userId!);
    } else {
      _toggleAyanamsa(r.sidMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compareMode = ref.watch(ayanamsaCompareModeProvider);
    final selected = ref.watch(selectedAyanamsasProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text('Mode:', style: theme.textTheme.labelMedium),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Select')),
                        ButtonSegment(value: true, label: Text('Compare All')),
                      ],
                      selected: {compareMode},
                      onSelectionChanged: (s) =>
                          ref.read(ayanamsaCompareModeProvider.notifier).state =
                              s.first,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final fmt = ref.watch(ayanamsaFormatProvider);
                        return SegmentedButton<DisplayFormat>(
                          segments: DisplayFormat.values
                              .map(
                                (f) => ButtonSegment(
                                  value: f,
                                  label: Text(f.label),
                                ),
                              )
                              .toList(),
                          selected: {fmt},
                          onSelectionChanged: (s) =>
                              ref.read(ayanamsaFormatProvider.notifier).state =
                                  s.first,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final results = switch (ref.watch(
                          ayanamsaResultsProvider,
                        )) {
                          CalcOk(:final value) => value,
                          CalcError() => const <AyanamsaCalcResult>[],
                        };
                        final fmt = ref.watch(ayanamsaFormatProvider);
                        final jd = ref.watch(contextBarProvider).jdUt;
                        return ExportButton(
                          hasResults: results.isNotEmpty,
                          getRows: () => ayanamsaToExportRows(results, fmt),
                          filenameStem: 'swe_ayanamsa_${jd.toStringAsFixed(4)}',
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (!compareMode) ...[
                const SizedBox(height: 6),
                // Ayanamsa selector chips — scrollable with constrained height.
                // User-defined is an "add" action (bottom), not a toggle: each
                // press appends an independently editable entry below.
                Consumer(
                  builder: (context, ref, _) {
                    final modes = ayanamsaModesFor();
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final e in modes.entries)
                              FilterChip(
                                label: Text(
                                  e.value,
                                  style: theme.textTheme.labelSmall,
                                ),
                                selected: selected.contains(e.key),
                                onSelected: (_) => _toggleAyanamsa(e.key),
                                visualDensity: VisualDensity.compact,
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: Text(
                                'User-defined',
                                style: theme.textTheme.labelSmall,
                              ),
                              onPressed: () => ref
                                  .read(userAyanamsasProvider.notifier)
                                  .add(),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Inline editors for each user-defined entry.
                Consumer(
                  builder: (context, ref, _) {
                    final users = ref.watch(userAyanamsasProvider);
                    if (users.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'These are the same user-defined ayanamshas the '
                            'context bar offers — one defined there is editable '
                            'here, and one defined here is selectable there.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          for (var i = 0; i < users.length; i++)
                            _UserAyanamsaEditor(
                              key: ValueKey(users[i].id),
                              entry: users[i],
                              fallbackName: 'User-defined ${i + 1}',
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        SeriesBar(tabId: AppTab.ayanamsa.name),
        const Divider(height: 1),
        // Results
        if (ref.watch(
          seriesSettingsProvider(AppTab.ayanamsa.name).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          _buildResults(),
      ],
    );
  }

  Widget _buildSeries() {
    final format = ref.watch(ayanamsaFormatProvider);
    final steps = ref.watch(ayanamsaSeriesProvider);

    List<ExportRow> rows(List<AyanamsaCalcResult> results) =>
        ayanamsaToExportRows(results, format);

    return SeriesView(
      tabId: AppTab.ayanamsa.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
    );
  }

  Widget _buildResults() {
    final format = ref.watch(ayanamsaFormatProvider);
    final results = switch (ref.watch(ayanamsaResultsProvider)) {
      CalcOk(:final value) => value,
      CalcError() => const <AyanamsaCalcResult>[],
    };

    if (results.isEmpty) {
      return const Center(child: Text('No results'));
    }

    final compareMode = ref.watch(ayanamsaCompareModeProvider);

    // In compare mode, show a compact table instead of cards.
    if (compareMode) {
      return _buildCompareTable(results);
    }

    return ResultCardGrid<AyanamsaCalcResult>.items(
      items: results,
      emptyMessage: 'No results',
      cardOverlay: (i) => IconButton(
        icon: const Icon(Icons.close, size: 16),
        tooltip: 'Remove ${results[i].name}',
        visualDensity: VisualDensity.compact,
        onPressed: () => _removeResult(results[i]),
      ),
      cardBuilder: (r) => ResultCard(
        title: r.name,
        subtitle: 'SE_SIDM_${_sidModeLabel(r.sidMode)}',
        fields: [
          ResultField(
            label: 'Value',
            value: formatAngle(r.value, format),
            rawValue: r.value,
          ),
        ],
      ),
    );
  }

  Widget _buildCompareTable(List<AyanamsaCalcResult> results) {
    final format = ref.watch(ayanamsaFormatProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 36,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 32,
        columns: const [
          DataColumn(label: Text('#')),
          DataColumn(label: Text('Ayanamsa')),
          DataColumn(label: Text('Value'), numeric: true),
        ],
        rows: results.map((r) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  _sidModeLabel(r.sidMode),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              DataCell(Text(r.name, style: theme.textTheme.bodySmall)),
              DataCell(
                SelectableText(
                  formatAngle(r.value, format),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/// Inline editor for one user-defined ayanamsha: optional name, reference JD,
/// value at t0, the `jdisut` (t0-is-UT) checkbox, and a remove button. Edits
/// flow straight to [userAyanamsasProvider], so both the compared value here
/// and any chart selecting this entry update live. Horizontally scrollable so
/// the row never overflows at high zoom.
///
/// Labels sit *beside* their boxes rather than inside them as `labelText`: a
/// floating label is laid out against the field's own width, so on a narrow
/// phone it was the label that got clipped, not the field (swe-dashboard/96).
class _UserAyanamsaEditor extends ConsumerStatefulWidget {
  const _UserAyanamsaEditor({
    super.key,
    required this.entry,
    required this.fallbackName,
  });

  final UserAyanamsa entry;

  /// Shown as the name field's placeholder, and used for the remove tooltip,
  /// when the entry has no name of its own.
  final String fallbackName;

  @override
  ConsumerState<_UserAyanamsaEditor> createState() =>
      _UserAyanamsaEditorState();
}

class _UserAyanamsaEditorState extends ConsumerState<_UserAyanamsaEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.entry.name ?? '',
  );
  late final TextEditingController _t0 = TextEditingController(
    text: widget.entry.t0.toString(),
  );
  late final TextEditingController _val = TextEditingController(
    text: widget.entry.value.toString(),
  );

  @override
  void dispose() {
    _name.dispose();
    _t0.dispose();
    _val.dispose();
    super.dispose();
  }

  void _commit() {
    final name = _name.text.trim();
    ref
        .read(userAyanamsasProvider.notifier)
        .update(
          widget.entry.id,
          // Blank means "no name": the entry falls back to its numbered label
          // rather than showing an empty one.
          name: name.isEmpty ? null : name,
          t0: double.tryParse(_t0.text),
          value: double.tryParse(_val.text),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final fieldWidth = (150 * scale).floorToDouble();
    final notifier = ref.read(userAyanamsasProvider.notifier);

    Widget field(
      TextEditingController c,
      String label, {
      String? hint,
      bool numeric = true,
    }) => Row(
      children: [
        Text('$label:', style: theme.textTheme.labelSmall),
        const SizedBox(width: 4),
        SizedBox(
          width: fieldWidth,
          child: TextField(
            controller: c,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  )
                : TextInputType.text,
            onChanged: (_) => _commit(),
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: theme.textTheme.bodySmall,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            field(_name, 'Name', hint: widget.fallbackName, numeric: false),
            const SizedBox(width: 8),
            // t0 is typed, not computed, so nothing is converted here — the
            // label only says which scale the number the user enters is read
            // on. That is the entry's own `jdisut` flag, not the Context
            // Scale: the engine reads t0 on this flag alone, so a label
            // following the global setting would name a scale that has no
            // bearing on this field.
            field(_t0, 't0 (JD ${widget.entry.t0IsUt ? 'UT' : 'TT'})'),
            const SizedBox(width: 8),
            field(_val, 'ayanamsa at t0 (°)'),
            const SizedBox(width: 4),
            Checkbox(
              value: widget.entry.t0IsUt,
              visualDensity: VisualDensity.compact,
              onChanged: (v) =>
                  notifier.update(widget.entry.id, t0IsUt: v ?? false),
            ),
            Text('t0 UT', style: theme.textTheme.labelSmall),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Remove ${widget.entry.name ?? widget.fallbackName}',
              visualDensity: VisualDensity.compact,
              onPressed: () => notifier.removeById(widget.entry.id),
            ),
          ],
        ),
      ),
    );
  }
}
