// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../widgets/export_button.dart';
import '../../widgets/star_search_field.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/display_format.dart';
import '../../core/ephe/catalog.dart';
import '../../core/flag_provider.dart';
import '../other_bodies/other_bodies_provider.dart'
    show otherBodiesNamedAsteroids, namedComets;
import '../../core/calculation/series_spec.dart';
import 'table_view_provider.dart';

class TableViewTab extends ConsumerStatefulWidget {
  const TableViewTab({super.key});

  @override
  ConsumerState<TableViewTab> createState() => _TableViewTabState();
}

class _TableViewTabState extends ConsumerState<TableViewTab> {
  final _stepValueController = TextEditingController(text: '1');
  final _stepCountController = TextEditingController(text: '30');
  final _asteroidController = TextEditingController();
  final _cometController = TextEditingController();
  bool _showMore = false;

  @override
  void dispose() {
    _stepValueController.dispose();
    _stepCountController.dispose();
    _asteroidController.dispose();
    _cometController.dispose();
    super.dispose();
  }

  void _onStepValueChanged(String text) {
    final sv = double.tryParse(text);
    // A negative step runs the series backward (swetest `-bwd`). What else is
    // admissible depends on the unit, so the rule lives on StepUnit — note
    // that `double.tryParse` happily returns NaN and Infinity for text a user
    // can type.
    final unit = ref.read(tableViewStepUnitProvider);
    if (sv != null && unit.acceptsStepValue(sv)) {
      ref.read(tableViewStepValueProvider.notifier).state = sv;
    }
  }

  /// Switching to a calendar unit can invalidate a step value that was fine
  /// for the previous one (2.5 Days is meaningful, 2.5 Months is not). Round
  /// it and show the rounded value, so the field never disagrees with the
  /// series it produced.
  void _onStepUnitChanged(StepUnit unit) {
    final current = ref.read(tableViewStepValueProvider);
    final usable = unit.snapStepValue(current);
    if (usable != current) {
      ref.read(tableViewStepValueProvider.notifier).state = usable;
      _stepValueController.text = usable.toStringAsFixed(0);
    }
    ref.read(tableViewStepUnitProvider.notifier).state = unit;
  }

  void _onStepCountChanged(String text) {
    final sc = int.tryParse(text);
    if (sc != null && sc > 0 && sc <= 1000) {
      ref.read(tableViewStepCountProvider.notifier).state = sc;
    }
  }

  void _toggleExtraBody(int bodyId) {
    final current = ref.read(tableViewExtraBodiesProvider);
    ref
        .read(tableViewExtraBodiesProvider.notifier)
        .state = current.contains(bodyId)
        ? ({...current}..remove(bodyId))
        : {...current, bodyId};
  }

  void _addExtraBody(int bodyId) {
    final current = ref.read(tableViewExtraBodiesProvider);
    if (!current.contains(bodyId)) {
      ref.read(tableViewExtraBodiesProvider.notifier).state = {
        ...current,
        bodyId,
      };
    }
  }

  void _addCustomAsteroid() {
    final num = int.tryParse(_asteroidController.text.trim());
    if (num != null && num > 0) {
      _addExtraBody(seAstOffset + num);
      _asteroidController.clear();
    }
  }

  void _addCustomComet() {
    final num = int.tryParse(_cometController.text.trim());
    if (num != null && num > 0) {
      _addExtraBody(seAstOffset + num);
      _cometController.clear();
    }
  }

  void _addStar(String name) {
    final current = ref.read(tableViewStarsProvider);
    if (!current.contains(name)) {
      ref.read(tableViewStarsProvider.notifier).state = [...current, name];
    }
  }

