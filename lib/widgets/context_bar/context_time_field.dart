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

class ContextTimeField extends ConsumerStatefulWidget {
  const ContextTimeField({this.showNowButton = false, super.key});

  final bool showNowButton;

  @override
  ConsumerState<ContextTimeField> createState() => _ContextTimeFieldState();
}

class _ContextTimeFieldState extends ConsumerState<ContextTimeField> {
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

  /// The displayed local civil time: the canonical Moment rendered on the
  /// selected time scale, then shifted by the UTC offset.
  DateTime _localOf(ContextBarState ctx) {
    final civil = _jdUtils.jdUtToCivil(
      ctx.jdUt,
      calendar: ctx.calendar,
      scale: ctx.timeScale,
    );
    return _jdUtils.applyUtcOffset(civil, ctx.utcOffset);
  }

  /// Commit new civil time fields back to the canonical Moment: undo the offset,
  /// then map the scale-time civil value to a UT1 Julian Day.
  void _commitLocal(ContextBarState ctx, int hour, int minute, int second) {
    final local = _localOf(ctx);
    final newLocal = DateTime.utc(
      local.year,
      local.month,
      local.day,
      hour,
      minute,
      second,
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
    _controller.text = fmtTime(_localOf(ref.read(contextBarProvider)));
  }

  void _commit() {
    final parsed = parseTimeFields(_controller.text);
    if (parsed == null) return;
    _commitLocal(
      ref.read(contextBarProvider),
      parsed.hour,
      parsed.minute,
      parsed.second,
    );
  }

  Future<void> _pick() async {
    final ctx = ref.read(contextBarProvider);
    final local = _localOf(ctx);
    final picked = await showPreciseTimePicker(
      context: context,
      initialHour: local.hour,
      initialMinute: local.minute,
      initialSecond: local.second,
    );
    if (picked == null) return;
    _commitLocal(ctx, picked.$1, picked.$2, picked.$3);
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

    final trailing = widget.showNowButton
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dateTimeIconButton(Icons.update, 'Set to now', () {
                ref.read(contextBarProvider.notifier).setNow();
              }),
              dateTimeIconButton(Icons.access_time, 'Pick time', _pick),
            ],
          )
        : dateTimeIconButton(Icons.access_time, 'Pick time', _pick);

    return labeledField(
      context: context,
      label: 'Time',
      controller: _controller,
      focusNode: _focusNode,
      hint: 'HH:MM:SS',
      onCommit: _commit,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d:]'))],
      trailing: trailing,
    );
  }
}
