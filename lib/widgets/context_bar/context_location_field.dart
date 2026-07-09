// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/date_time_input.dart';

enum LocationFieldKind { latitude, longitude, altitude, city }

class ContextLocationField extends ConsumerStatefulWidget {
  const ContextLocationField(this.kind, {super.key});

  final LocationFieldKind kind;

  @override
  ConsumerState<ContextLocationField> createState() =>
      _ContextLocationFieldState();
}

class _ContextLocationFieldState extends ConsumerState<ContextLocationField> {
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
    _controller.text = switch (widget.kind) {
      LocationFieldKind.latitude => fmtCoord(ctx.latitude),
      LocationFieldKind.longitude => fmtCoord(ctx.longitude),
      LocationFieldKind.altitude => ctx.altitude.round().toString(),
      LocationFieldKind.city => ctx.cityLabel,
    };
  }

  void _commit() {
    final notifier = ref.read(contextBarProvider.notifier);
    _selfUpdate = true;
    switch (widget.kind) {
      case LocationFieldKind.latitude:
        notifier.setLatitude(double.tryParse(_controller.text) ?? 0);
      case LocationFieldKind.longitude:
        notifier.setLongitude(double.tryParse(_controller.text) ?? 0);
      case LocationFieldKind.altitude:
        notifier.setAltitude(double.tryParse(_controller.text) ?? 0);
      case LocationFieldKind.city:
        notifier.setCityLabel(_controller.text);
    }
  }

  String get _label => switch (widget.kind) {
    LocationFieldKind.latitude => 'Lat',
    LocationFieldKind.longitude => 'Lon',
    LocationFieldKind.altitude => 'Alt',
    LocationFieldKind.city => 'City',
  };

  String get _hint => switch (widget.kind) {
    LocationFieldKind.city => 'City',
    _ => '0',
  };

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

    final isNumeric = widget.kind != LocationFieldKind.city;
    return labeledField(
      context: context,
      label: _label,
      controller: _controller,
      focusNode: _focusNode,
      hint: _hint,
      onCommit: _commit,
      formatters: isNumeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.+-]'))]
          : null,
    );
  }
}
