// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/date_time_input.dart';

class ContextUtcField extends ConsumerStatefulWidget {
  const ContextUtcField({super.key});

  @override
  ConsumerState<ContextUtcField> createState() => _ContextUtcFieldState();
}

class _ContextUtcFieldState extends ConsumerState<ContextUtcField> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _selfUpdate = false;

  static final _utcOffsets = [
    for (int h = -12; h <= 12; h++)
      for (final m in [0, 30])
        if (h != 12 || m == 0) h + m / 60.0,
  ];

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
    _controller.text = fmtOffset(ctx.utcOffset);
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final sign = text.startsWith('-') ? -1.0 : 1.0;
    final stripped = text.replaceAll(RegExp(r'^[+-]'), '');
    final parts = stripped.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setUtcOffset(sign * (h + m / 60.0));
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

    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final fieldStyle = isMobile
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.bodySmall;

    return Row(
      children: [
        Text('UTC ', style: labelStyle),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: fieldStyle,
            decoration: dateTimeInputDecoration('+00:00'),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d:+-]')),
            ],
            onSubmitted: (_) => _commit(),
            onEditingComplete: _commit,
          ),
        ),
        PopupMenuButton<double>(
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: 'Select UTC offset',
          itemBuilder: (_) => _utcOffsets
              .map(
                (o) => PopupMenuItem(
                  value: o,
                  height: 32,
                  child: Text(fmtOffset(o), style: fieldStyle),
                ),
              )
              .toList(),
          onSelected: (offset) {
            ref.read(contextBarProvider.notifier).setUtcOffset(offset);
          },
        ),
      ],
    );
  }
}
