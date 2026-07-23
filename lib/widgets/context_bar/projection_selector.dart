// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import 'labeled_dropdown.dart';

/// Sidereal projection-plane dropdown (SE_SIDBIT_ECL_T0 / SSY_PLANE).
///
/// Modifies how body longitudes are projected for any sidereal ayanamsha
/// (swetest `-sidt0` / `-sidsp`). Disabled when the zodiac is tropical, where
/// no sidereal projection applies.
class ProjectionSelector extends ConsumerWidget {
  const ProjectionSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projection = ref.watch(
      contextBarProvider.select((s) => s.projection),
    );
    final isTropical = ref.watch(
      contextBarProvider.select((s) => s.zodiacRef == ZodiacRef.tropical),
    );

    return LabeledDropdown<SiderealProjection>(
      label: 'Projection',
      value: projection,
      items: SiderealProjection.values,
      itemLabel: (p) => p.label,
      onChanged: isTropical
          ? null
          : (v) =>
                ref.read(contextBarProvider.notifier).setSiderealProjection(v),
    );
  }
}
