// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../core/swe_utils.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../../widgets/star_search_field.dart';
import 'heliacal_provider.dart';

const _eventTypes = [
  (seHeliacalRising, 'Heliacal Rising'),
  (seHeliacalSetting, 'Heliacal Setting'),
  (seEveningFirst, 'Evening First'),
  (seMorningLast, 'Morning Last'),
];

/// Bodies available for heliacal events, matching the Planets tab default set.
/// The heliacalUt API takes a string name, so we map body ID → name.
const _heliacalBodies = [
  (seSun, 'Sun'),
  (seMoon, 'Moon'),
  (seMercury, 'Mercury'),
  (seVenus, 'Venus'),
  (seMars, 'Mars'),
  (seJupiter, 'Jupiter'),
  (seSaturn, 'Saturn'),
  (seUranus, 'Uranus'),
  (seNeptune, 'Neptune'),
  (sePluto, 'Pluto'),
];

class HeliacalTab extends ConsumerStatefulWidget {
  const HeliacalTab({super.key});

  @override
  ConsumerState<HeliacalTab> createState() => _HeliacalTabState();
}

class _HeliacalTabState extends ConsumerState<HeliacalTab> {
  bool _showAtmospheric = false;
  bool _showStarInput = false;

  late final TextEditingController _pressureController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _humidityController;
  late final TextEditingController _extinctionController;
  late final TextEditingController _ageController;
  late final TextEditingController _snellenController;

  /// Coalesces rapid field edits: heliacalUt is a heavyweight iterative FFI
  /// search, so a reactive recompute fires only after typing pauses rather than
  /// on every keystroke. Explicit actions (submit, suggestion/chip pick) bypass
  /// this and push immediately, cancelling any pending debounce.
  Timer? _recomputeDebounce;

  @override
  void initState() {
    super.initState();
    _pressureController = TextEditingController(text: '1013.25');
    _temperatureController = TextEditingController(text: '25.0');
    _humidityController = TextEditingController(text: '50.0');
    _extinctionController = TextEditingController(text: '0.2');
    _ageController = TextEditingController(text: '36.0');
    _snellenController = TextEditingController(text: '1.0');
  }

  @override
  void dispose() {
    _recomputeDebounce?.cancel();
    _pressureController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    _extinctionController.dispose();
    _ageController.dispose();
    _snellenController.dispose();
    super.dispose();
  }

  /// Schedules [apply] after a short pause, cancelling any pending edit. The
  /// heliacal result provider recomputes reactively when [apply] mutates a
  /// StateProvider, so debouncing here throttles the FFI search, not the UI.
  void _debouncedSet(void Function() apply) {
    _recomputeDebounce?.cancel();
    _recomputeDebounce = Timer(const Duration(milliseconds: 400), apply);
  }

  void _addTarget(String name) {
    final current = ref.read(heliacalTargetsProvider);
    if (current.contains(name)) return;
    ref.read(heliacalTargetsProvider.notifier).state = [...current, name];
  }

  void _removeTarget(String name) {
    final current = ref.read(heliacalTargetsProvider);
    ref.read(heliacalTargetsProvider.notifier).state = current
        .where((t) => t != name)
        .toList();
  }

  void _toggleTarget(String name) {
    final current = ref.read(heliacalTargetsProvider);
    if (current.contains(name)) {
      _removeTarget(name);
    } else {
      _addTarget(name);
    }
  }

  void _addStarByName(String name) {
    _recomputeDebounce?.cancel();
    _addTarget(name);
  }

  @override
  Widget build(BuildContext context) {
    final eventType = ref.watch(heliacalEventTypeProvider);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final targets = ref.watch(heliacalTargetsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Body chips (multi-select) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Body ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ..._heliacalBodies.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(b.$2),
                      selected: targets.contains(b.$2),
                      onSelected: (_) => _toggleTarget(b.$2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Fixed star input (progressive disclosure) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _showStarInput = !_showStarInput),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showStarInput ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Fixed Star by Name',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showStarInput) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Star ', style: theme.textTheme.labelLarge),
                    const SizedBox(width: 8),
                    Expanded(child: StarSearchField(onSelect: _addStarByName)),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        // ── Event type chips + Calculate + Export ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Event ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ..._eventTypes.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(e.$2),
                      selected: eventType == e.$1,
                      onSelected: (_) =>
                          ref.read(heliacalEventTypeProvider.notifier).state =
                              e.$1,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final results = switch (ref.watch(heliacalResultProvider)) {
                      CalcOk(:final value) => value,
                      CalcError() => null,
                    };
                    final jd = ref.watch(contextBarProvider).jdUt;
                    return ExportButton(
                      hasResults: results != null && results.isNotEmpty,
                      getRows: () => results != null
                          ? heliacalToExportRows(results, ref.read(sweProvider))
                          : [],
                      filenameStem: 'swe_heliacal_${jd.toStringAsFixed(4)}',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // ── Progressive disclosure: atmospheric & observer params ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _showAtmospheric = !_showAtmospheric),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAtmospheric ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Atmospheric & Observer Conditions',
                        style: labelStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showAtmospheric) ...[
                const SizedBox(height: 8),
                // Atmosphere row
                Text(
                  'ATMOSPHERE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Pressure (mbar)',
                  _pressureController,
                  heliacalPressureProvider,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Temperature (°C)',
                  _temperatureController,
                  heliacalTemperatureProvider,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Humidity (%)',
                  _humidityController,
                  heliacalHumidityProvider,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Extinction coeff.',
                  _extinctionController,
                  heliacalExtinctionProvider,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 8),
                // Observer row
                Text(
                  'OBSERVER',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Age (years)',
                  _ageController,
                  heliacalObserverAgeProvider,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Snellen ratio',
                  _snellenController,
                  heliacalSnellenRatioProvider,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        const _ResultsView(),
      ],
    );
  }

