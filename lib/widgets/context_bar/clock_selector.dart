// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/display_format.dart';
import '../../core/output_clock.dart';
import 'labeled_dropdown.dart';

/// Selects which clock event times and Moments are rendered in (UT / civil UTC
/// offset / LMT / LAT). View-layer only — the Moment stays a UT Julian Day.
class ClockSelector extends ConsumerWidget {
  const ClockSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clock = ref.watch(outputClockProvider);

    return LabeledDropdown<OutputClock>(
      label: 'Clock',
      value: clock,
      items: OutputClock.values,
      itemLabel: (c) => c.label,
      onChanged: (v) => ref.read(outputClockProvider.notifier).state = v,
    );
  }
}
