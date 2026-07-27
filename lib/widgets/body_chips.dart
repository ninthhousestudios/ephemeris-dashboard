// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/body_catalog.dart';
import '../core/body_selection.dart';

/// One body chip bound to a core [BodySelection].
///
/// Deliberately *not* a whole "BodyPicker" (swe-dashboard/85): the six picker
/// surfaces differ in real ways — presets, progressive disclosure, MPC entry
/// fields, moon groups, comet lists — and a widget that took all of that as
/// configuration would be a parameter bag worse than the honest copies. What
/// they genuinely share is the chip: label from [BodyCatalog], selected state
/// read from the selection, edit written back through its notifier. That is
/// what these two widgets own, and it composes into a scrolling `Row` or a
/// `Wrap` equally well.
class BodyChip extends ConsumerWidget {
  const BodyChip({
    super.key,
    required this.selection,
    required this.body,
    this.label,
  });

  final BodySelection selection;
  final int body;

  /// Overrides [BodyCatalog.labelFor] — for chips naming a body the catalog
  /// cannot name from its id alone (a moon, a comet's pseudo-MPC number).
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(bodySelectionProvider(selection)).contains(body);
    return FilterChip(
      label: Text(label ?? BodyCatalog.labelFor(body)),
      selected: selected,
      onSelected: (_) =>
          ref.read(bodySelectionProvider(selection).notifier).toggle(body),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// The single-body counterpart of [BodyChip]: picking one replaces the
/// selection rather than adding to it.
class BodyChoiceChip extends ConsumerWidget {
  const BodyChoiceChip({
    super.key,
    required this.selection,
    required this.body,
    this.label,
  });

  final BodySelection selection;
  final int body;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(singleBodyProvider(selection)) == body;
    return ChoiceChip(
      label: Text(label ?? BodyCatalog.labelFor(body)),
      selected: selected,
      onSelected: (_) =>
          ref.read(bodySelectionProvider(selection).notifier).setSingle(body),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// A `Wrap` of [BodyChip]s over [bodies] — the shape every progressive
/// disclosure section uses. `Wrap` (never a fixed-ratio grid) per the zoom
/// rules in CLAUDE.md.
class BodyChipWrap extends StatelessWidget {
  const BodyChipWrap({
    super.key,
    required this.selection,
    required this.bodies,
    this.labels,
  });

  final BodySelection selection;
  final List<int> bodies;

  /// Per-body label overrides, for ids [BodyCatalog] cannot name.
  final Map<int, String>? labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final body in bodies)
          BodyChip(selection: selection, body: body, label: labels?[body]),
      ],
    );
  }
}

/// The single-body counterpart of [BodyChipWrap].
class BodyChoiceChipWrap extends StatelessWidget {
  const BodyChoiceChipWrap({
    super.key,
    required this.selection,
    required this.bodies,
    this.labels,
  });

  final BodySelection selection;
  final List<int> bodies;
  final Map<int, String>? labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final body in bodies)
          BodyChoiceChip(
            selection: selection,
            body: body,
            label: labels?[body],
          ),
      ],
    );
  }
}

/// The chips of [BodyChipWrap] as loose children, each with trailing padding,
/// for embedding in a horizontally scrolling `Row`.
List<Widget> bodyChipRow(BodySelection selection, List<int> bodies) => [
  for (final body in bodies)
    Padding(
      padding: const EdgeInsets.only(right: 4),
      child: BodyChip(selection: selection, body: body),
    ),
];

/// The single-body counterpart of [bodyChipRow].
List<Widget> bodyChoiceChipRow(BodySelection selection, List<int> bodies) => [
  for (final body in bodies)
    Padding(
      padding: const EdgeInsets.only(right: 4),
      child: BodyChoiceChip(selection: selection, body: body),
    ),
];
