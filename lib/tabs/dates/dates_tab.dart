// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../core/date_time_input.dart';
import '../../core/ephemeris/emitter_provider.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/code_modal.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'dates_provider.dart';

class DatesTab extends ConsumerStatefulWidget {
  const DatesTab({super.key});

  @override
  ConsumerState<DatesTab> createState() => _DatesTabState();
}

class _DatesTabState extends ConsumerState<DatesTab> {
  bool _isCustom = false;

  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _jdCtrl = TextEditingController();

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _jdCtrl.dispose();
    super.dispose();
  }

  JdUtils get _jdUtils => JdUtils(ref.read(sweProvider));

  void _syncFromContext() {
    final ctx = ref.read(contextBarProvider);
    final dt = _jdUtils.jdToDateTime(ctx.jdUt);
    _dateCtrl.text = fmtDate(dt);
    _timeCtrl.text = fmtTime(dt);
    _jdCtrl.text = ctx.jdUt.toStringAsFixed(8);
  }

  /// Commits the local editor fields into the per-tab override JD, which the
  /// result provider watches — the recompute is reactive, no Calculate press.
  void _commitFields() {
    final jd = double.tryParse(_jdCtrl.text) ?? _parseDateTime();
    if (jd != null) {
      ref.read(datesOverrideJdProvider.notifier).state = jd;
    }
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

  void _setNow() {
    final now = DateTime.now().toUtc();
    _dateCtrl.text = fmtDate(now);
    _timeCtrl.text = fmtTime(now);
    _jdCtrl.text = _jdUtils.dateTimeToJd(now).toStringAsFixed(8);
    setState(() => _isCustom = true);
    _commitFields();
  }

  void _resetToContext() {
    // Clear the override so the result provider tracks the context JD again.
    ref.read(datesOverrideJdProvider.notifier).state = null;
    setState(() {
      _isCustom = false;
      _syncFromContext();
    });
  }

  Future<void> _pickDate() async {
    final current = _parseDateFromCtrl();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(-4000),
      lastDate: DateTime(4000),
    );
    if (picked == null) return;
    _dateCtrl.text = fmtDate(picked);
    _syncJdFromDateTimeFields();
    setState(() => _isCustom = true);
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
    setState(() => _isCustom = true);
  }

  DateTime? _parseDateFromCtrl() {
    final d = parseDateFields(_dateCtrl.text);
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  void _syncJdFromDateTimeFields() {
    final jd = _parseDateTime();
    if (jd != null) {
      _jdCtrl.text = jd.toStringAsFixed(8);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep fields synced with context bar unless user has customized
    if (!_isCustom) {
      final ctx = ref.watch(contextBarProvider);
      final dt = _jdUtils.jdToDateTime(ctx.jdUt);
      final dateStr = fmtDate(dt);
      final timeStr = fmtTime(dt);
      final jdStr = ctx.jdUt.toStringAsFixed(8);
      if (_dateCtrl.text != dateStr) _dateCtrl.text = dateStr;
      if (_timeCtrl.text != timeStr) _timeCtrl.text = timeStr;
      if (_jdCtrl.text != jdStr) _jdCtrl.text = jdStr;
    }

    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isMobile = ResponsiveLayout.of(context) == ScreenSize.mobile;

    return Column(
      children: [
        // ── Date/Time input section ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date + Time + JD row using Expanded fields
              Row(
                children: [
                  // Date field
                  Text('Date ', style: labelStyle),
                  Expanded(
                    child: TextField(
                      controller: _dateCtrl,
                      style: theme.textTheme.bodySmall,
                      decoration: dateTimeInputDecoration('YYYY-MM-DD'),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                      ],
                      onChanged: (_) => setState(() => _isCustom = true),
                      onSubmitted: (_) => _commitFields(),
                    ),
                  ),
                  dateTimeIconButton(
                    Icons.calendar_today,
                    'Pick date',
                    _pickDate,
                  ),
                  const SizedBox(width: 12),
                  // Time field
                  Text('Time (UT) ', style: labelStyle),
                  Expanded(
                    child: TextField(
                      controller: _timeCtrl,
                      style: theme.textTheme.bodySmall,
                      decoration: dateTimeInputDecoration('HH:MM:SS'),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d:]')),
                      ],
                      onChanged: (_) => setState(() => _isCustom = true),
                      onSubmitted: (_) => _commitFields(),
                    ),
                  ),
                  dateTimeIconButton(Icons.access_time, 'Pick time', _pickTime),
                  const SizedBox(width: 12),
                  // JD field
                  Text('JD ', style: labelStyle),
                  Expanded(
                    child: TextField(
                      controller: _jdCtrl,
                      style: theme.textTheme.bodySmall,
                      decoration: dateTimeInputDecoration('2460000.0'),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      onChanged: (_) => setState(() => _isCustom = true),
                      onSubmitted: (_) => _commitFields(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Action buttons row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _setNow,
                      icon: const Icon(Icons.update, size: 18),
                      label: const Text('Now'),
                    ),
                    if (_isCustom) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _resetToContext,
                        icon: const Icon(Icons.sync, size: 18),
                        label: const Text('Reset to Context'),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final outcome = ref.watch(datesResultProvider);
                        final jd = ref.watch(contextBarProvider).jdUt;
                        return ExportButton(
                          hasResults: outcome is CalcOk<DatesResult>,
                          getRows: () => switch (outcome) {
                            CalcOk(value: final r) => datesToExportRows(r),
                            CalcSweError() => [],
                          },
                          filenameStem: 'swe_dates_${jd.toStringAsFixed(4)}',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        if (isMobile) _buildResults() else Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    final outcome = ref.watch(datesResultProvider);
    return switch (outcome) {
      CalcSweError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final result) => _buildResultCards(result),
    };
  }

  Widget _buildResultCards(DatesResult result) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 600 ? 2 : 1;
        final cardWidth = (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              SizedBox(
                width: cardWidth,
                child: _buildCalendarCard(context, result),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildJulianDayCard(context, result),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildTimeCard(context, result),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildLocalTimeCard(context, result),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarCard(BuildContext context, DatesResult r) {
    final t = r.revjulTime;
    final timeStr =
        '${t.h.toString().padLeft(2, '0')}:'
        '${t.m.toString().padLeft(2, '0')}:'
        '${t.s.toStringAsFixed(2).padLeft(5, '0')}';

    return ResultCard(
      title: 'Calendar',
      subtitle: 'revjul(JD UT)',
      fields: r.revjulError != null
          ? [
              ResultField(
                label: 'Error',
                value: r.revjulError!,
                rawValue: double.nan,
              ),
            ]
          : [
              ResultField(
                label: 'Year',
                value: r.revjulYear.toString(),
                rawValue: r.revjulYear.toDouble(),
              ),
              ResultField(
                label: 'Month',
                value: _monthName(r.revjulMonth),
                rawValue: r.revjulMonth.toDouble(),
              ),
              ResultField(
                label: 'Day',
                value: r.revjulDay.toString(),
                rawValue: r.revjulDay.toDouble(),
              ),
              ResultField(
                label: 'Time (UT)',
                value: timeStr,
                rawValue: r.revjulHour,
              ),
              ResultField(
                label: 'Day of Week',
                value: r.dayOfWeekName,
                rawValue: double.nan,
              ),
            ],
      onCode: () {
        final trace = ref.read(datesTraceProvider);
        final slice = trace.sliceByTab('dates');
        if (slice.entries.isEmpty) return;
        final emitter = ref.read(selectedEmitterProvider);
        final code = slice.entries.map(emitter.emitSnippet).join('\n');
        showCodeModal(context, code: code, languageLabel: emitter.displayName);
      },
    );
  }

  Widget _buildJulianDayCard(BuildContext context, DatesResult r) {
    return ResultCard(
      title: 'Julian Day',
      subtitle: 'JD UT and ET',
      fields: [
        ResultField(
          label: 'JD UT',
          value: r.jdUt.toStringAsFixed(8),
          rawValue: r.jdUt,
        ),
        ResultField(
          label: 'JD ET',
          value: r.jdEt.toStringAsFixed(8),
          rawValue: r.jdEt,
        ),
      ],
      onCode: () {
        final trace = ref.read(datesTraceProvider);
        final slice = trace.sliceByTab('dates');
        if (slice.entries.isEmpty) return;
        final emitter = ref.read(selectedEmitterProvider);
        final code = slice.entries.map(emitter.emitSnippet).join('\n');
        showCodeModal(context, code: code, languageLabel: emitter.displayName);
      },
    );
  }

  Widget _buildTimeCard(BuildContext context, DatesResult r) {
    return ResultCard(
      title: 'Time',
      subtitle: 'Delta-T · Sidereal · Equation of Time',
      fields: [
        if (r.deltaTError != null)
          ResultField(
            label: 'Delta-T Error',
            value: r.deltaTError!,
            rawValue: double.nan,
          )
        else
          ResultField(
            label: 'Delta-T (s)',
            value: r.deltaT.toStringAsFixed(3),
            rawValue: r.deltaT,
          ),
        if (r.siderealTimeError != null)
          ResultField(
            label: 'GMST Error',
            value: r.siderealTimeError!,
            rawValue: double.nan,
          )
        else
          ResultField(
            label: 'Sidereal (h)',
            value: _formatHours(r.siderealTime),
            rawValue: r.siderealTime,
          ),
        if (r.equationOfTimeError != null)
          ResultField(
            label: 'EqT Error',
            value: r.equationOfTimeError!,
            rawValue: double.nan,
          )
        else
          ResultField(
            label: 'Eq. of Time (min)',
            value: r.equationOfTimeMinutes.toStringAsFixed(4),
            rawValue: r.equationOfTimeMinutes,
          ),
      ],
      onCode: () {
        final trace = ref.read(datesTraceProvider);
        final slice = trace.sliceByTab('dates');
        if (slice.entries.isEmpty) return;
        final emitter = ref.read(selectedEmitterProvider);
        final code = slice.entries.map(emitter.emitSnippet).join('\n');
        showCodeModal(context, code: code, languageLabel: emitter.displayName);
      },
    );
  }

  Widget _buildLocalTimeCard(BuildContext context, DatesResult r) {
    return ResultCard(
      title: 'Local Time',
      subtitle: 'LMT ↔ LAT (by longitude)',
      fields: [
        if (r.lmtToLatError != null)
          ResultField(
            label: 'LMT→LAT Error',
            value: r.lmtToLatError!,
            rawValue: double.nan,
          )
        else
          ResultField(
            label: 'LMT→LAT (JD)',
            value: r.lmtToLat.toStringAsFixed(8),
            rawValue: r.lmtToLat,
          ),
        if (r.latToLmtError != null)
          ResultField(
            label: 'LAT→LMT Error',
            value: r.latToLmtError!,
            rawValue: double.nan,
          )
        else
          ResultField(
            label: 'LAT→LMT (JD)',
            value: r.latToLmt.toStringAsFixed(8),
            rawValue: r.latToLmt,
          ),
      ],
      onCode: () {
        final trace = ref.read(datesTraceProvider);
        final slice = trace.sliceByTab('dates');
        if (slice.entries.isEmpty) return;
        final emitter = ref.read(selectedEmitterProvider);
        final code = slice.entries.map(emitter.emitSnippet).join('\n');
        showCodeModal(context, code: code, languageLabel: emitter.displayName);
      },
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _monthName(int month) {
  const names = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (month < 1 || month > 12) return month.toString();
  return '${names[month]} ($month)';
}

String _formatHours(double hours) {
  final h = hours.truncate();
  final m = ((hours - h) * 60).truncate();
  final s = ((hours - h) * 3600 - m * 60);
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toStringAsFixed(2).padLeft(5, '0')}';
}
