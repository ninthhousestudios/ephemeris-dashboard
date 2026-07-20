// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/context_provider.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../stars/stars_provider.dart'
    show StarCatalogEntry, commonStars, starCatalogProvider;
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

// ── Twilight modes ────────────────────────────────────────────────────────────

enum _TwilightMode {
  none('None', 0),
  civil('Civil', rsBitCivilTwilight),
  nautical('Nautical', rsBitNauticTwilight),
  astronomical('Astronomical', rsBitAstroTwilight);

  const _TwilightMode(this.label, this.bit);
  final String label;
  final int bit;
}

// ── Tab widget ────────────────────────────────────────────────────────────────

class RiseSetTab extends ConsumerStatefulWidget {
  const RiseSetTab({super.key});

  @override
  ConsumerState<RiseSetTab> createState() => _RiseSetTabState();
}

class _RiseSetTabState extends ConsumerState<RiseSetTab> {
  _TwilightMode _twilightMode = _TwilightMode.none;
  bool _showAtmospheric = false;
  final _atpressController = TextEditingController(text: '1013.25');
  final _attempController = TextEditingController(text: '15.0');

  final _starSearchController = TextEditingController();
  final _starFocusNode = FocusNode();
  List<StarCatalogEntry> _starSuggestions = [];

  @override
  void initState() {
    super.initState();
    _starSearchController.addListener(_onStarSearchChanged);
    _starFocusNode.addListener(() {
      if (!_starFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _starSuggestions = []);
        });
      }
    });
  }

  @override
  void dispose() {
    _starSearchController.removeListener(_onStarSearchChanged);
    _starSearchController.dispose();
    _starFocusNode.dispose();
    _atpressController.dispose();
    _attempController.dispose();
    super.dispose();
  }

  void _onStarSearchChanged() {
    final q = _starSearchController.text.trim();
    if (q.isEmpty) {
      setState(() => _starSuggestions = []);
      return;
    }
    final lower = q.toLowerCase();
    final bayerQ = lower.startsWith(',') ? lower.substring(1) : lower;
    final catalog = ref.read(starCatalogProvider);
    setState(() {
      _starSuggestions = catalog.where((e) {
        return e.commonName.toLowerCase().contains(lower) ||
            e.bayerDesig.toLowerCase().contains(bayerQ);
      }).toList();
    });
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

  void _selectStarSuggestion(StarCatalogEntry entry) {
    _starSearchController.clear();
    _addTarget(RiseSetTarget.star(entry.commonName));
    setState(() => _starSuggestions = []);
  }

  void _commitStarSearch() {
    final term = _starSearchController.text.trim();
    if (term.isNotEmpty) {
      _addTarget(RiseSetTarget.star(term));
      _starSearchController.clear();
    }
    setState(() => _starSuggestions = []);
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

  void _toggleModifier(int bit, bool on) {
    final current = ref.read(riseSetModifiersProvider);
    ref.read(riseSetModifiersProvider.notifier).state = on
        ? (current | bit)
        : (current & ~bit);
  }

  void _setTwilightMode(_TwilightMode mode) {
    setState(() => _twilightMode = mode);
    var mods = ref.read(riseSetModifiersProvider);
    mods &= ~(rsBitCivilTwilight | rsBitNauticTwilight | rsBitAstroTwilight);
    if (mode != _TwilightMode.none) mods |= mode.bit;
    ref.read(riseSetModifiersProvider.notifier).state = mods;
  }

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _starSearchController,
                      focusNode: _starFocusNode,
                      style: theme.textTheme.bodySmall,
                      decoration: InputDecoration(
                        hintText: 'Search star name, Bayer, or HIP number',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: _starSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _starSearchController.clear();
                                  setState(() => _starSuggestions = []);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _commitStarSearch(),
                    ),
                    if (_starSuggestions.isNotEmpty)
                      Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: _starSuggestions.length,
                            itemBuilder: (context, index) {
                              final entry = _starSuggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(entry.commonName),
                                trailing: Text(
                                  entry.bayerDesig,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                onTap: () => _selectStarSuggestion(entry),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
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
                _ModifierChip(
                  label: 'Disc Center',
                  bit: rsBitDiscCenter,
                  modifiers: modifiers,
                  onToggle: _toggleModifier,
                ),
                const SizedBox(width: 4),
                _ModifierChip(
                  label: 'Disc Bottom',
                  bit: rsBitDiscBottom,
                  modifiers: modifiers,
                  onToggle: _toggleModifier,
                ),
                const SizedBox(width: 4),
                _ModifierChip(
                  label: 'No Refraction',
                  bit: rsBitNoRefraction,
                  modifiers: modifiers,
                  onToggle: _toggleModifier,
                ),
                const SizedBox(width: 4),
                _ModifierChip(
                  label: 'Hindu Rising',
                  bit: rsBitHinduRising,
                  modifiers: modifiers,
                  onToggle: _toggleModifier,
                ),
                const SizedBox(width: 4),
                ExportButton(
                  hasResults: outcome is CalcOk<List<RiseSetGroupResult>>,
                  filenameStem: 'rise_set',
                  getRows: () => switch (outcome) {
                    CalcOk(value: final r) => riseSetToExportRows(r),
                    CalcSweError() => [],
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
                SegmentedButton<_TwilightMode>(
                  segments: _TwilightMode.values
                      .map((m) => ButtonSegment(value: m, label: Text(m.label)))
                      .toList(),
                  selected: {_twilightMode},
                  onSelectionChanged: (s) => _setTwilightMode(s.first),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
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
        const Divider(height: 1),
        // ── Results ──
        _buildResults(outcome),
      ],
    );
  }

  Widget _buildResults(CalcOutcome<List<RiseSetGroupResult>> outcome) {
    switch (outcome) {
      case CalcSweError(:final message):
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
            child: Text(group.target.label, style: theme.textTheme.titleMedium),
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _eventCard(
                'Rise',
                result.riseJd,
                result.riseDateTime,
                result.riseFlag,
                result.riseError,
                cardWidth,
              ),
              _eventCard(
                'Set',
                result.setJd,
                result.setDateTime,
                result.setFlag,
                result.setError,
                cardWidth,
              ),
              _eventCard(
                'Upper Transit',
                result.upperTransitJd,
                result.upperTransitDateTime,
                result.upperTransitFlag,
                result.upperTransitError,
                cardWidth,
              ),
              _eventCard(
                'Lower Transit',
                result.lowerTransitJd,
                result.lowerTransitDateTime,
                result.lowerTransitFlag,
                result.lowerTransitError,
                cardWidth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventCard(
    String title,
    double? jd,
    RiseSetDateTime? dt,
    int? flag,
    String? error,
    double cardWidth,
  ) {
    final fields = <ResultField>[];
    final utcOffset = ref.read(contextBarProvider).utcOffset;

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
          value: dt?.formattedWithLocal(utcOffset) ?? '—',
        ),
      );
    }

    return SizedBox(
      width: cardWidth,
      child: ResultCard(
        title: title,
        subtitle: 'riseTrans',
        flagHex: flag != null
            ? '0x${flag.toRadixString(16).toUpperCase()}'
            : null,
        fields: fields,
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _ModifierChip extends StatelessWidget {
  const _ModifierChip({
    required this.label,
    required this.bit,
    required this.modifiers,
    required this.onToggle,
  });

  final String label;
  final int bit;
  final int modifiers;
  final void Function(int bit, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: (modifiers & bit) != 0,
      onSelected: (on) => onToggle(bit, on),
      visualDensity: VisualDensity.compact,
    );
  }
}
