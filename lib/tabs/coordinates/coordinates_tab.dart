// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../dates/dates_provider.dart';
import 'coordinates_provider.dart';

/// Labelled numeric field, shared by all three cards on this tab.
Widget _buildInput(
  BuildContext context,
  String label,
  TextEditingController ctrl,
  VoidCallback onCommit, {
  ValueChanged<String>? onChanged,
}) {
  return Row(
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(width: 8),
      Expanded(
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(
            signed: true,
            decimal: true,
          ),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          onChanged: onChanged,
          onSubmitted: (_) => onCommit(),
        ),
      ),
    ],
  );
}

class CoordinatesTab extends ConsumerWidget {
  const CoordinatesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = ref.watch(coordFormatProvider);
    final jd = ref.watch(contextBarProvider).jdUt;
    final theme = Theme.of(context);

    final azAltOutcome = ref.watch(azAltResultProvider);
    final coTransOutcome = ref.watch(coTransResultProvider);
    final refracOutcome = ref.watch(refracResultProvider);

    final exportRows = <ExportRow>[
      if (azAltOutcome case CalcOk(value: final r))
        ...coordToExportRows(
          r is CoordAzAltRevResult ? CoordOp.azAltRev : CoordOp.azAlt,
          r,
          fmt,
        ),
      if (coTransOutcome case CalcOk(value: final r))
        ...coordToExportRows(CoordOp.cotrans, r, fmt),
      if (refracOutcome case CalcOk(value: final r))
        ...coordToExportRows(CoordOp.refrac, r, fmt),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Coordinate Transforms',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(width: 16),
                SegmentedButton<DisplayFormat>(
                  segments: DisplayFormat.values
                      .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                      .toList(),
                  selected: {fmt},
                  onSelectionChanged: (s) =>
                      ref.read(coordFormatProvider.notifier).state = s.first,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                ExportButton(
                  hasResults: exportRows.isNotEmpty,
                  getRows: () => exportRows,
                  filenameStem: 'swe_coordinates_${jd.toStringAsFixed(4)}',
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        _buildCardsGrid(),
      ],
    );
  }

  Widget _buildCardsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              SizedBox(width: cardWidth, child: const _AzAltCard()),
              SizedBox(width: cardWidth, child: const _CoTransCard()),
              SizedBox(width: cardWidth, child: const _RefracCard()),
            ],
          ),
        );
      },
    );
  }
}

// ── Az/Alt card (with direction toggle) ─────────────────────────────────────

class _AzAltCard extends ConsumerStatefulWidget {
  const _AzAltCard();

  @override
  ConsumerState<_AzAltCard> createState() => _AzAltCardState();
}

class _AzAltCardState extends ConsumerState<_AzAltCard> {
  bool _forward = true;
  final _lonCtrl = TextEditingController(text: '0.0');
  final _latCtrl = TextEditingController(text: '0.0');
  final _distCtrl = TextEditingController(text: '1.0');
  final _azCtrl = TextEditingController(text: '0.0');
  final _altCtrl = TextEditingController(text: '0.0');
  final _atpressCtrl = TextEditingController(text: '1013.25');
  final _attempCtrl = TextEditingController(text: '15.0');

  @override
  void dispose() {
    _lonCtrl.dispose();
    _latCtrl.dispose();
    _distCtrl.dispose();
    _azCtrl.dispose();
    _altCtrl.dispose();
    _atpressCtrl.dispose();
    _attempCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    ref.read(azAltInputProvider.notifier).state = (
      forward: _forward,
      lon: double.tryParse(_lonCtrl.text) ?? 0.0,
      lat: double.tryParse(_latCtrl.text) ?? 0.0,
      dist: double.tryParse(_distCtrl.text) ?? 1.0,
      atpress: double.tryParse(_atpressCtrl.text) ?? 1013.25,
      attemp: double.tryParse(_attempCtrl.text) ?? 15.0,
      azimuth: double.tryParse(_azCtrl.text) ?? 0.0,
      altitude: double.tryParse(_altCtrl.text) ?? 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final outcome = ref.watch(azAltResultProvider);
    final fmt = ref.watch(coordFormatProvider);

    return Card(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Az/Alt', style: theme.textTheme.titleSmall),
            Text(
              'Horizontal ↔ Ecliptic',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Ecl → Hor')),
                ButtonSegment(value: false, label: Text('Hor → Ecl')),
              ],
              selected: {_forward},
              onSelectionChanged: (s) => setState(() => _forward = s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 8),
            if (_forward) ...[
              _buildInput(context, 'Lon (°)', _lonCtrl, _commit),
              const SizedBox(height: 4),
              _buildInput(context, 'Lat (°)', _latCtrl, _commit),
              const SizedBox(height: 4),
              _buildInput(context, 'Dist (AU)', _distCtrl, _commit),
              const SizedBox(height: 4),
              _buildInput(context, 'Pressure (mbar)', _atpressCtrl, _commit),
              const SizedBox(height: 4),
              _buildInput(context, 'Temp (°C)', _attempCtrl, _commit),
            ] else ...[
              _buildInput(context, 'Azimuth (°)', _azCtrl, _commit),
              const SizedBox(height: 4),
              _buildInput(context, 'True Alt (°)', _altCtrl, _commit),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _commit,
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Calculate'),
              ),
            ),
            _resultSection(outcome, fmt, theme, colorScheme),
          ],
        ),
      ),
    );
  }
}

