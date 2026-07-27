// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calculation/series_settings.dart';
import '../core/calculation/series_settings_provider.dart';
import '../core/calculation/series_spec.dart';
import '../core/context_provider.dart';
import '../core/display_format.dart';
import '../core/jd_utils.dart';
import '../core/swe_utils_provider.dart';

/// Series-mode controls for one tab: the mode toggle, and — once on — the
/// start Moment, step size and row count.
///
/// Tab-agnostic: it takes a [tabId] (`TabDescriptor.id`) and nothing else, so
/// every eligible tab wires it in the same one line.
///
/// The start is shown read-only. The Context owns the Moment (CLAUDE.md: JD is
/// canonical), and an editable start here would be a second place to set the
/// same thing.
class SeriesBar extends ConsumerStatefulWidget {
  const SeriesBar({super.key, required this.tabId, this.trailing});

  final String tabId;

  /// Extras (e.g. the body tabs' display controls) rendered on the same row,
  /// after the Series chip and any series controls. The widget is responsible
  /// for adapting its own content to the mode — see `BodyDisplayControls`.
  final Widget? trailing;

  @override
  ConsumerState<SeriesBar> createState() => _SeriesBarState();
}

class _SeriesBarState extends ConsumerState<SeriesBar> {
  late final TextEditingController _stepValueController;
  late final TextEditingController _rowCountController;
  Timer? _stepValueDebounce;
  Timer? _rowCountDebounce;

  static const _debounceDuration = Duration(milliseconds: 600);

  SeriesSettingsNotifier get _notifier =>
      ref.read(seriesSettingsProvider(widget.tabId).notifier);

  @override
  void initState() {
    super.initState();
    final settings = ref.read(seriesSettingsProvider(widget.tabId));
    _stepValueController = TextEditingController(
      text: _formatStepValue(settings.stepValue),
    );
    _rowCountController = TextEditingController(
      text: settings.rowCount.toString(),
    );
  }

  @override
  void dispose() {
    _stepValueDebounce?.cancel();
    _rowCountDebounce?.cancel();
    _stepValueController.dispose();
    _rowCountController.dispose();
    super.dispose();
  }

  static String _formatStepValue(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  void _onStepValueChanged(String text) {
    _stepValueDebounce?.cancel();
    _stepValueDebounce = Timer(_debounceDuration, () {
      final value = double.tryParse(text);
      if (value != null) _notifier.setStepValue(value);
    });
  }

  /// Switching to a calendar unit can invalidate a step value that was fine
  /// for the previous one. The notifier snaps it and returns what it took, so
  /// the field never disagrees with the series it produced.
  void _onStepUnitChanged(StepUnit unit) {
    final effective = _notifier.setStepUnit(unit);
    final text = _formatStepValue(effective);
    if (_stepValueController.text != text) _stepValueController.text = text;
  }

  void _onRowCountChanged(String text) {
    _rowCountDebounce?.cancel();
    _rowCountDebounce = Timer(_debounceDuration, () {
      final rows = int.tryParse(text);
      if (rows != null) _notifier.setRowCount(rows);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(seriesSettingsProvider(widget.tabId));
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          // Dense horizontal bar — scrolls rather than overflows at zoom.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Series'),
                  avatar: const Icon(Icons.timeline, size: 16),
                  selected: settings.enabled,
                  onSelected: _notifier.setEnabled,
                  visualDensity: VisualDensity.compact,
                ),
                if (settings.enabled) ...[
                  const SizedBox(width: 12),
                  Text('From ', style: labelStyle),
                  Text(_startLabel(), style: theme.textTheme.bodySmall),
                  const SizedBox(width: 12),
                  Text('Step ', style: labelStyle),
                  const SizedBox(width: 4),
                  _numberField(
                    theme,
                    _stepValueController,
                    onChanged: _onStepValueChanged,
                    onCommit: _commitStepValue,
                    signed: true,
                  ),
                  const SizedBox(width: 4),
                  ...StepUnit.values.map(
                    (u) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(u.label),
                        selected: settings.stepUnit == u,
                        onSelected: (_) => _onStepUnitChanged(u),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Rows ', style: labelStyle),
                  const SizedBox(width: 4),
                  _numberField(
                    theme,
                    _rowCountController,
                    onChanged: _onRowCountChanged,
                    onCommit: _commitRowCount,
                  ),
                ],
                if (widget.trailing != null) ...[
                  const SizedBox(width: 12),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
        if (settings.enabled) _warning(theme, settings),
      ],
    );
  }

  /// The Context Moment as the series start, tagged ` UT` so the scale is
  /// explicit; no companion clock (the "From …" label is width-constrained).
  String _startLabel() {
    final ctx = ref.watch(contextBarProvider);
    return formatJdDateTime(
      ref.read(sweProvider),
      ctx.jdUt,
      view: ref.watch(clockViewProvider),
      showCompanion: false,
      fallbackDigits: 4,
    );
  }

  Widget _warning(ThemeData theme, SeriesSettings settings) {
    // Only the row count can be out of bounds; the step value is gated on the
    // way in and has no unusable-but-accepted range.
    final message = rowCountWarning(settings.rowCount);
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              message,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _commitStepValue() {
    _stepValueDebounce?.cancel();
    final value = double.tryParse(_stepValueController.text);
    if (value != null) _notifier.setStepValue(value);
  }

  void _commitRowCount() {
    _rowCountDebounce?.cancel();
    final rows = int.tryParse(_rowCountController.text);
    if (rows != null) _notifier.setRowCount(rows);
  }

  Widget _numberField(
    ThemeData theme,
    TextEditingController controller, {
    required ValueChanged<String> onChanged,
    required VoidCallback onCommit,
    bool signed = false,
  }) {
    // Floored so the box lands on a whole pixel at fractional zoom.
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return SizedBox(
      width: (60 * scale).floorToDouble(),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: (_) => onCommit(),
        style: theme.textTheme.bodySmall,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.numberWithOptions(
          decimal: signed,
          signed: signed,
        ),
      ),
    );
  }
}
