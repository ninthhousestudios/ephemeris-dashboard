// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calendar.dart';
import '../../core/context_provider.dart';
import 'labeled_dropdown.dart';

/// Selects which calendar civil dates are read in / rendered on. View-layer
/// only — the Moment stays a Julian Day.
class CalendarSelector extends ConsumerWidget {
  const CalendarSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(contextBarProvider.select((s) => s.calendar));

    return LabeledDropdown<Calendar>(
      label: 'Calendar',
      value: calendar,
      items: Calendar.values,
      itemLabel: (c) => c.label,
      onChanged: (v) => ref.read(contextBarProvider.notifier).setCalendar(v),
    );
  }
}