// ── CoTrans card ────────────────────────────────────────────────────────────

class _CoTransCard extends ConsumerStatefulWidget {
  const _CoTransCard();

  @override
  ConsumerState<_CoTransCard> createState() => _CoTransCardState();
}

class _CoTransCardState extends ConsumerState<_CoTransCard> {
  bool _eclToEqu = true;

  /// Once the user edits the obliquity field, stop auto-filling it from the
  /// Context Moment's true obliquity so their value is preserved.
  bool _epsCustom = false;
  final _lonCtrl = TextEditingController(text: '0.0');
  final _latCtrl = TextEditingController(text: '0.0');
  final _distCtrl = TextEditingController(text: '1.0');
  final _epsCtrl = TextEditingController(text: '23.4393');

  @override
  void dispose() {
    _lonCtrl.dispose();
    _latCtrl.dispose();
    _distCtrl.dispose();
    _epsCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    ref.read(coTransInputProvider.notifier).state = (
      eclToEqu: _eclToEqu,
      lon: double.tryParse(_lonCtrl.text) ?? 0.0,
      lat: double.tryParse(_latCtrl.text) ?? 0.0,
      dist: double.tryParse(_distCtrl.text) ?? 1.0,
      eps: double.tryParse(_epsCtrl.text) ?? 23.4393,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final outcome = ref.watch(coTransResultProvider);
    final fmt = ref.watch(coordFormatProvider);

    // Default the obliquity field to the Context Moment's true obliquity
    // (SE_ECL_NUT) until the user overrides it. Reuses the Dates tab compute.
    if (!_epsCustom) {
      final trueObliquity = switch (ref.watch(datesResultProvider)) {
        CalcOk(value: final r) when r.eclNutError == null => r.trueObliquity,
        _ => null,
      };
      if (trueObliquity != null) {
        final s = trueObliquity.toStringAsFixed(6);
        if (_epsCtrl.text != s) {
          _epsCtrl.text = s;
          // Push into the input provider after the frame — mutating provider
          // state during build is disallowed.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_epsCustom) _commit();
          });
        }
      }
    }

    return Card(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CoTrans', style: theme.textTheme.titleSmall),
            Text(
              'Ecliptic ↔ Equatorial',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Ecl → Equ')),
                ButtonSegment(value: false, label: Text('Equ → Ecl')),
              ],
              selected: {_eclToEqu},
              onSelectionChanged: (s) => setState(() => _eclToEqu = s.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const SizedBox(height: 8),
            _buildInput(context, 'Lon (°)', _lonCtrl, _commit),
            const SizedBox(height: 4),
            _buildInput(context, 'Lat (°)', _latCtrl, _commit),
            const SizedBox(height: 4),
            _buildInput(context, 'Distance', _distCtrl, _commit),
            const SizedBox(height: 4),
            _buildInput(
              context,
              'Obliquity (°)',
              _epsCtrl,
              _commit,
              onChanged: (_) => _epsCustom = true,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _commit,
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Calculate'),
              ),
            ),
            _resultSection(outcome, fmt, theme, colorScheme),
          ],
        ),
      ),
    );
  }
}

// ── Refraction card ─────────────────────────────────────────────────────────

class _RefracCard extends ConsumerStatefulWidget {
  const _RefracCard();

  @override
  ConsumerState<_RefracCard> createState() => _RefracCardState();
}

class _RefracCardState extends ConsumerState<_RefracCard> {
  final _altCtrl = TextEditingController(text: '0.0');
  final _atpressCtrl = TextEditingController(text: '1013.25');
  final _attempCtrl = TextEditingController(text: '15.0');

  @override
  void dispose() {
    _altCtrl.dispose();
    _atpressCtrl.dispose();
    _attempCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    ref.read(refracInputProvider.notifier).state = (
      altitude: double.tryParse(_altCtrl.text) ?? 0.0,
      atpress: double.tryParse(_atpressCtrl.text) ?? 1013.25,
      attemp: double.tryParse(_attempCtrl.text) ?? 15.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final outcome = ref.watch(refracResultProvider);
    final fmt = ref.watch(coordFormatProvider);

    return Card(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Refraction', style: theme.textTheme.titleSmall),
            Text(
              'Atmospheric refraction',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _buildInput(context, 'Altitude (°)', _altCtrl, _commit),
            const SizedBox(height: 4),
            _buildInput(context, 'Pressure (mbar)', _atpressCtrl, _commit),
            const SizedBox(height: 4),
            _buildInput(context, 'Temp (°C)', _attempCtrl, _commit),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _commit,
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Calculate'),
              ),
            ),
            _resultSection(outcome, fmt, theme, colorScheme),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

Widget _resultSection(
  CalcOutcome<CoordResult> outcome,
  DisplayFormat fmt,
  ThemeData theme,
  ColorScheme colorScheme,
) {
  return switch (outcome) {
    CalcError(:final message) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Error: $message',
        style: TextStyle(color: colorScheme.error),
      ),
    ),
    CalcOk(value: final result) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        ...coordResultToFields(
          result,
          fmt,
        ).map((f) => _resultRow(f, theme, colorScheme)),
      ],
    ),
  };
}

Widget _resultRow(ResultField f, ThemeData theme, ColorScheme colorScheme) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Text(
          f.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            f.value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    ),
  );
}
