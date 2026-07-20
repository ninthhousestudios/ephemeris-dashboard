// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/ephe/scanner.dart';
import 'labeled_dropdown.dart';

class JplFileSelector extends ConsumerWidget {
  const JplFileSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(contextBarProvider.select((s) => s.epheSource));
    if (source != EpheSource.jpl) return const SizedBox.shrink();

    final jplFiles = ref.watch(installedJplFilesProvider);
    if (jplFiles.isEmpty) return const SizedBox.shrink();

    final selected = ref.watch(contextBarProvider.select((s) => s.jplFilename));
    final effective = (selected != null && jplFiles.contains(selected))
        ? selected
        : jplFiles.first;

    if (effective != selected) {
      Future.microtask(
        () => ref.read(contextBarProvider.notifier).setJplFilename(effective),
      );
    }

    return LabeledDropdown<String>(
      label: 'JPL file',
      value: effective,
      items: jplFiles,
      itemLabel: (f) => f,
      onChanged: jplFiles.length <= 1
          ? null
          : (v) => ref.read(contextBarProvider.notifier).setJplFilename(v),
    );
  }
}
