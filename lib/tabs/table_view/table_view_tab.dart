import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/export_button.dart';
import '../../core/calc_trigger.dart';
import '../../core/display_format.dart';
import 'table_view_provider.dart';

class TableViewTab extends ConsumerStatefulWidget {
  const TableViewTab({super.key});

  @override
  ConsumerState<TableViewTab> createState() => _TableViewTabState();
}

class _TableViewTabState extends ConsumerState<TableViewTab> {
  final _stepValueController = TextEditingController(text: '1');
  final _stepCountController = TextEditingController(text: '30');

  @override
  void dispose() {
    _stepValueController.dispose();
    _stepCountController.dispose();
    super.dispose();
  }

  void _onStepValueChanged(String text) {
    final sv = double.tryParse(text);
    if (sv != null && sv > 0) {
      ref.read(tableViewStepValueProvider.notifier).state = sv;
    }
  }

  void _onStepCountChanged(String text) {
    final sc = int.tryParse(text);
    if (sc != null && sc > 0 && sc <= 1000) {
      ref.read(tableViewStepCountProvider.notifier).state = sc;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedBodies = ref.watch(tableViewBodiesProvider);
    final stepUnit = ref.watch(tableViewStepUnitProvider);
    final format = ref.watch(tableViewFormatProvider);
    final results = ref.watch(tableViewResultsProvider);
    final triggered = ref.watch(calcTriggerProvider) > 0;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

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
                ...tableViewBodies.map((b) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: FilterChip(
                        label: Text(b.$2),
                        selected: selectedBodies.contains(b.$1),
                        onSelected: (on) {
                          final current =
                              ref.read(tableViewBodiesProvider.notifier).state;
                          if (on) {
                            ref
                                .read(tableViewBodiesProvider.notifier)
                                .state = {...current, b.$1};
                          } else if (current.length > 1) {
                            ref
                                .read(tableViewBodiesProvider.notifier)
                                .state = {...current}..remove(b.$1);
                          }
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
        ),
        // ── Step config + Calculate ──
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
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                  ),
                ),
                const SizedBox(width: 4),
                ...StepUnit.values.map((u) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(u.label),
                        selected: stepUnit == u,
                        onSelected: (_) => ref
                            .read(tableViewStepUnitProvider.notifier)
                            .state = u,
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
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
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ExportButton(
                  hasResults: triggered && results.isNotEmpty,
                  filenameStem: 'table_view',
                  getRows: () => tableViewToExportRows(
                    results,
                    ref.read(tableViewBodiesProvider),
                    ref.read(tableViewFormatProvider),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Data table ──
        Expanded(
          child: triggered
              ? _buildTable(results, selectedBodies, format)
              : const Center(
                  child: Text('Select bodies, configure step, press Calculate'),
                ),
        ),
      ],
    );
  }

  Widget _buildTable(
    List<EphemerisRow> rows,
    Set<int> bodies,
    DisplayFormat format,
  ) {
    if (rows.isEmpty) {
      return const Center(child: Text('No results'));
    }

    final sortedBodies = bodies.toList()..sort();
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall
        ?.copyWith(fontWeight: FontWeight.bold);
    final cellStyle = theme.textTheme.bodySmall;

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
            DataColumn(
              label: Text('Date/Time (UT)', style: headerStyle),
            ),
            DataColumn(
              label: Text('JD', style: headerStyle),
            ),
            ...sortedBodies.map((b) => DataColumn(
                  label: Text(bodyName(b), style: headerStyle),
                )),
          ],
          rows: rows.map((row) {
            return DataRow(cells: [
              DataCell(Text(row.dateStr, style: cellStyle)),
              DataCell(Text(row.jd.toStringAsFixed(4), style: cellStyle)),
              ...sortedBodies.map((b) {
                final val = row.bodyValues[b];
                if (val == null) {
                  return DataCell(Text('—', style: cellStyle));
                }
                final (lon, err) = val;
                return DataCell(Text(
                  err ?? formatAngle(lon!, format),
                  style: cellStyle,
                ));
              }),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
