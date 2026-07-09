// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import 'labeled_dropdown.dart';

class OriginSelector extends ConsumerWidget {
  const OriginSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final origin = ref.watch(contextBarProvider.select((s) => s.origin));

    return LabeledDropdown<Origin>(
      label: 'Origin',
      value: origin,
      items: Origin.values,
      itemLabel: (o) => o.label,
      onChanged: (v) => ref.read(contextBarProvider.notifier).setOrigin(v),
    );
  }
}
