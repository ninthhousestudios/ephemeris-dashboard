// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/calculation/series_settings_provider.dart';
import '../../core/display_format.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../layout/tab_definitions.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../../widgets/series_bar.dart';
import '../../widgets/series_view.dart';
import '../../widgets/star_search_field.dart';
import '../stars/stars_provider.dart' show commonStars;
import 'rise_set_provider.dart';

// ── Body list ─────────────────────────────────────────────────────────────────

const _bodies = [
  (seSun, 'Sun'),
  (seMoon, 'Moon'),
  (seMercury, 'Mercury'),
  (seVenus, 'Venus'),
  (seMars, 'Mars'),
  (seJupiter, 'Jupiter'),
  (seSaturn, 'Saturn'),
  (seUranus, 'Uranus'),
  (seNeptune, 'Neptune'),
  (sePluto, 'Pluto'),
];

const _twilightLabels = {
  TwilightMode.none: 'None',
  TwilightMode.civil: 'Civil',
  TwilightMode.nautical: 'Nautical',
  TwilightMode.astronomical: 'Astronomical',
};

// ── Tab widget ────────────────────────────────────────────────────────────────

class RiseSetTab extends ConsumerStatefulWidget {
  const RiseSetTab({super.key});

  @override
  ConsumerState<RiseSetTab> createState() => _RiseSetTabState();
}

class _RiseSetTabState extends ConsumerState<RiseSetTab> {
  bool _showAtmospheric = false;
  final _atpressController = TextEditingController(text: '1013.25');
  final _attempController = TextEditingController(text: '15.0');

  @override
  void dispose() {
    _atpressController.dispose();
    _attempController.dispose();
    super.dispose();
  }

  void _addTarget(RiseSetTarget target) {
    final current = ref.read(riseSetTargetsProvider);
    if (current.contains(target)) return;
    ref.read(riseSetTargetsProvider.notifier).state = [...current, target];
  }

  void _removeTarget(RiseSetTarget target) {
    final current = ref.read(riseSetTargetsProvider);
    ref.read(riseSetTargetsProvider.notifier).state = current
        .where((t) => t != target)
        .toList();
  }

  void _toggleBodyTarget(int bodyId, bool on) {
    final target = RiseSetTarget.body(bodyId);
    if (on) {
      _addTarget(target);
    } else {
      _removeTarget(target);
    }
  }

  void _toggleStarTarget(String name, bool on) {
    final target = RiseSetTarget.star(name);
    if (on) {
      _addTarget(target);
    } else {
      _removeTarget(target);
    }
  }

  void _addStarByName(String name) {
    _addTarget(RiseSetTarget.star(name));
  }

  void _commitFields() {
    final atpress = double.tryParse(_atpressController.text);
    if (atpress != null) {
      ref.read(riseSetAtpressProvider.notifier).state = atpress;
    }
    final attemp = double.tryParse(_attempController.text);
    if (attemp != null) {
      ref.read(riseSetAttempProvider.notifier).state = attemp;
    }
  }

  RiseSetModifiers get _mods => ref.read(riseSetModifiersProvider);
  set _mods(RiseSetModifiers value) =>
      ref.read(riseSetModifiersProvider.notifier).state = value;

  /// Toggle a disc reference chip: on selects it, off falls back to the default
  /// upper limb. Center and Bottom are one exclusive choice. Selecting anything
  /// other than Center also clears Hindu Rising, which forces disc center.
  void _toggleDisc(DiscReference disc, bool on) {
    final next = on ? disc : DiscReference.upperLimb;
    _mods = _mods.copyWith(
      disc: next,
      hinduRising: next == DiscReference.center ? _mods.hinduRising : false,
    );
  }

  void _toggleNoRefraction(bool on) => _mods = _mods.copyWith(noRefraction: on);

