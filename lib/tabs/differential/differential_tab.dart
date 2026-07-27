// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';
import '../../core/body_catalog.dart';
import '../../core/body_selection.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/date_time_input.dart';
import '../../core/display_format.dart';
import '../../core/export_service.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_utils_provider.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/export_button.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import 'differential_provider.dart';

class DifferentialTab extends ConsumerStatefulWidget {
  const DifferentialTab({super.key});

  @override
  ConsumerState<DifferentialTab> createState() => _DifferentialTabState();
}

class _DifferentialTabState extends ConsumerState<DifferentialTab> {
  /// The bodies behind "Extra": centaurs and minors, Earth, and the
  /// interpolated lunar apsides.
  static const _extraBodies = <int>[
    ...BodyCatalog.centaursAndMinors,
    seEarth,
    ...BodyCatalog.interpolatedPoints,
  ];

  bool _showExtraBodies = false;
  bool _showAsteroids = false;
  bool _isCustomTime = false;
  final _asteroidCtrlA = TextEditingController();
  final _asteroidCtrlB = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _jdCtrl = TextEditingController();

  @override
  void dispose() {
    _asteroidCtrlA.dispose();
    _asteroidCtrlB.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _jdCtrl.dispose();
    super.dispose();
  }

  JdUtils get _jdUtils => JdUtils(ref.read(sweProvider));

  void _syncTimeFromContext() {
    final ctx = ref.read(contextBarProvider);
    final dt = _jdUtils.jdToDateTime(ctx.jdUt);
    _dateCtrl.text = fmtDate(dt);
    _timeCtrl.text = fmtTime(dt);
    _jdCtrl.text = ctx.jdUt.toStringAsFixed(8);
  }

  double? _parseDateTime() {
    final d = parseDateFields(_dateCtrl.text);
    if (d == null) return null;
    final t = parseTimeFields(_timeCtrl.text);
    try {
      return _jdUtils.dateTimeToJd(
        DateTime.utc(
          d.year,
          d.month,
          d.day,
          t?.hour ?? 0,
          t?.minute ?? 0,
          t?.second ?? 0,
        ),
      );
    } on ArgumentError {
      return null;
    }
  }

  void _syncJdFromDateTimeFields() {
    final jd = _parseDateTime();
    if (jd != null) _jdCtrl.text = jd.toStringAsFixed(8);
  }

  void _setNow() {
    final now = DateTime.now().toUtc();
    _dateCtrl.text = fmtDate(now);
    _timeCtrl.text = fmtTime(now);
    _jdCtrl.text = _jdUtils.dateTimeToJd(now).toStringAsFixed(8);
    setState(() => _isCustomTime = true);
  }

  void _resetToContext() {
    setState(() {
      _isCustomTime = false;
      _syncTimeFromContext();
    });
    ref.read(diffOverrideJdProvider.notifier).state = null;
  }

  void _commitTimeOverride() {
    final jd = double.tryParse(_jdCtrl.text) ?? _parseDateTime();
    if (jd != null) {
      ref.read(diffOverrideJdProvider.notifier).state = jd;
    }
  }

