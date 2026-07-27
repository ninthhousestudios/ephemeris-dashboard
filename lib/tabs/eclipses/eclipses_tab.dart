// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/display_format.dart';
import '../../core/swe_utils_provider.dart';
import '../../widgets/export_button.dart';
import '../../widgets/star_search_field.dart';
import 'eclipses_provider.dart';

class EclipsesTab extends ConsumerStatefulWidget {
  const EclipsesTab({super.key});

  @override
  ConsumerState<EclipsesTab> createState() => _EclipsesTabState();
}

/// Bright near-ecliptic stars the Moon regularly occults.
const _occultStars = <String>[
  'Aldebaran',
  'Regulus',
  'Spica',
  'Antares',
  'Pollux',
];

const _localFilterTooltip =
    'Type filtering is unavailable under Local scope: the engine searches for '
    'the next eclipse visible at the location, and those calls take no '
    'eclipse-type argument. Switch to Global to filter by type.';

class _EclipsesTabState extends ConsumerState<EclipsesTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eclType = ref.watch(eclipseTypeProvider);
    final scope = ref.watch(eclipseScopeProvider);
    final filter = ref.watch(eclipseFilterProvider);
    final count = ref.watch(eclipseCountProvider);
    final outcome = ref.watch(eclipseResultsProvider);
    // The *WhenLoc engine calls take no eclType, so under Local scope the
    // filter chips would advertise a constraint the search never receives.
    final filterApplies = eclipseFilterApplies(scope);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Solar / Lunar toggle ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Body ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Solar'),
                  selected: eclType == EclipseType.solar,
                  onSelected: (_) =>
                      ref.read(eclipseTypeProvider.notifier).state =
                          EclipseType.solar,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Lunar'),
                  selected: eclType == EclipseType.lunar,
                  onSelected: (_) =>
                      ref.read(eclipseTypeProvider.notifier).state =
                          EclipseType.lunar,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Occultation'),
                  selected: eclType == EclipseType.occultation,
                  onSelected: (_) =>
                      ref.read(eclipseTypeProvider.notifier).state =
                          EclipseType.occultation,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 16),
                Text('Scope ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Global'),
                  selected: scope == EclipseScope.global,
                  onSelected: (_) =>
                      ref.read(eclipseScopeProvider.notifier).state =
                          EclipseScope.global,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Local'),
                  selected: scope == EclipseScope.local,
                  onSelected: (_) =>
                      ref.read(eclipseScopeProvider.notifier).state =
                          EclipseScope.local,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        // ── Occultation target (planet / fixed star) ──
        if (eclType == EclipseType.occultation) _buildOccultTarget(theme),
        // ── Filter + count + Calculate ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Filter ',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: filterApplies ? null : theme.disabledColor,
                  ),
                ),
                const SizedBox(width: 4),
                ...eclipseFilters
                    .where((f) {
                      // Penumbral only for lunar
                      if (f.$2 == seEclPenumbral &&
                          eclType != EclipseType.lunar) {
                        return false;
                      }
                      // Annular/Hybrid not for lunar
                      if ((f.$2 == seEclAnnular || f.$2 == seEclHybrid) &&
                          eclType == EclipseType.lunar) {
                        return false;
                      }
                      // Hybrid doesn't apply to occultations
                      if (f.$2 == seEclHybrid &&
                          eclType == EclipseType.occultation) {
                        return false;
                      }
                      return true;
                    })
                    .map((f) {
                      final chip = ChoiceChip(
                        label: Text(f.$1),
                        // Nothing reads as selected under Local scope — showing
                        // a live selection would claim a constraint the search
                        // never receives.
                        selected: filterApplies && filter == f.$2,
                        onSelected: filterApplies
                            ? (_) =>
                                  ref
                                          .read(eclipseFilterProvider.notifier)
                                          .state =
                                      f.$2
                            : null,
                        visualDensity: VisualDensity.compact,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: filterApplies
                            ? chip
                            : Tooltip(
                                message: _localFilterTooltip,
                                child: chip,
                              ),
                      );
                    }),
                const SizedBox(width: 12),
                Text('Count ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ...([1, 3, 5, 10]).map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text('$n'),
                      selected: count == n,
                      onSelected: (_) =>
                          ref.read(eclipseCountProvider.notifier).state = n,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ExportButton(
                  hasResults: switch (outcome) {
                    CalcOk(value: final events) => events.isNotEmpty,
                    CalcError() => false,
                  },
                  filenameStem: 'eclipses',
                  getRows: () => switch (outcome) {
                    CalcOk(value: final events) => eclipsesToExportRows(
                      events,
                      ref.read(sweProvider),
                      // Export follows the Context's clock view, as the card
                      // always did — the old hand-written export defaulted it.
                      ref.read(clockViewProvider),
                    ),
                    CalcError() => [],
                  },
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        _buildResults(outcome),
      ],
    );
  }

  Widget _buildOccultTarget(ThemeData theme) {
    final kind = ref.watch(occultTargetKindProvider);
    final swe = ref.read(sweProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kind toggle + planet/star preset chips.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Target ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Planet'),
                  selected: kind == OccultTarget.planet,
                  onSelected: (_) =>
                      ref.read(occultTargetKindProvider.notifier).state =
                          OccultTarget.planet,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Star'),
                  selected: kind == OccultTarget.star,
                  onSelected: (_) =>
                      ref.read(occultTargetKindProvider.notifier).state =
                          OccultTarget.star,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 12),
                if (kind == OccultTarget.planet)
                  ...() {
                    final selected = ref.watch(occultPlanetProvider);
                    return occultablePlanets.map(
                      (body) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                          label: Text(safeGetName(swe, body)),
                          selected: selected == body,
                          onSelected: (_) =>
                              ref.read(occultPlanetProvider.notifier).state =
                                  body,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    );
                  }()
                else
                  ...() {
                    final selected = ref.watch(occultStarProvider);
                    return _occultStars.map(
                      (star) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                          label: Text(star),
                          selected: selected == star,
                          onSelected: (_) =>
                              ref.read(occultStarProvider.notifier).state =
                                  star,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        ),
        // Full-catalog star search (Bayer / HIP) — the prebuilt selector.
        if (kind == OccultTarget.star)
          Padding(
            padding: const EdgeInsets.fromLTRB(52, 0, 12, 4),
            child: StarSearchField(
              onSelect: (name) =>
                  ref.read(occultStarProvider.notifier).state = name,
              hintText: 'Search star name, Bayer, or HIP number',
              dense: true,
            ),
          ),
      ],
    );
  }

  Widget _buildResults(CalcOutcome<List<EclipseEvent>> outcome) {
    final List<EclipseEvent> events;
    switch (outcome) {
      case CalcError(:final message):
        return Center(child: Text('Calculation error: $message'));
      case CalcOk(value: final v):
        events = v;
    }
    if (events.isEmpty) {
      return const Center(child: Text('No eclipses found'));
    }

    final swe = ref.read(sweProvider);
    final view = ref.watch(clockViewProvider);
    // One label/value source for cards and export alike — see eclipseSections.
    final sections = eclipseSections(events, swe, view);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1000
            ? 3
            : constraints.maxWidth > 600
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final section in sections)
                SizedBox(width: cardWidth, child: section.toCard()),
            ],
          ),
        );
      },
    );
  }
}
