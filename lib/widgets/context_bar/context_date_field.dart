// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/date_time_input.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../core/time_scale.dart';

class ContextDateField extends ConsumerStatefulWidget {
  const ContextDateField({super.key});

  @override
  ConsumerState<ContextDateField> createState() => _ContextDateFieldState();
}

class _ContextDateFieldState extends ConsumerState<ContextDateField> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _selfUpdate = false;

  JdUtils get _jdUtils => JdUtils(ref.read(sweProvider));

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        if (!_focusNode.hasFocus) _commit();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The displayed local civil date: the canonical Moment rendered on the
  /// selected time scale and calendar, then shifted by the UTC offset. Raw civil
  /// fields (not a DateTime) so a Julian-only date such as 29 Feb 1900 survives.
  Civil _localOf(ContextBarState ctx) => _jdUtils.localCivilOf(
    ctx.jdUt,
    calendar: ctx.calendar,
    scale: ctx.timeScale,
    offsetHours: ctx.utcOffset,
  );

  /// Commit new civil date fields back to the canonical Moment: keep the current
  /// time of day, undo the offset, then map the scale-time civil value to a UT1
  /// Julian Day — all in raw fields so a Julian-only date is not normalised away.
  void _commitLocal(ContextBarState ctx, int year, int month, int day) {
    final local = _localOf(ctx);
    final jdUt = _jdUtils.localCivilToJdUt(
      (
        year: year,
        month: month,
        day: day,
        hour: local.hour,
        minute: local.minute,
        second: local.second,
      ),
      calendar: ctx.calendar,
      scale: ctx.timeScale,
      offsetHours: ctx.utcOffset,
    );
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setJd(jdUt);
  }

  void _sync() {
    if (_focusNode.hasFocus) return;
    final local = _localOf(ref.read(contextBarProvider));
    _controller.text = fmtDateFields(local.year, local.month, local.day);
  }

  void _commit() {
    final ctx = ref.read(contextBarProvider);
    final text = _controller.text.trim();
    final parsed = parseDateFields(text, calendar: ctx.calendar);
    if (parsed == null) {
      // Reject invalid input (e.g. 29 Feb 1990 on the Proleptic Gregorian
      // calendar) by snapping the field back to the canonical Moment and
      // telling the user why, so a bad entry never just silently vanishes.
      // Empty is not "invalid" — it just reverts, no complaint.
      _sync();
      if (text.isNotEmpty) {
        _showInvalid('"$text" is not a valid ${ctx.calendar.label} date');
      }
      return;
    }
    _commitLocal(ctx, parsed.year, parsed.month, parsed.day);
  }

  void _showInvalid(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _pick() async {
    final ctx = ref.read(contextBarProvider);
    final local = _localOf(ctx);
    // The picker is proleptic Gregorian; a Julian-only initial date is clamped
    // to a representable one, which is fine for seeding the calendar UI.
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.utc(local.year, local.month, local.day),
      firstDate: DateTime(-4000),
      lastDate: DateTime(4000),
    );
    if (picked == null) return;
    _commitLocal(ctx, picked.year, picked.month, picked.day);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(contextBarProvider, (_, _) {
      if (_selfUpdate) {
        _selfUpdate = false;
        return;
      }
      _sync();
    });
    if (_controller.text.isEmpty) _sync();

    // Date rarely differs between UT1 and TT, but a ΔT shift can cross midnight.
    // Label only TT, matching the Time field; UT1/UTC stay a bare "Date".
    final scale = ref.watch(contextBarProvider.select((s) => s.timeScale));

    return labeledField(
      context: context,
      label: scale == TimeScale.tt ? 'Date (TT)' : 'Date',
      controller: _controller,
      focusNode: _focusNode,
      hint: 'YYYY-MM-DD',
      onCommit: _commit,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]'))],
      trailing: dateTimeIconButton(Icons.calendar_today, 'Pick date', _pick),
    );
  }
}
