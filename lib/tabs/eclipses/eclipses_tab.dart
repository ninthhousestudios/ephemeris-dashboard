// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/body_utils.dart';
import '../../core/calculation/calc_outcome.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../core/swe_utils.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
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

class _EclipsesTabState extends ConsumerState<EclipsesTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eclType = ref.watch(eclipseTypeProvider);
    final scope = ref.watch(eclipseScopeProvider);
    final filter = ref.watch(eclipseFilterProvider);
    final count = ref.watch(eclipseCountProvider);
    final outcome = ref.watch(eclipseResultsProvider);

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
                Text('Filter ', style: theme.textTheme.labelLarge),
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
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                          label: Text(f.$1),
                          selected: filter == f.$2,
                          onSelected: (_) =>
                              ref.read(eclipseFilterProvider.notifier).state =
                                  f.$2,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
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
            children: events
                .map(
                  (e) => SizedBox(
                    width: cardWidth,
                    child: _eclipseCard(context, e, swe),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _eclipseCard(BuildContext context, EclipseEvent e, SweUtils swe) {
    final fields = <ResultField>[];

    if (e.error != null) {
      fields.add(ResultField(label: 'Error', value: e.error!));
    } else {
      if (e.targetLabel != null) {
        fields.add(ResultField(label: 'Target', value: e.targetLabel!));
      }
      fields.add(ResultField(label: 'Type', value: e.eclipseTypeLabel));

      if (e.maxEclipseJd != null) {
        fields.add(
          ResultField(
            label: 'Max Eclipse',
            value: formatJdDateTime(swe, e.maxEclipseJd!),
          ),
        );
        fields.add(
          ResultField(
            label: 'Max JD',
            value: e.maxEclipseJd!.toStringAsFixed(8),
            rawValue: e.maxEclipseJd,
          ),
        );
      }

      // Timing fields
      _addJdField(fields, 'Begin', e.beginJd, swe);
      _addJdField(fields, 'End', e.endJd, swe);
      _addJdField(fields, 'Totality Begin', e.totalityBeginJd, swe);
      _addJdField(fields, 'Totality End', e.totalityEndJd, swe);
      _addJdField(fields, 'Penumbral Begin', e.penumbralBeginJd, swe);
      _addJdField(fields, 'Penumbral End', e.penumbralEndJd, swe);
      _addJdField(fields, 'Local Noon', e.localNoonJd, swe);
      _addJdField(fields, '1st Contact', e.firstContactJd, swe);
      _addJdField(fields, '2nd Contact', e.secondContactJd, swe);
      _addJdField(fields, '3rd Contact', e.thirdContactJd, swe);
      _addJdField(fields, '4th Contact', e.fourthContactJd, swe);
      _addJdField(fields, 'Sunrise', e.sunriseJd, swe);
      _addJdField(fields, 'Sunset', e.sunsetJd, swe);

      // Attributes
      if (e.magnitude != null) {
        fields.add(
          ResultField(
            label: 'Magnitude',
            value: e.magnitude!.toStringAsFixed(4),
            rawValue: e.magnitude,
          ),
        );
      }
      if (e.obscuration != null) {
        fields.add(
          ResultField(
            label: 'Obscuration',
            value: '${(e.obscuration! * 100).toStringAsFixed(2)}%',
            rawValue: e.obscuration,
          ),
        );
      }
      if (e.centralLat != null && e.centralLon != null) {
        fields.add(
          ResultField(
            label: 'Central Line',
            value:
                '${e.centralLat!.toStringAsFixed(4)}° / ${e.centralLon!.toStringAsFixed(4)}°',
          ),
        );
      }
      if (e.visibilityRemark != null) {
        fields.add(
          ResultField(label: 'Visibility', value: e.visibilityRemark!),
        );
      }
      if (e.sarosSeries != null) {
        fields.add(
          ResultField(
            label: 'Saros',
            value:
                '${e.sarosSeries!.round()} / ${e.sarosMember?.round() ?? "?"}',
          ),
        );
      }
    }

    final scopeLabel = e.scope == EclipseScope.global ? 'Global' : 'Local';
    final title = switch (e.type) {
      EclipseType.solar => '#${e.index} Solar Eclipse',
      EclipseType.lunar => '#${e.index} Lunar Eclipse',
      EclipseType.occultation => '#${e.index} Occultation',
    };

    return ResultCard(
      title: title,
      subtitle: scopeLabel,
      flagHex: '0x${e.returnFlag.toRadixString(16).toUpperCase()}',
      fields: fields,
    );
  }

  void _addJdField(
    List<ResultField> fields,
    String label,
    double? jd,
    SweUtils swe,
  ) {
    if (jd == null) return;
    fields.add(ResultField(label: label, value: formatJdDateTime(swe, jd)));
  }
}
