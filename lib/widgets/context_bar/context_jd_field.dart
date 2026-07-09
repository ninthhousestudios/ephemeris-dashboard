// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../core/context_provider.dart';
import '../../core/date_time_input.dart';

class ContextJdField extends ConsumerStatefulWidget {
  const ContextJdField({super.key});

  @override
  ConsumerState<ContextJdField> createState() => _ContextJdFieldState();
}

class _ContextJdFieldState extends ConsumerState<ContextJdField> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _selfUpdate = false;

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

  void _sync() {
    if (_focusNode.hasFocus) return;
    final ctx = ref.read(contextBarProvider);
    _controller.text = ctx.jdUt.toStringAsFixed(6);
  }

  void _commit() {
    final jd = double.tryParse(_controller.text);
    if (jd == null) return;
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setJd(jd);
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

    return labeledField(
      context: context,
      label: 'JD (UT)',
      controller: _controller,
      focusNode: _focusNode,
      hint: '2460000.0',
      onCommit: _commit,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
    );
  }
}
