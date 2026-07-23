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
  /// selected time scale, then shifted by the UTC offset.
  DateTime _localOf(ContextBarState ctx) {
    final civil = _jdUtils.jdUtToCivil(
      ctx.jdUt,
      calendar: ctx.calendar,
      scale: ctx.timeScale,
    );
    return _jdUtils.applyUtcOffset(civil, ctx.utcOffset);
  }

  /// Commit new civil date fields back to the canonical Moment: keep the current
  /// time of day, undo the offset, then map the scale-time civil value to a UT1
  /// Julian Day.
  void _commitLocal(ContextBarState ctx, int year, int month, int day) {
    final local = _localOf(ctx);
    final newLocal = DateTime.utc(
      year,
      month,
      day,
      local.hour,
      local.minute,
      local.second,
    );
    final scaleCivil = _jdUtils.removeUtcOffset(newLocal, ctx.utcOffset);
    final jdUt = _jdUtils.civilToJdUt(
      scaleCivil,
      calendar: ctx.calendar,
      scale: ctx.timeScale,
    );
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setJd(jdUt);
  }

  void _sync() {
    if (_focusNode.hasFocus) return;
    _controller.text = fmtDate(_localOf(ref.read(contextBarProvider)));
  }

  void _commit() {
    final parsed = parseDateFields(_controller.text);
    if (parsed == null) return;
    _commitLocal(
      ref.read(contextBarProvider),
      parsed.year,
      parsed.month,
      parsed.day,
    );
  }

  Future<void> _pick() async {
    final ctx = ref.read(contextBarProvider);
    final local = _localOf(ctx);
    final picked = await showDatePicker(
      context: context,
      initialDate: local,
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