  Future<void> _pickDate() async {
    final d = parseDateFields(_dateCtrl.text);
    final current = d != null ? DateTime(d.year, d.month, d.day) : null;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(-4000),
      lastDate: DateTime(4000),
    );
    if (picked == null) return;
    _dateCtrl.text = fmtDate(picked);
    _syncJdFromDateTimeFields();
    setState(() => _isCustomTime = true);
    _commitTimeOverride();
  }

  Future<void> _pickTime() async {
    final t = parseTimeFields(_timeCtrl.text);
    final picked = await showPreciseTimePicker(
      context: context,
      initialHour: t?.hour ?? 0,
      initialMinute: t?.minute ?? 0,
      initialSecond: t?.second ?? 0,
    );
    if (picked == null) return;
    _timeCtrl.text = fmtHms(picked.$1, picked.$2, picked.$3);
    _syncJdFromDateTimeFields();
    setState(() => _isCustomTime = true);
    _commitTimeOverride();
  }

  // ── Body selection ──

  void _setBodyA(int body) => ref
      .read(bodySelectionProvider(BodySelection.differentialBodyA).notifier)
      .setSingle(body);

  void _setBodyB(int body) => ref
      .read(bodySelectionProvider(BodySelection.differentialBodyB).notifier)
      .setSingle(body);

  void _addAsteroidA() {
    final n = int.tryParse(_asteroidCtrlA.text.trim());
    if (n != null && n > 0) {
      _setBodyA(seAstOffset + n);
      _asteroidCtrlA.clear();
    }
  }

  void _addAsteroidB() {
    final n = int.tryParse(_asteroidCtrlB.text.trim());
    if (n != null && n > 0) {
      _setBodyB(seAstOffset + n);
      _asteroidCtrlB.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync time fields from context when not custom
    if (!_isCustomTime) {
      final ctx = ref.watch(contextBarProvider);
      final dt = _jdUtils.jdToDateTime(ctx.jdUt);
      final dateStr = fmtDate(dt);
      final timeStr = fmtTime(dt);
      final jdStr = ctx.jdUt.toStringAsFixed(8);
      if (_dateCtrl.text != dateStr) _dateCtrl.text = dateStr;
      if (_timeCtrl.text != timeStr) _timeCtrl.text = timeStr;
      if (_jdCtrl.text != jdStr) _jdCtrl.text = jdStr;
    }

    final bodyA = ref.watch(
      singleBodyProvider(BodySelection.differentialBodyA),
    );
    final bodyB = ref.watch(
      singleBodyProvider(BodySelection.differentialBodyB),
    );
    final fmt = ref.watch(diffFormatProvider);
    final jd = ref.watch(contextBarProvider).jdUt;
    final diffOutcome = ref.watch(diffResultProvider);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Date/Time input row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text('Date ', style: labelStyle),
              Expanded(
                child: TextField(
                  controller: _dateCtrl,
                  style: theme.textTheme.bodySmall,
                  decoration: dateTimeInputDecoration('YYYY-MM-DD'),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                  ],
                  onChanged: (_) {
                    setState(() => _isCustomTime = true);
                    _syncJdFromDateTimeFields();
                    _commitTimeOverride();
                  },
                ),
              ),
              dateTimeIconButton(Icons.calendar_today, 'Pick date', _pickDate),
              const SizedBox(width: 12),
              Text('Time (UT) ', style: labelStyle),
              Expanded(
                child: TextField(
                  controller: _timeCtrl,
                  style: theme.textTheme.bodySmall,
                  decoration: dateTimeInputDecoration('HH:MM:SS'),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d:]')),
                  ],
                  onChanged: (_) {
                    setState(() => _isCustomTime = true);
                    _syncJdFromDateTimeFields();
                    _commitTimeOverride();
                  },
                ),
              ),
              dateTimeIconButton(Icons.access_time, 'Pick time', _pickTime),
              const SizedBox(width: 12),
              Text('JD ', style: labelStyle),
              Expanded(
                child: TextField(
                  controller: _jdCtrl,
                  style: theme.textTheme.bodySmall,
                  decoration: dateTimeInputDecoration('2460000.0'),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  onChanged: (_) {
                    setState(() => _isCustomTime = true);
                    _commitTimeOverride();
                  },
                ),
              ),
              if (_isCustomTime) ...[
                const SizedBox(width: 4),
                dateTimeIconButton(
                  Icons.sync,
                  'Reset to context',
                  _resetToContext,
                ),
              ],
              dateTimeIconButton(Icons.update, 'Now', _setNow),
            ],
          ),
        ),
        // ── Body A chip row ──
        _buildBodyRow(
          'Body A',
          bodyA,
          _setBodyA,
          _asteroidCtrlA,
          _addAsteroidA,
          theme,
        ),
        // ── Body B chip row ──
        _buildBodyRow(
          'Body B',
          bodyB,
          _setBodyB,
          _asteroidCtrlB,
          _addAsteroidB,
          theme,
        ),
        // ── Progressive disclosure ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _showExtraBodies = !_showExtraBodies),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showExtraBodies ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text('More bodies', style: labelStyle),
                  ],
                ),
              ),
              if (_showExtraBodies) ...[
                const SizedBox(height: 4),
                _buildExtraSection(bodyA, bodyB, theme),
              ],
            ],
          ),
        ),
        // ── Format + export row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SegmentedButton<DisplayFormat>(
                  segments: DisplayFormat.values
                      .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                      .toList(),
                  selected: {fmt},
                  onSelectionChanged: (s) =>
                      ref.read(diffFormatProvider.notifier).state = s.first,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                ExportButton(
                  hasResults: diffOutcome is CalcOk<DiffResult>,
                  getRows: () {
                    return switch (diffOutcome) {
                      CalcOk(value: final result) => diffToExportRows(
                        result,
                        ref.read(diffFormatProvider),
                      ),
                      CalcError() => [],
                    };
                  },
                  filenameStem: 'swe_differential_${jd.toStringAsFixed(4)}',
                ),
              ],
            ),
          ),
        ),
        SeriesBar(tabId: AppTab.differential.name),
        const Divider(height: 1),
        // ── Results ──
        if (ref.watch(
          seriesSettingsProvider(
            AppTab.differential.name,
          ).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          _DiffResults(),
      ],
    );
  }

  Widget _buildSeries() {
    final format = ref.watch(diffFormatProvider);
    final steps = ref.watch(diffSeriesProvider);

    List<ExportRow> rows(DiffResult result) => diffToExportRows(result, format);

    return SeriesView(
      tabId: AppTab.differential.name,
      steps: [
        for (final (moment, outcome) in steps) (moment, outcome.map(rows)),
      ],
    );
  }

  /// Builds a single-select chip row for Body A or Body B (default bodies only).
  Widget _buildBodyRow(
    String label,
    int selected,
    ValueChanged<int> onSelect,
    TextEditingController asteroidCtrl,
    VoidCallback onAddAsteroid,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('$label ', style: theme.textTheme.labelLarge),
            const SizedBox(width: 4),
            ...BodyCatalog.full.map(
              (body) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(BodyCatalog.labelFor(body)),
                  selected: selected == body,
                  onSelected: (_) => onSelect(body),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the progressive disclosure extra bodies section.
  Widget _buildExtraSection(int bodyA, int bodyB, ThemeData theme) {
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Extra bodies — two rows (A and B select)
        Text('Extra — click for A, long-press for B', style: labelStyle),
        const SizedBox(height: 2),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: _extraBodies
              .map((body) => _dualSelectChip(body, bodyA, bodyB, theme))
              .toList(),
        ),
        const SizedBox(height: 4),
        Text('Uranian', style: labelStyle),
        const SizedBox(height: 2),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: BodyCatalog.uranian
              .map((body) => _dualSelectChip(body, bodyA, bodyB, theme))
              .toList(),
        ),
        const SizedBox(height: 4),
        // Asteroids disclosure
        InkWell(
          onTap: () => setState(() => _showAsteroids = !_showAsteroids),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showAsteroids ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text('Asteroids (by MPC number)', style: labelStyle),
            ],
          ),
        ),
        if (_showAsteroids) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: BodyCatalog.namedAsteroids.entries.map((e) {
              final bodyId = seAstOffset + e.key;
              return _dualSelectChip(
                bodyId,
                bodyA,
                bodyB,
                theme,
                label: e.value,
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('A: ', style: labelStyle),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _asteroidCtrlA,
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
                  onSubmitted: (_) => _addAsteroidA(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Set Body A to asteroid',
                onPressed: _addAsteroidA,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 12),
              Text('B: ', style: labelStyle),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _asteroidCtrlB,
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
                  onSubmitted: (_) => _addAsteroidB(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Set Body B to asteroid',
                onPressed: _addAsteroidB,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// A chip that sets Body A on tap, Body B on long-press.
  /// Highlighted if it matches either selection.
  Widget _dualSelectChip(
    int body,
    int bodyA,
    int bodyB,
    ThemeData theme, {
    String? label,
  }) {
    final isA = body == bodyA;
    final isB = body == bodyB;
    final chipLabel = label ?? BodyCatalog.labelFor(body);

    return GestureDetector(
      onLongPress: () => _setBodyB(body),
      child: ChoiceChip(
        label: Text(
          isA && isB
              ? '$chipLabel (A+B)'
              : isA
              ? '$chipLabel (A)'
              : isB
              ? '$chipLabel (B)'
              : chipLabel,
        ),
        selected: isA || isB,
        selectedColor: isA && isB
            ? theme.colorScheme.tertiary.withValues(alpha: 0.3)
            : isA
            ? theme.colorScheme.primary.withValues(alpha: 0.2)
            : theme.colorScheme.secondary.withValues(alpha: 0.2),
        onSelected: (_) => _setBodyA(body),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _DiffResults extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(diffResultProvider);
    final fmt = ref.watch(diffFormatProvider);

    return switch (outcome) {
      CalcError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final result) => _resultCard(result, fmt),
    };
  }

  // One label/value source for the card and export alike — see diffSections.
  Widget _resultCard(DiffResult result, DisplayFormat fmt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: diffSections(result, fmt).first.toCard(),
    );
  }
}
