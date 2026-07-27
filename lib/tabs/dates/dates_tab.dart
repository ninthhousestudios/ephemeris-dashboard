// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/context_provider.dart';
import '../../core/calendar.dart';
import '../../core/date_time_input.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_utils_provider.dart';
import '../../core/time_scale.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card_grid.dart';
import '../../widgets/result_section.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
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

  Calendar get _calendar => ref.read(contextBarProvider).calendar;

  /// The tab's own JD editor renders on the Context's Calendar, like every
  /// other civil date in the app. Raw civil fields rather than a [DateTime], so
  /// a Julian-only date (29 Feb 1900) survives instead of rolling to 1 Mar.
  void _syncFromContext() {
    final ctx = ref.read(contextBarProvider);
    final civil = _jdUtils.civilFieldsOn(ctx.jdUt, ctx.calendar);
    _dateCtrl.text = fmtDateFields(civil.year, civil.month, civil.day);
    _timeCtrl.text = fmtHms(civil.hour, civil.minute, civil.second);
    _jdCtrl.text = ctx.jdUt.toStringAsFixed(8);
  }

  /// Commits the JD editor into the per-tab override JD, which the result
  /// provider watches — the recompute is reactive, no Calculate press.
  void _commitJd() {
    final jd = double.tryParse(_jdCtrl.text);
    if (jd != null) {
      ref.read(datesOverrideJdProvider.notifier).state = jd;
    }
  }

  /// Commits the Date/Time editors, read on the Context Calendar.
  ///
  /// Split from [_commitJd] *by source*. One shared commit that preferred the
  /// JD field made this path unreachable: while the user types a date, _jdCtrl
  /// still holds the last good JD, so the JD parse always won and the civil
  /// entry was silently computed away.
  void _commitCivil() {
    final jd = _parseDateTime();
    if (jd == null) return;
    _jdCtrl.text = jd.toStringAsFixed(8);
    ref.read(datesOverrideJdProvider.notifier).state = jd;
  }

  double? _parseDateTime() {
    final calendar = _calendar;
    final d = parseDateFields(_dateCtrl.text, calendar: calendar);
    if (d == null) return null;
    final t = parseTimeFields(_timeCtrl.text);
    try {
      // UT and no offset: this editor is labelled "Time (UT)" and edits the JD
      // directly, so there is no scale or zone to undo.
      return _jdUtils.localCivilToJdUt(
        (
          year: d.year,
          month: d.month,
          day: d.day,
          hour: t?.hour ?? 0,
          minute: t?.minute ?? 0,
          second: t?.second ?? 0,
        ),
        calendar: calendar,
        scale: TimeScale.ut1,
        offsetHours: 0,
      );
    } on ArgumentError {
      return null;
    }
  }

  void _setNow() {
    final now = DateTime.now().toUtc();
    final jd = _jdUtils.dateTimeToJd(now);
    final civil = _jdUtils.civilFieldsOn(jd, _calendar);
    _dateCtrl.text = fmtDateFields(civil.year, civil.month, civil.day);
    _timeCtrl.text = fmtHms(civil.hour, civil.minute, civil.second);
    _jdCtrl.text = jd.toStringAsFixed(8);
    setState(() => _isCustom = true);
    _commitJd();
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
    // The picker is proleptic Gregorian; its fields are read back on the
    // Context calendar, same as a typed date.
    _dateCtrl.text = fmtDateFields(picked.year, picked.month, picked.day);
    // Commit, not just sync: a picked date that only refreshed the JD text left
    // the Calendar card showing the previous Moment until some later submit.
    _commitCivil();
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
    _commitCivil();
    setState(() => _isCustom = true);
  }

  DateTime? _parseDateFromCtrl() {
    final d = parseDateFields(_dateCtrl.text, calendar: _calendar);
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  @override
  Widget build(BuildContext context) {
    // Keep fields synced with context bar unless user has customized
    if (!_isCustom) {
      final ctx = ref.watch(contextBarProvider);
      final civil = _jdUtils.civilFieldsOn(ctx.jdUt, ctx.calendar);
      final dateStr = fmtDateFields(civil.year, civil.month, civil.day);
      final timeStr = fmtHms(civil.hour, civil.minute, civil.second);
      final jdStr = ctx.jdUt.toStringAsFixed(8);
      if (_dateCtrl.text != dateStr) _dateCtrl.text = dateStr;
      if (_timeCtrl.text != timeStr) _timeCtrl.text = timeStr;
      if (_jdCtrl.text != jdStr) _jdCtrl.text = jdStr;
    }

    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

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
                      onSubmitted: (_) => _commitCivil(),
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
                      onSubmitted: (_) => _commitCivil(),
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
                      onSubmitted: (_) => _commitJd(),
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
                        final ctx = ref.watch(contextBarProvider);
                        final jd = ctx.jdUt;
                        return ExportButton(
                          hasResults: outcome is CalcOk<DatesResult>,
                          getRows: () => switch (outcome) {
                            CalcOk(value: final r) => datesToExportRows(
                              r,
                              ctx.calendar,
                            ),
                            CalcError() => [],
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
        SeriesBar(tabId: AppTab.dates.name),
        const Divider(height: 1),
        // ── Results ──
        if (ref.watch(
          seriesSettingsProvider(AppTab.dates.name).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          _buildResults(),
      ],
    );
  }

  Widget _buildSeries() {
    final steps = ref.watch(datesSeriesProvider);
    // Watched for the same reason the Calendar card watches it: the civil
    // fields a step exports are read on the Context Calendar.
    final calendar = ref.watch(contextBarProvider.select((s) => s.calendar));

    return SeriesView(
      tabId: AppTab.dates.name,
      steps: [
        for (final (moment, outcome) in steps)
          (moment, outcome.map((r) => datesToExportRows(r, calendar))),
      ],
    );
  }

  Widget _buildResults() {
    final outcome = ref.watch(datesResultProvider);
    // Watched, not read: the Calendar card names the calendar it rendered on,
    // so switching it in the context bar must repaint the card.
    final calendar = ref.watch(contextBarProvider.select((s) => s.calendar));
    return switch (outcome) {
      CalcError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final result) => _buildResultCards(result, calendar),
    };
  }

  Widget _buildResultCards(DatesResult result, Calendar calendar) {
    return ResultCardGrid<ResultSection>.items(
      // One label/value source for cards and export alike — see datesSections.
      items: datesSections(result, calendar),
      // Two columns at most: the date cards are wide.
      maxColumns: 2,
      cardBuilder: (section) => section.toCard(),
    );
  }
}