  /// Hindu Rising is a preset (disc center + no refraction + geocentric). It
  /// owns those two chips while active, and can't coexist with Disc Bottom, so
  /// turning it on moves a Bottom selection to Center.
  void _toggleHinduRising(bool on) {
    _mods = _mods.copyWith(
      hinduRising: on,
      disc: on && _mods.disc == DiscReference.bottom
          ? DiscReference.center
          : _mods.disc,
    );
  }

  void _setTwilight(TwilightMode mode) =>
      _mods = _mods.copyWith(twilight: mode);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targets = ref.watch(riseSetTargetsProvider);
    final modifiers = ref.watch(riseSetModifiersProvider);
    final outcome = ref.watch(riseSetResultProvider);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Body chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Body ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ..._bodies.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(b.$2),
                      selected: targets.contains(RiseSetTarget.body(b.$1)),
                      onSelected: (on) => _toggleBodyTarget(b.$1, on),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Star preset chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Star ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ...commonStars.map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(name),
                      selected: targets.contains(RiseSetTarget.star(name)),
                      onSelected: (on) => _toggleStarTarget(name, on),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Star search bar with autocomplete ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: StarSearchField(
                  onSelect: _addStarByName,
                  hintText: 'Search star name, Bayer, or HIP number',
                  dense: true,
                ),
              ),
            ],
          ),
        ),
        // ── Modifier chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Disc reference (upper limb default / center / bottom) is one
                // exclusive choice. Hindu Rising is a preset that forces center +
                // no refraction, so while it's on those chips are locked to it.
                _ModifierChip(
                  label: 'Disc Center',
                  selected:
                      modifiers.hinduRising ||
                      modifiers.disc == DiscReference.center,
                  onSelected: modifiers.hinduRising
                      ? null
                      : (on) => _toggleDisc(DiscReference.center, on),
                ),
                const SizedBox(width: 4),
                _ModifierChip(
                  label: 'Disc Bottom',
                  selected:
                      !modifiers.hinduRising &&
                      modifiers.disc == DiscReference.bottom,
                  onSelected: modifiers.hinduRising
                      ? null
                      : (on) => _toggleDisc(DiscReference.bottom, on),
                ),
                const SizedBox(width: 4),
                _ModifierChip(
                  label: 'No Refraction',
                  selected: modifiers.hinduRising || modifiers.noRefraction,
                  onSelected: modifiers.hinduRising
                      ? null
                      : _toggleNoRefraction,
                ),
                const SizedBox(width: 4),
                _ModifierChip(
                  label: 'Hindu Rising',
                  selected: modifiers.hinduRising,
                  onSelected: _toggleHinduRising,
                ),
                const SizedBox(width: 4),
                ExportButton(
                  hasResults: outcome is CalcOk<List<RiseSetGroupResult>>,
                  filenameStem: 'rise_set',
                  getRows: () => switch (outcome) {
                    CalcOk(value: final r) => riseSetToExportRows(r),
                    CalcError() => [],
                  },
                ),
              ],
            ),
          ),
        ),
        // ── Progressive disclosure: twilight + atmospheric params ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _showAtmospheric = !_showAtmospheric),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAtmospheric ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Twilight & Atmospheric Parameters',
                        style: labelStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showAtmospheric) ...[
                const SizedBox(height: 4),
                // Twilight selector
                SegmentedButton<TwilightMode>(
                  segments: TwilightMode.values
                      .map(
                        (m) => ButtonSegment(
                          value: m,
                          label: Text(_twilightLabels[m]!),
                        ),
                      )
                      .toList(),
                  selected: {modifiers.twilight},
                  onSelectionChanged: (s) => _setTwilight(s.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Twilight applies to the Sun only; ignored for other bodies.',
                  style: labelStyle,
                ),
                const SizedBox(height: 8),
                // Atmospheric params with Expanded fields
                Row(
                  children: [
                    Text('Pressure (hPa) ', style: labelStyle),
                    Expanded(
                      child: TextField(
                        controller: _atpressController,
                        style: theme.textTheme.bodySmall,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onEditingComplete: _commitFields,
                        onSubmitted: (_) => _commitFields(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Temp (°C) ', style: labelStyle),
                    Expanded(
                      child: TextField(
                        controller: _attempController,
                        style: theme.textTheme.bodySmall,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        onEditingComplete: _commitFields,
                        onSubmitted: (_) => _commitFields(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        SeriesBar(tabId: AppTab.riseSet.name),
        const Divider(height: 1),
        // ── Results ──
        if (ref.watch(
          seriesSettingsProvider(AppTab.riseSet.name).select((s) => s.enabled),
        ))
          _buildSeries()
        else
          _buildResults(outcome),
      ],
    );
  }

  Widget _buildSeries() {
    final theme = Theme.of(context);
    final swe = ref.read(sweProvider);
    final clockView = ref.watch(clockViewProvider);
    final steps = ref.watch(riseSetSeriesProvider);
    final target = ref.watch(riseSetSeriesTargetProvider);

    // A per-event cell: the error string if the search failed (e.g. polar day),
    // otherwise the JD rendered on the selected clock, or an em-dash.
    String cell(double? jd, String? error) =>
        error ??
        (jd != null
            ? formatJdDateTime(swe, jd, view: clockView, showLabel: false)
            : '—');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text(
            target == null
                ? 'Select a body or star to run a series.'
                : 'Series follows ${target.label} (first selected).',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SeriesView(
          tabId: AppTab.riseSet.name,
          steps: [
            for (final (moment, outcome) in steps)
              (moment, outcome.map((r) => riseSetSeriesToExportRows(r, cell))),
          ],
          momentLabel: (m) => formatJdDateTime(
            swe,
            m.ut,
            showLabel: false,
            view: clockView,
            fallbackDigits: 4,
          ),
          momentColumnTitle: 'Date/Time (UT)',
        ),
      ],
    );
  }

  Widget _buildResults(CalcOutcome<List<RiseSetGroupResult>> outcome) {
    switch (outcome) {
      case CalcError(:final message):
        return Center(child: Text('Calculation error: $message'));
      case CalcOk(value: final groups):
        if (groups.isEmpty) {
          return const Center(child: Text('Select a body or star.'));
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 600
                ? 2
                : 1;
            final cardWidth =
                (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final group in groups)
                    _buildResultGroup(group, cardWidth),
                ],
              ),
            );
          },
        );
    }
  }

  Widget _buildResultGroup(RiseSetGroupResult group, double cardWidth) {
    final theme = Theme.of(context);
    final result = group.result;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(group.target.label, style: theme.textTheme.titleMedium),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => _removeTarget(group.target),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove',
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _eventCard('Rise', result.riseJd, result.riseError, cardWidth),
              _eventCard('Set', result.setJd, result.setError, cardWidth),
              _eventCard(
                'Upper Transit',
                result.upperTransitJd,
                result.upperTransitError,
                cardWidth,
              ),
              _eventCard(
                'Lower Transit',
                result.lowerTransitJd,
                result.lowerTransitError,
                cardWidth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventCard(String title, double? jd, String? error, double cardWidth) {
    final fields = <ResultField>[];

    if (error != null) {
      fields.add(ResultField(label: 'Error', value: error));
    } else {
      fields.add(
        ResultField(
          label: 'JD',
          value: jd != null ? jd.toStringAsFixed(8) : '—',
          rawValue: jd,
        ),
      );
      fields.add(
        ResultField(
          label: 'Date/Time',
          value: jd != null
              ? formatJdDateTime(
                  ref.read(sweProvider),
                  jd,
                  view: ref.watch(clockViewProvider),
                )
              : '—',
        ),
      );
    }

    return SizedBox(
      width: cardWidth,
      child: ResultCard(title: title, subtitle: 'riseTrans', fields: fields),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _ModifierChip extends StatelessWidget {
  const _ModifierChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;

  /// `null` disables the chip (e.g. while a preset owns it).
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
    );
  }
}