  Widget _paramRow(
    String label,
    TextEditingController ctrl,
    StateProvider<double> provider,
    ThemeData theme,
    TextStyle? labelStyle,
  ) {
    return Row(
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ctrl,
            style: theme.textTheme.bodySmall,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            onChanged: (v) {
              final d = double.tryParse(v);
              if (d != null) {
                _debouncedSet(() => ref.read(provider.notifier).state = d);
              }
            },
          ),
        ),
      ],
    );
  }
}

// ── Results view ──────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  const _ResultsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = switch (ref.watch(heliacalResultProvider)) {
      CalcOk(:final value) => value,
      CalcError(:final message) => <HeliacalCalcResult>[
        HeliacalCalcResult(
          objectName: '(error)',
          eventType: ref.read(heliacalEventTypeProvider),
          startVisibleJd: double.nan,
          bestVisibleJd: double.nan,
          endVisibleJd: double.nan,
          error: message,
        ),
      ],
    };

    if (results.isEmpty) {
      return const Center(child: Text('Select a body or star.'));
    }

    final swe = ref.read(sweProvider);
    final utcOffset = ref.read(contextBarProvider).utcOffset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 900 ? 2 : 1;
        final cardWidth = (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in results)
                _buildResultGroup(context, ref, r, swe, utcOffset, cardWidth),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultGroup(
    BuildContext context,
    WidgetRef ref,
    HeliacalCalcResult r,
    SweUtils swe,
    double utcOffset,
    double cardWidth,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(r.objectName, style: theme.textTheme.titleMedium),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    final current = ref.read(heliacalTargetsProvider);
                    ref.read(heliacalTargetsProvider.notifier).state = current
                        .where((t) => t != r.objectName)
                        .toList();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
          if (r.hasError)
            SizedBox(
              width: cardWidth,
              child: ResultCard(
                title: r.objectName,
                subtitle: HeliacalCalcResult.eventLabel(r.eventType),
                fields: [
                  ResultField(
                    label: 'Error',
                    value: r.error!,
                    rawValue: double.nan,
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildEventCard(r, swe, utcOffset),
                ),
                SizedBox(width: cardWidth, child: _buildJdCard(r)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(HeliacalCalcResult r, SweUtils swe, double utcOffset) {
    return ResultCard(
      title: HeliacalCalcResult.eventLabel(r.eventType),
      subtitle: 'heliacalUt("${r.objectName}")',
      fields: [
        ResultField(
          label: 'Start Visible',
          value: _fmtHeliacalJd(swe, r.startVisibleJd, utcOffset),
          rawValue: r.startVisibleJd,
        ),
        ResultField(
          label: 'Best Visible',
          value: _fmtHeliacalJd(swe, r.bestVisibleJd, utcOffset),
          rawValue: r.bestVisibleJd,
        ),
        ResultField(
          label: 'End Visible',
          value: _fmtHeliacalJd(swe, r.endVisibleJd, utcOffset),
          rawValue: r.endVisibleJd,
        ),
      ],
    );
  }

  Widget _buildJdCard(HeliacalCalcResult r) {
    return ResultCard(
      title: 'Julian Days',
      subtitle: r.objectName,
      fields: [
        ResultField(
          label: 'Start (JD)',
          value: r.startVisibleJd.toStringAsFixed(6),
          rawValue: r.startVisibleJd,
        ),
        ResultField(
          label: 'Best (JD)',
          value: r.bestVisibleJd.toStringAsFixed(6),
          rawValue: r.bestVisibleJd,
        ),
        ResultField(
          label: 'End (JD)',
          value: r.endVisibleJd.toStringAsFixed(6),
          rawValue: r.endVisibleJd,
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtHeliacalJd(SweUtils swe, double jd, double utcOffset) =>
    formatJdDateTime(
      swe,
      jd,
      seconds: false,
      utcOffset: utcOffset,
      emptyPlaceholder: '—',
      fallbackDigits: 4,
    );
