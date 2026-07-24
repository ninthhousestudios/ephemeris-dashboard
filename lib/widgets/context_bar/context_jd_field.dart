// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/date_time_input.dart';
import '../../core/swe_service.dart';
import '../../core/swe_utils.dart';
import '../../core/time_scale.dart';

class ContextJdField extends ConsumerStatefulWidget {
  const ContextJdField({super.key});

  @override
  ConsumerState<ContextJdField> createState() => _ContextJdFieldState();
}

class _ContextJdFieldState extends ConsumerState<ContextJdField> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _selfUpdate = false;

  SweUtils get _swe => ref.read(sweProvider);

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

  /// The Julian Day shown for the current scale. TT shows JD(TT) = ut + ΔT;
  /// UT1 and UTC show the canonical JD(UT) — UTC has no Julian Day of its own,
  /// so a UTC instant reads as its UT1 JD.
  double _displayJd(ContextBarState ctx) => ctx.timeScale == TimeScale.tt
      ? ctx.jdUt + _swe.deltat(ctx.jdUt)
      : ctx.jdUt;

  void _sync() {
    if (_focusNode.hasFocus) return;
    _controller.text = _displayJd(
      ref.read(contextBarProvider),
    ).toStringAsFixed(6);
  }

  void _commit() {
    final text = _controller.text.trim();
    final entered = double.tryParse(text);
    if (entered == null) {
      // Snap back to the canonical Moment and say why, matching the date and
      // time fields: a rejected entry that just vanished on blur looked like
      // the field had eaten it. Empty is not "invalid" — it reverts silently.
      _sync();
      if (text.isNotEmpty && mounted) {
        showInvalidEntry(context, '"$text" is not a valid Julian Day');
      }
      return;
    }
    final ctx = ref.read(contextBarProvider);
    // In TT the entered value is a JD on the TT scale: step back one ΔT to the
    // canonical UT1 JD (as swetest does), so Moment.ut stays canonical.
    final jdUt = ctx.timeScale == TimeScale.tt
        ? entered - _swe.deltat(entered)
        : entered;
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setJd(jdUt);
  }

  @override
  Widget build(BuildContext context) {
    final scale = ref.watch(contextBarProvider.select((s) => s.timeScale));
    ref.listen(contextBarProvider, (_, _) {
      if (_selfUpdate) {
        _selfUpdate = false;
        return;
      }
      _sync();
    });
    if (_controller.text.isEmpty) _sync();

    return labeledField(
      context: context,
      label: scale == TimeScale.tt ? 'JD (TT)' : 'JD (UT)',
      controller: _controller,
      focusNode: _focusNode,
      hint: '2460000.0',
      onCommit: _commit,
      // '-' is allowed through: the engine's range reaches back past JD 0, and
      // silently swallowing the sign turned "-100" into "100" — the same
      // vanishing-keystroke problem the snackbar above fixes. Anything the
      // formatter now lets through that is not a number is caught on commit.
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.\-]'))],
    );
  }
}
