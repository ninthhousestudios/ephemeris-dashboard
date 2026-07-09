// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import 'labeled_dropdown.dart';

class EqRefSelector extends ConsumerWidget {
  const EqRefSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqRef = ref.watch(contextBarProvider.select((s) => s.eqRef));

    return LabeledDropdown<EqRef>(
      label: 'Eq. Ref',
      value: eqRef,
      items: EqRef.values,
      itemLabel: (e) => e.label,
      onChanged: (v) => ref.read(contextBarProvider.notifier).setEqRef(v),
    );
  }
}
