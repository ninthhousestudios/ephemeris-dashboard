import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'coordinates_provider.dart';

class CoordinatesTab extends ConsumerStatefulWidget {
  const CoordinatesTab({super.key});

  @override
  ConsumerState<CoordinatesTab> createState() => _CoordinatesTabState();
}

class _CoordinatesTabState extends ConsumerState<CoordinatesTab> {
  final Map<String, List<ResultField>> _allResults = {};

  @override
  Widget build(BuildContext context) {
    final fmt = ref.watch(coordFormatProvider);
    final jd = ref.watch(contextBarProvider).jdUt;
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.of(context) == ScreenSize.mobile;

    return Column(
      children: [
        // ── Header: title + format + export ──
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
                  hasResults: _allResults.isNotEmpty,
                  getRows: () => _allResults.entries
                      .map(
                        (e) => ExportRow(
                          header: e.key,
                          fields: e.value
                              .map((f) => (f.label, f.value))
                              .toList(),
                        ),
                      )
                      .toList(),
                  filenameStem: 'swe_coordinates_${jd.toStringAsFixed(4)}',
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Cards grid ──
        if (isMobile) _buildCardsGrid() else Expanded(child: _buildCardsGrid()),
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
              SizedBox(
                width: cardWidth,
                child: _AzAltCard(
                  onResult: (fields) => setState(() {
                    if (fields != null) _allResults['Az/Alt'] = fields;
                  }),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _CoTransCard(
                  onResult: (fields) => setState(() {
                    if (fields != null) _allResults['CoTrans'] = fields;
                  }),
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _RefracCard(
                  onResult: (fields) => setState(() {
                    if (fields != null) _allResults['Refraction'] = fields;
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Az/Alt card (with direction toggle) ─────────────────────────────────────

class _AzAltCard extends ConsumerStatefulWidget {
  const _AzAltCard({required this.onResult});
  final ValueChanged<List<ResultField>?> onResult;

  @override
  ConsumerState<_AzAltCard> createState() => _AzAltCardState();
}

class _AzAltCardState extends ConsumerState<_AzAltCard> {
  bool _forward = true; // true = ecl→hor, false = hor→ecl
  final _lonCtrl = TextEditingController(text: '0.0');
  final _latCtrl = TextEditingController(text: '0.0');
  final _distCtrl = TextEditingController(text: '1.0');
  final _azCtrl = TextEditingController(text: '0.0');
  final _altCtrl = TextEditingController(text: '0.0');
  final _atpressCtrl = TextEditingController(text: '1013.25');
  final _attempCtrl = TextEditingController(text: '15.0');
  List<ResultField>? _result;

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

  void _calculate() {
    if (_forward) {
      ref.read(coordOpProvider.notifier).state = CoordOp.azAlt;
      ref.read(coordLonProvider.notifier).state =
          double.tryParse(_lonCtrl.text) ?? 0.0;
      ref.read(coordLatProvider.notifier).state =
          double.tryParse(_latCtrl.text) ?? 0.0;
      ref.read(coordDistProvider.notifier).state =
          double.tryParse(_distCtrl.text) ?? 1.0;
      ref.read(coordAtpressProvider.notifier).state =
          double.tryParse(_atpressCtrl.text) ?? 1013.25;
      ref.read(coordAttempProvider.notifier).state =
          double.tryParse(_attempCtrl.text) ?? 15.0;
    } else {
      ref.read(coordOpProvider.notifier).state = CoordOp.azAltRev;
      ref.read(coordAzimuthProvider.notifier).state =
          double.tryParse(_azCtrl.text) ?? 0.0;
      ref.read(coordAltitudeProvider.notifier).state =
          double.tryParse(_altCtrl.text) ?? 0.0;
    }
    final outcome = ref.read(coordResultProvider);
    switch (outcome) {
      case CalcOk(value: final result):
        final fmt = ref.read(coordFormatProvider);
        final fields = coordResultToFields(result, fmt);
        setState(() => _result = fields);
        widget.onResult(fields);
      case CalcSweError():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            // Direction toggle
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
            // Inputs change based on direction
            if (_forward) ...[
              _buildInput('Lon (°)', _lonCtrl),
              const SizedBox(height: 4),
              _buildInput('Lat (°)', _latCtrl),
              const SizedBox(height: 4),
              _buildInput('Dist (AU)', _distCtrl),
              const SizedBox(height: 4),
              _buildInput('Pressure (mbar)', _atpressCtrl),
              const SizedBox(height: 4),
              _buildInput('Temp (°C)', _attempCtrl),
            ] else ...[
              _buildInput('Azimuth (°)', _azCtrl),
              const SizedBox(height: 4),
              _buildInput('True Alt (°)', _altCtrl),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Calculate'),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._result!.map((f) => _resultRow(f, theme, colorScheme)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
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
            onSubmitted: (_) => _calculate(),
          ),
        ),
      ],
    );
  }
}

// ── CoTrans card ────────────────────────────────────────────────────────────

class _CoTransCard extends ConsumerStatefulWidget {
  const _CoTransCard({required this.onResult});
  final ValueChanged<List<ResultField>?> onResult;

  @override
  ConsumerState<_CoTransCard> createState() => _CoTransCardState();
}

class _CoTransCardState extends ConsumerState<_CoTransCard> {
  bool _eclToEqu = true; // true = ecl→equ, false = equ→ecl
  final _lonCtrl = TextEditingController(text: '0.0');
  final _latCtrl = TextEditingController(text: '0.0');
  final _distCtrl = TextEditingController(text: '1.0');
  final _epsCtrl = TextEditingController(text: '23.4393');
  List<ResultField>? _result;

  @override
  void dispose() {
    _lonCtrl.dispose();
    _latCtrl.dispose();
    _distCtrl.dispose();
    _epsCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    ref.read(coordOpProvider.notifier).state = CoordOp.cotrans;
    ref.read(coordLonProvider.notifier).state =
        double.tryParse(_lonCtrl.text) ?? 0.0;
    ref.read(coordLatProvider.notifier).state =
        double.tryParse(_latCtrl.text) ?? 0.0;
    ref.read(coordDistProvider.notifier).state =
        double.tryParse(_distCtrl.text) ?? 1.0;
    // Sign of eps controls direction: positive = ecl→equ, negative = equ→ecl
    final epsAbs = (double.tryParse(_epsCtrl.text) ?? 23.4393).abs();
    ref.read(coordEpsProvider.notifier).state = _eclToEqu ? epsAbs : -epsAbs;
    final outcome = ref.read(coordResultProvider);
    switch (outcome) {
      case CalcOk(value: final result):
        final fmt = ref.read(coordFormatProvider);
        final fields = coordResultToFields(result, fmt);
        setState(() => _result = fields);
        widget.onResult(fields);
      case CalcSweError():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            // Direction toggle
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
            _buildInput('Lon (°)', _lonCtrl),
            const SizedBox(height: 4),
            _buildInput('Lat (°)', _latCtrl),
            const SizedBox(height: 4),
            _buildInput('Distance', _distCtrl),
            const SizedBox(height: 4),
            _buildInput('Obliquity (°)', _epsCtrl),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Calculate'),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._result!.map((f) => _resultRow(f, theme, colorScheme)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
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
            onSubmitted: (_) => _calculate(),
          ),
        ),
      ],
    );
  }
}

// ── Refraction card ─────────────────────────────────────────────────────────

class _RefracCard extends ConsumerStatefulWidget {
  const _RefracCard({required this.onResult});
  final ValueChanged<List<ResultField>?> onResult;

  @override
  ConsumerState<_RefracCard> createState() => _RefracCardState();
}

class _RefracCardState extends ConsumerState<_RefracCard> {
  final _altCtrl = TextEditingController(text: '0.0');
  final _atpressCtrl = TextEditingController(text: '1013.25');
  final _attempCtrl = TextEditingController(text: '15.0');
  List<ResultField>? _result;

  @override
  void dispose() {
    _altCtrl.dispose();
    _atpressCtrl.dispose();
    _attempCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    ref.read(coordOpProvider.notifier).state = CoordOp.refrac;
    ref.read(coordAltitudeProvider.notifier).state =
        double.tryParse(_altCtrl.text) ?? 0.0;
    ref.read(coordAtpressProvider.notifier).state =
        double.tryParse(_atpressCtrl.text) ?? 1013.25;
    ref.read(coordAttempProvider.notifier).state =
        double.tryParse(_attempCtrl.text) ?? 15.0;
    final outcome = ref.read(coordResultProvider);
    switch (outcome) {
      case CalcOk(value: final result):
        final fmt = ref.read(coordFormatProvider);
        final fields = coordResultToFields(result, fmt);
        setState(() => _result = fields);
        widget.onResult(fields);
      case CalcSweError():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            _buildInput('Altitude (°)', _altCtrl),
            const SizedBox(height: 4),
            _buildInput('Pressure (mbar)', _atpressCtrl),
            const SizedBox(height: 4),
            _buildInput('Temp (°C)', _attempCtrl),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Calculate'),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._result!.map((f) => _resultRow(f, theme, colorScheme)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
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
            onSubmitted: (_) => _calculate(),
          ),
        ),
      ],
    );
  }
}

// ── Shared result row helper ────────────────────────────────────────────────

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
