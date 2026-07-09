// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import 'labeled_dropdown.dart';

class ZodiacRefSelector extends ConsumerWidget {
  const ZodiacRefSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zodiacRef = ref.watch(contextBarProvider.select((s) => s.zodiacRef));

    return LabeledDropdown<ZodiacRef>(
      label: 'Zodiac',
      value: zodiacRef,
      items: ZodiacRef.values,
      itemLabel: (z) => z.label,
      onChanged: (v) => ref.read(contextBarProvider.notifier).setZodiacRef(v),
    );
  }
}
