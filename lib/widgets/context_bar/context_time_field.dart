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
  /// selected time scale and calendar, then shifted by the UTC offset. Raw civil
  /// fields (not a DateTime) so editing the time of a Julian-only date such as
  /// 29 Feb 1900 does not roll the date to 1 Mar behind the calendar's back.
  Civil _localOf(ContextBarState ctx) => _jdUtils.localCivilOf(
    ctx.jdUt,
    calendar: ctx.calendar,
    scale: ctx.timeScale,
    offsetHours: ctx.utcOffset,
  );

  /// Commit new civil time fields back to the canonical Moment: keep the current
  /// date, undo the offset, then map the scale-time civil value to a UT1 Julian
  /// Day — all in raw fields so the date is not normalised away.
  void _commitLocal(ContextBarState ctx, int hour, int minute, int second) {
    final local = _localOf(ctx);
    final jdUt = _jdUtils.localCivilToJdUt(
      (
        year: local.year,
        month: local.month,
        day: local.day,
        hour: hour,
        minute: minute,
        second: second,
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
    _controller.text = fmtHms(local.hour, local.minute, local.second);
  }

  void _commit() {
    final text = _controller.text.trim();
    final parsed = parseTimeFields(text);
    if (parsed == null) {
      // Revert to the canonical time and say why, so a bad entry (e.g. 25:00)
      // never just silently sticks. Empty reverts without complaint.
      _sync();
      if (text.isNotEmpty && mounted) {
        showInvalidEntry(context, '"$text" is not a valid time (HH:MM:SS)');
      }
      return;
    }
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

    // Only TT relabels the field: UT1/UTC are the ordinary wall-clock reading, so
    // a bare "Time" is correct; TT shifts by ΔT, so name the scale to explain it.
    final scale = ref.watch(contextBarProvider.select((s) => s.timeScale));
    final label = scale == TimeScale.tt ? 'Time (TT)' : 'Time';

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
      label: label,
      controller: _controller,
      focusNode: _focusNode,
      hint: 'HH:MM:SS',
      onCommit: _commit,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d:]'))],
      trailing: trailing,
    );
  }
}
