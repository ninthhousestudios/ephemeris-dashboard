import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/swe_service.dart';
import 'labeled_dropdown.dart';

class EpheSourceSelector extends ConsumerWidget {
  const EpheSourceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(contextBarProvider.select((s) => s.epheSource));
    final noFiles = !hasEpheFiles;

    // When no ephemeris files exist, force Moshier and disable the dropdown.
    final effectiveSource = noFiles ? EpheSource.moshier : source;

    return LabeledDropdown<EpheSource>(
      label: noFiles ? 'Ephe (Moshier only)' : 'Ephe',
      value: effectiveSource,
      items: noFiles ? [EpheSource.moshier] : EpheSource.values,
      itemLabel: (s) => s.label,
      onChanged: noFiles
          ? null
          : (v) => ref.read(contextBarProvider.notifier).setEpheSource(v),
    );
  }
}
