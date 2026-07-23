// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/time_scale.dart';
import 'labeled_dropdown.dart';

/// Selects the time scale the civil date/time field is entered in / displayed
/// on (swetest `-ut`/`-t`/`-utc`). View-layer only — the Moment stays a UT1
/// Julian Day; the scale is an input transform + display label.
class TimeScaleSelector extends ConsumerWidget {
  const TimeScaleSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(contextBarProvider.select((s) => s.timeScale));

    return Tooltip(
      message:
          'Time scale of the civil date/time field.\n'
          'UT1 — universal time (the canonical Moment).\n'
          'TT — terrestrial/ephemeris time (UT1 + ΔT).\n'
          'UTC — coordinated universal time (leap seconds).\n\n'
          'Switching ephemeris source changes ΔT, so a TT/UTC-displayed field '
          'shifts by ~ms while the underlying UT Moment holds — correct, not a '
          'bug.',
      child: LabeledDropdown<TimeScale>(
        label: 'Scale',
        value: scale,
        items: TimeScale.values,
        itemLabel: (t) => t.label,
        onChanged: (v) => ref.read(contextBarProvider.notifier).setTimeScale(v),
      ),
    );
  }
}
