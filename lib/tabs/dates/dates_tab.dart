import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc_session.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/code_emitter.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
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
    _dateCtrl.text = _fmtDate(dt);
    _timeCtrl.text = _fmtTime(dt);
    _jdCtrl.text = ctx.jdUt.toStringAsFixed(8);
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

  bool get _hasCalculated =>
      ref.watch(calcSessionProvider.select((s) => s.tabHasRun('dates')));

  void _calculate() {
    final jd = double.tryParse(_jdCtrl.text) ?? _parseDateTime();
    if (jd != null) {
      ref.read(datesOverrideJdProvider.notifier).state = jd;
    }
    ref.read(calcSessionProvider.notifier).calculate(activate: {'dates'});
  }

  double? _parseDateTime() {
    try {
      final parts = _dateCtrl.text.split('-');
      if (parts.length != 3) return null;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final tParts = _timeCtrl.text.split(':');
      final hour = tParts.isNotEmpty ? int.tryParse(tParts[0]) ?? 0 : 0;
      final min = tParts.length > 1 ? int.tryParse(tParts[1]) ?? 0 : 0;
      final sec = tParts.length > 2 ? int.tryParse(tParts[2]) ?? 0 : 0;
      return _jdUtils.dateTimeToJd(DateTime.utc(year, month, day, hour, min, sec));
    } catch (_) {
      return null;
    }
  }

  void _setNow() {
    final now = DateTime.now().toUtc();
    _dateCtrl.text = _fmtDate(now);
    _timeCtrl.text = _fmtTime(now);
    _jdCtrl.text = _jdUtils.dateTimeToJd(now).toStringAsFixed(8);
    setState(() => _isCustom = true);
  }

  void _resetToContext() {
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
    _dateCtrl.text = _fmtDate(picked);
    _syncJdFromDateTimeFields();
    setState(() => _isCustom = true);
  }

  Future<void> _pickTime() async {
    final parts = _timeCtrl.text.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;

    final picked = await _showPreciseTimePicker(
      context: context,
      initialHour: h,
      initialMinute: m,
      initialSecond: s,
    );
    if (picked == null) return;
    _timeCtrl.text =
        '${picked.$1.toString().padLeft(2, '0')}:${picked.$2.toString().padLeft(2, '0')}:${picked.$3.toString().padLeft(2, '0')}';
    _syncJdFromDateTimeFields();
    setState(() => _isCustom = true);
  }

  DateTime? _parseDateFromCtrl() {
    try {
      final parts = _dateCtrl.text.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
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
      final dateStr = _fmtDate(dt);
      final timeStr = _fmtTime(dt);
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
                      decoration: _deco('YYYY-MM-DD'),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]'))],
                      onChanged: (_) => setState(() => _isCustom = true),
                      onSubmitted: (_) => _calculate(),
                    ),
                  ),
                  _iconBtn(Icons.calendar_today, 'Pick date', _pickDate),
                  const SizedBox(width: 12),
                  // Time field
                  Text('Time (UT) ', style: labelStyle),
                  Expanded(
                    child: TextField(
                      controller: _timeCtrl,
                      style: theme.textTheme.bodySmall,
                      decoration: _deco('HH:MM:SS'),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d:]'))],
                      onChanged: (_) => setState(() => _isCustom = true),
                      onSubmitted: (_) => _calculate(),
                    ),
                  ),
                  _iconBtn(Icons.access_time, 'Pick time', _pickTime),
                  const SizedBox(width: 12),
                  // JD field
                  Text('JD ', style: labelStyle),
                  Expanded(
                    child: TextField(
                      controller: _jdCtrl,
                      style: theme.textTheme.bodySmall,
                      decoration: _deco('2460000.0'),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      onChanged: (_) => setState(() => _isCustom = true),
                      onSubmitted: (_) => _calculate(),
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
                    FilledButton.icon(
                      onPressed: _calculate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: const Text('Calculate'),
                    ),
                    const SizedBox(width: 8),
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
                    Consumer(builder: (context, ref, _) {
                      final result = ref.watch(datesResultProvider);
                      final jd = ref.watch(contextBarProvider).jdUt;
                      return ExportButton(
                        hasResults: _hasCalculated && result != null,
                        getRows: () =>
                            result != null ? datesToExportRows(result) : [],
                        filenameStem: 'swe_dates_${jd.toStringAsFixed(4)}',
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        Expanded(
          child: _hasCalculated ? _buildResults() : _buildPlaceholder(),
        ),
      ],
    );
  }

  static InputDecoration _deco(String hint) => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        hintText: hint,
        border: const OutlineInputBorder(),
      );

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 14),
      padding: const EdgeInsets.only(left: 4),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Text('Press Calculate to show date/time conversions'),
    );
  }

  Widget _buildResults() {
    final result = ref.watch(datesResultProvider);
    if (result == null) {
      return const Center(child: Text('No result'));
    }

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
              SizedBox(width: cardWidth, child: _buildCalendarCard(context, result)),
              SizedBox(width: cardWidth, child: _buildJulianDayCard(context, result)),
              SizedBox(width: cardWidth, child: _buildTimeCard(context, result)),
              SizedBox(width: cardWidth, child: _buildLocalTimeCard(context, result)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarCard(BuildContext context, DatesResult r) {
    final t = r.revjulTime;
    final timeStr = '${t.h.toString().padLeft(2, '0')}:'
        '${t.m.toString().padLeft(2, '0')}:'
        '${t.s.toStringAsFixed(2).padLeft(5, '0')}';

    return ResultCard(
      title: 'Calendar',
      subtitle: 'revjul(JD UT)',
      fields: r.revjulError != null
          ? [ResultField(label: 'Error', value: r.revjulError!, rawValue: double.nan)]
          : [
              ResultField(label: 'Year', value: r.revjulYear.toString(), rawValue: r.revjulYear.toDouble()),
              ResultField(label: 'Month', value: _monthName(r.revjulMonth), rawValue: r.revjulMonth.toDouble()),
              ResultField(label: 'Day', value: r.revjulDay.toString(), rawValue: r.revjulDay.toDouble()),
              ResultField(label: 'Time (UT)', value: timeStr, rawValue: r.revjulHour),
              ResultField(label: 'Day of Week', value: r.dayOfWeekName, rawValue: double.nan),
            ],
      onCode: () {
        final trace = ref.read(callTraceProvider);
        if (trace == null) return;
        final slice = trace.sliceByTab('dates');
        if (slice.entries.isEmpty) return;
        const emitter = CEmitter();
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
        ResultField(label: 'JD UT', value: r.jdUt.toStringAsFixed(8), rawValue: r.jdUt),
        ResultField(label: 'JD ET', value: r.jdEt.toStringAsFixed(8), rawValue: r.jdEt),
      ],
      onCode: () {
        final trace = ref.read(callTraceProvider);
        if (trace == null) return;
        final slice = trace.sliceByTab('dates');
        if (slice.entries.isEmpty) return;
        const emitter = CEmitter();
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
          ResultField(label: 'Delta-T Error', value: r.deltaTError!, rawValue: double.nan)
        else
          ResultField(label: 'Delta-T (s)', value: r.deltaT.toStringAsFixed(3), rawValue: r.deltaT),
        if (r.siderealTimeError != null)
          ResultField(label: 'GMST Error', value: r.siderealTimeError!, rawValue: double.nan)
        else
          ResultField(label: 'Sidereal (h)', value: _formatHours(r.siderealTime), rawValue: r.siderealTime),
        if (r.equationOfTimeError != null)
          ResultField(label: 'EqT Error', value: r.equationOfTimeError!, rawValue: double.nan)
        else
          ResultField(label: 'Eq. of Time (min)', value: r.equationOfTimeMinutes.toStringAsFixed(4), rawValue: r.equationOfTimeMinutes),
      ],
      onCode: () {
        final trace = ref.read(callTraceProvider);
        if (trace == null) return;
        final slice = trace.sliceByTab('dates');
        if (slice.entries.isEmpty) return;
        const emitter = CEmitter();
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
          ResultField(label: 'LMT→LAT Error', value: r.lmtToLatError!, rawValue: double.nan)
        else
          ResultField(label: 'LMT→LAT (JD)', value: r.lmtToLat.toStringAsFixed(8), rawValue: r.lmtToLat),
        if (r.latToLmtError != null)
          ResultField(label: 'LAT→LMT Error', value: r.latToLmtError!, rawValue: double.nan)
        else
          ResultField(label: 'LAT→LMT (JD)', value: r.latToLmt.toStringAsFixed(8), rawValue: r.latToLmt),
      ],
      onCode: () {
        final trace = ref.read(callTraceProvider);
        if (trace == null) return;
        final slice = trace.sliceByTab('dates');
        if (slice.entries.isEmpty) return;
        const emitter = CEmitter();
        final code = slice.entries.map(emitter.emitSnippet).join('\n');
        showCodeModal(context, code: code, languageLabel: emitter.displayName);
      },
    );
  }

  /// Precise time picker dialog with hour/minute/second spinners.
  static Future<(int, int, int)?> _showPreciseTimePicker({
    required BuildContext context,
    required int initialHour,
    required int initialMinute,
    required int initialSecond,
  }) {
    var h = initialHour;
    var m = initialMinute;
    var s = initialSecond;
    return showDialog<(int, int, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final spinnerStyle =
              Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontFamily: 'monospace');
          final colonStyle =
              Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontFamily: 'monospace');

          Widget spinner(String label, int value, int max, ValueChanged<int> onChanged) {
            return IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Theme.of(ctx).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_up),
                    onPressed: () => setState(() => onChanged((value + 1) % (max + 1))),
                  ),
                  TextField(
                    controller: TextEditingController(text: value.toString().padLeft(2, '0')),
                    textAlign: TextAlign.center,
                    style: spinnerStyle,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    onChanged: (text) {
                      final v = int.tryParse(text);
                      if (v != null && v >= 0 && v <= max) onChanged(v);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_down),
                    onPressed: () =>
                        setState(() => onChanged((value - 1 + max + 1) % (max + 1))),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            title: const Text('Set Time'),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                spinner('Hour', h, 23, (v) => h = v),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':', style: colonStyle),
                ),
                spinner('Min', m, 59, (v) => m = v),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':', style: colonStyle),
                ),
                spinner('Sec', s, 59, (v) => s = v),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop((h, m, s)),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _monthName(int month) {
  const names = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
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