  void _removeStar(String name) {
    final current = ref.read(tableViewStarsProvider);
    ref.read(tableViewStarsProvider.notifier).state = current
        .where((s) => s != name)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedBodies = ref.watch(tableViewBodiesProvider);
    final extraBodies = ref.watch(tableViewExtraBodiesProvider);
    final stars = ref.watch(tableViewStarsProvider);
    final stepUnit = ref.watch(tableViewStepUnitProvider);
    final format = ref.watch(tableViewFormatProvider);
    final outcome = ref.watch(tableViewResultsProvider);
    final flags = ref.watch(flagBarProvider);
    final isXyz = flags.isXyz;
    final extraColumns = ref.watch(tableViewColumnsProvider);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final availableColumns = isXyz
        ? const [TableColumn.distance]
        : TableColumn.values;
    final sortedKeys = tableViewSortedKeys(selectedBodies, extraBodies, stars);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Body multi-select chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Bodies ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ...tableViewBodies.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(b.$2),
                      selected: selectedBodies.contains(b.$1),
                      onSelected: (on) {
                        final current = ref
                            .read(tableViewBodiesProvider.notifier)
                            .state;
                        if (on) {
                          ref.read(tableViewBodiesProvider.notifier).state = {
                            ...current,
                            b.$1,
                          };
                        } else {
                          ref.read(tableViewBodiesProvider.notifier).state = {
                            ...current,
                          }..remove(b.$1);
                        }
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── More Bodies (expandable) ──
        _buildMoreBodies(theme, labelStyle, extraBodies, stars),
        // ── Column options ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Columns ', style: labelStyle),
                const SizedBox(width: 4),
                ...availableColumns.map(
                  (col) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(col.label),
                      selected: extraColumns.contains(col),
                      onSelected: (on) {
                        final current = ref
                            .read(tableViewColumnsProvider.notifier)
                            .state;
                        ref.read(tableViewColumnsProvider.notifier).state = on
                            ? {...current, col}
                            : ({...current}..remove(col));
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Step config ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Step ', style: labelStyle),
                const SizedBox(width: 4),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _stepValueController,
                    onChanged: _onStepValueChanged,
                    style: theme.textTheme.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ...StepUnit.values.map(
                  (u) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(u.label),
                      selected: stepUnit == u,
                      onSelected: (_) => _onStepUnitChanged(u),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Rows ', style: labelStyle),
                const SizedBox(width: 4),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _stepCountController,
                    onChanged: _onStepCountChanged,
                    style: theme.textTheme.bodySmall,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ExportButton(
                  hasResults: switch (outcome) {
                    CalcOk(value: final rows) => rows.isNotEmpty,
                    CalcError() => false,
                  },
                  filenameStem: 'table_view',
                  getRows: () => switch (outcome) {
                    CalcOk(value: final rows) => tableViewToExportRows(
                      rows,
                      tableViewSortedKeys(
                        ref.read(tableViewBodiesProvider),
                        ref.read(tableViewExtraBodiesProvider),
                        ref.read(tableViewStarsProvider),
                      ),
                      ref.read(tableViewFormatProvider),
                      isXyz: ref.read(flagBarProvider).isXyz,
                      columns: ref.read(tableViewColumnsProvider),
                    ),
                    CalcError() => [],
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Data table ──
        _buildTable(outcome, sortedKeys, format, isXyz, extraColumns),
      ],
    );
  }

  // ── More Bodies panel ─────────────────────────────────────────────────────

  Widget _buildMoreBodies(
    ThemeData theme,
    TextStyle? labelStyle,
    Set<int> extraBodies,
    List<String> stars,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showMore = !_showMore),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showMore ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text('More Bodies', style: labelStyle),
                if (extraBodies.isNotEmpty || stars.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${extraBodies.length + stars.length} selected)',
                    style: labelStyle,
                  ),
                ],
              ],
            ),
          ),
          if (_showMore) ...[
            const SizedBox(height: 4),
            // ── Planetary Moons ──
            Text(
              'Planetary Moons',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            for (final group in planetaryMoonGroups) ...[
              Text(group.parent, style: labelStyle),
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: group.moons.map((m) {
                  return FilterChip(
                    label: Text(m.name),
                    selected: extraBodies.contains(m.bodyId),
                    onSelected: (_) => _toggleExtraBody(m.bodyId),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
            ],
            // ── Asteroids ──
            Text(
              'Asteroids',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: otherBodiesNamedAsteroids.entries.map((e) {
                final bodyId = seAstOffset + e.key;
                return FilterChip(
                  label: Text(e.value),
                  selected: extraBodies.contains(bodyId),
                  onSelected: (_) => _toggleExtraBody(bodyId),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: (140 * MediaQuery.textScalerOf(context).scale(1.0))
                      .floorToDouble(),
                  child: TextField(
                    controller: _asteroidController,
                    decoration: const InputDecoration(
                      hintText: 'MPC #',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _addCustomAsteroid(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Add asteroid by MPC number',
                  onPressed: _addCustomAsteroid,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ── Comets ──
            Text(
              'Comets',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: namedComets.entries.map((e) {
                final bodyId = seAstOffset + e.key;
                return FilterChip(
                  label: Text(e.value),
                  selected: extraBodies.contains(bodyId),
                  onSelected: (_) => _toggleExtraBody(bodyId),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: (140 * MediaQuery.textScalerOf(context).scale(1.0))
                      .floorToDouble(),
                  child: TextField(
                    controller: _cometController,
                    decoration: const InputDecoration(
                      hintText: 'Pseudo-MPC #',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _addCustomComet(),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  tooltip: 'Add comet by pseudo-MPC number',
                  onPressed: _addCustomComet,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // ── Stars ──
            Text(
              'Stars',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            StarSearchField(onSelect: _addStar, dense: true),
            if (stars.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: stars.map((name) {
                  return Chip(
                    label: Text(name),
                    onDeleted: () => _removeStar(name),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  // ── Data table ────────────────────────────────────────────────────────────

  Widget _buildTable(
    CalcOutcome<List<EphemerisRow>> outcome,
    List<ColKey> keys,
    DisplayFormat format,
    bool isXyz,
    Set<TableColumn> extraColumns,
  ) {
    final List<EphemerisRow> rows;
    switch (outcome) {
      case CalcError(:final message):
        return Center(child: Text('Calculation error: $message'));
      case CalcOk(value: final v):
        rows = v;
    }
    if (rows.isEmpty) {
      return const Center(child: Text('No results'));
    }

    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.bold,
    );
    final cellStyle = theme.textTheme.bodySmall;

    List<DataColumn> colHeaders(ColKey key) {
      final name = key.label;
      if (isXyz) {
        return [
          DataColumn(label: Text('$name X', style: headerStyle)),
          DataColumn(label: Text('$name Y', style: headerStyle)),
          DataColumn(label: Text('$name Z', style: headerStyle)),
          if (extraColumns.contains(TableColumn.distance))
            DataColumn(label: Text('$name Dist', style: headerStyle)),
        ];
      }
      return [
        DataColumn(label: Text(name, style: headerStyle)),
        if (extraColumns.contains(TableColumn.latitude))
          DataColumn(label: Text('$name Lat', style: headerStyle)),
        if (extraColumns.contains(TableColumn.distance))
          DataColumn(label: Text('$name Dist', style: headerStyle)),
        if (extraColumns.contains(TableColumn.speed))
          DataColumn(label: Text('$name Spd', style: headerStyle)),
      ];
    }

    List<DataCell> colCells(EphemerisRow row, ColKey key) {
      final val = row.values[key];
      if (val == null) {
        final dash = DataCell(Text('—', style: cellStyle));
        if (isXyz) {
          return [
            dash,
            dash,
            dash,
            if (extraColumns.contains(TableColumn.distance)) dash,
          ];
        }
        return [
          dash,
          if (extraColumns.contains(TableColumn.latitude)) dash,
          if (extraColumns.contains(TableColumn.distance)) dash,
          if (extraColumns.contains(TableColumn.speed)) dash,
        ];
      }
      final (result, err) = val;
      if (err != null) {
        final errCell = DataCell(Text(err, style: cellStyle));
        if (isXyz) {
          return [
            errCell,
            errCell,
            errCell,
            if (extraColumns.contains(TableColumn.distance)) errCell,
          ];
        }
        return [
          errCell,
          if (extraColumns.contains(TableColumn.latitude)) errCell,
          if (extraColumns.contains(TableColumn.distance)) errCell,
          if (extraColumns.contains(TableColumn.speed)) errCell,
        ];
      }
      final r = result!;
      DataCell cell(String text) => DataCell(Text(text, style: cellStyle));
      if (isXyz) {
        return [
          cell(formatAu(r.longitude, format)),
          cell(formatAu(r.latitude, format)),
          cell(formatAu(r.distance, format)),
          if (extraColumns.contains(TableColumn.distance))
            cell(formatEuclidean(r.longitude, r.latitude, r.distance, format)),
        ];
      }
      return [
        cell(formatAngle(r.longitude, format)),
        if (extraColumns.contains(TableColumn.latitude))
          cell(formatAngle(r.latitude, format)),
        if (extraColumns.contains(TableColumn.distance))
          cell(formatAu(r.distance, format)),
        if (extraColumns.contains(TableColumn.speed))
          cell(formatAngle(r.longitudeSpeed, format)),
      ];
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 36,
          dataRowMinHeight: 28,
          dataRowMaxHeight: 32,
          columns: [
            DataColumn(label: Text('Date/Time (UT)', style: headerStyle)),
            DataColumn(label: Text('JD', style: headerStyle)),
            for (final key in keys) ...colHeaders(key),
          ],
          rows: rows.map((row) {
            return DataRow(
              cells: [
                DataCell(Text(row.dateStr, style: cellStyle)),
                DataCell(Text(row.jd.toStringAsFixed(4), style: cellStyle)),
                for (final key in keys) ...colCells(row, key),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class TableViewFormatTrailing extends ConsumerWidget {
  const TableViewFormatTrailing({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatStyle = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelSmall),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    );
    final format = ref.watch(tableViewFormatProvider);
    final outcome = ref.watch(tableViewResultsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<DisplayFormat>(
          segments: DisplayFormat.values
              .map((f) => ButtonSegment(value: f, label: Text(f.label)))
              .toList(),
          selected: {format},
          onSelectionChanged: (s) =>
              ref.read(tableViewFormatProvider.notifier).state = s.first,
          style: formatStyle,
        ),
        const SizedBox(width: 8),
        ExportButton(
          hasResults: switch (outcome) {
            CalcOk(value: final r) => r.isNotEmpty,
            CalcError() => false,
          },
          getRows: () => switch (outcome) {
            CalcOk(value: final r) => tableViewToExportRows(
              r,
              tableViewSortedKeys(
                ref.read(tableViewBodiesProvider),
                ref.read(tableViewExtraBodiesProvider),
                ref.read(tableViewStarsProvider),
              ),
              format,
              isXyz: ref.read(flagBarProvider).isXyz,
              columns: ref.read(tableViewColumnsProvider),
            ),
            CalcError() => [],
          },
          filenameStem: 'swe_table',
        ),
      ],
    );
  }
}
