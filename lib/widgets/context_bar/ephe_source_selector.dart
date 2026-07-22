// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/ephe/scanner.dart';
import 'labeled_dropdown.dart';

class EpheSourceSelector extends ConsumerWidget {
  const EpheSourceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(contextBarProvider.select((s) => s.epheSource));
    final available = ref.watch(availableEpheSourcesProvider);
    final effectiveSource = available.contains(source)
        ? source
        : EpheSource.moshier;

    if (effectiveSource != source) {
      Future.microtask(
        () => ref
            .read(contextBarProvider.notifier)
            .setEpheSource(effectiveSource),
      );
    }

    return LabeledDropdown<EpheSource>(
      // When no .se1/JPL files are present the only entry is Moshier; the
      // disabled dropdown showing "Moshier" says that on its own.
      label: 'Ephe',
      value: effectiveSource,
      items: EpheSource.values.where(available.contains).toList(),
      itemLabel: (s) => s.label,
      onChanged: available.length <= 1
          ? null
          : (v) => ref.read(contextBarProvider.notifier).setEpheSource(v),
    );
  }
}
