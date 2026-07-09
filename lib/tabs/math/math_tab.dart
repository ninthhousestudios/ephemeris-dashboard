// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/swe_service.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'math_provider.dart';

class MathTab extends ConsumerStatefulWidget {
  const MathTab({super.key});

  @override
  ConsumerState<MathTab> createState() => _MathTabState();
}

class _MathTabState extends ConsumerState<MathTab> {
  /// Collected results from all cards, for export.
  final Map<MathOp, List<ResultField>> _allResults = {};

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.of(context) == ScreenSize.mobile;
    return Column(
      children: [
        // Export bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                'Math Functions',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              ExportButton(
                hasResults: _allResults.isNotEmpty,
                getRows: () => mathToExportRows(_allResults),
                filenameStem:
                    'swe_math_${ref.read(contextBarProvider).jdUt.toStringAsFixed(4)}',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Cards grid
        if (isMobile) _buildMathGrid() else Expanded(child: _buildMathGrid()),
      ],
    );
  }

  Widget _buildMathGrid() {
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
            children: MathOp.values
                .map(
                  (op) => SizedBox(
                    width: cardWidth,
                    child: _MathOpCard(
                      op: op,
                      onResult: (fields) {
                        setState(() {
                          if (fields != null) {
                            _allResults[op] = fields;
                          }
                        });
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

/// A self-contained card for a single math operation.
class _MathOpCard extends ConsumerStatefulWidget {
  const _MathOpCard({required this.op, required this.onResult});

  final MathOp op;
  final ValueChanged<List<ResultField>?> onResult;

  @override
  ConsumerState<_MathOpCard> createState() => _MathOpCardState();
}

class _MathOpCardState extends ConsumerState<_MathOpCard> {
  final _ctrl1 = TextEditingController(text: '0.0');
  final _ctrl2 = TextEditingController(text: '0.0');
  List<ResultField>? _result;

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    super.dispose();
  }

  void _calculate() {
    final a = double.tryParse(_ctrl1.text) ?? 0.0;
    final b = double.tryParse(_ctrl2.text) ?? 0.0;
    final swe = ref.read(sweProvider);
    final fields = computeMathOp(swe, widget.op, a, b);
    setState(() => _result = fields);
    widget.onResult(fields);
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
            // Title
            Text(widget.op.label, style: theme.textTheme.titleSmall),
            Text(
              widget.op.id,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // Inputs
            _buildInput(
              'Input${widget.op.inputCount > 1 ? ' A' : ''}:',
              _ctrl1,
            ),
            if (widget.op.inputCount > 1) ...[
              const SizedBox(height: 4),
              _buildInput('Input B:', _ctrl2),
            ],
            const SizedBox(height: 8),
            // Calculate button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate, size: 16),
                label: const Text('Calculate'),
              ),
            ),
            // Results
            if (_result != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._result!.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80 * MediaQuery.textScalerOf(context).scale(1.0),
                        child: Text(
                          f.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
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
                ),
              ),
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
