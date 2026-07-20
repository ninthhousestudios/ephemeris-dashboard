// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/display_format.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'stars_provider.dart';

class StarsTab extends ConsumerStatefulWidget {
  const StarsTab({super.key});

  @override
  ConsumerState<StarsTab> createState() => _StarsTabState();
}

class _StarsTabState extends ConsumerState<StarsTab> {
  late final TextEditingController _searchController;
  final _focusNode = FocusNode();
  List<StarCatalogEntry> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(starSearchProvider),
    );
    _searchController.addListener(_onSearchChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _suggestions = []);
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final lower = q.toLowerCase();
    final bayerQ = lower.startsWith(',') ? lower.substring(1) : lower;
    final catalog = ref.read(starCatalogProvider);
    setState(() {
      _suggestions = catalog.where((e) {
        return e.commonName.toLowerCase().contains(lower) ||
            e.bayerDesig.toLowerCase().contains(bayerQ);
      }).toList();
    });
  }

  void _addStar(String name) {
    final current = ref.read(selectedStarsProvider);
    if (!current.contains(name)) {
      ref.read(selectedStarsProvider.notifier).state = [...current, name];
    }
    _searchController.clear();
    ref.read(starSearchProvider.notifier).state = '';
    setState(() => _suggestions = []);
  }

  void _removeStar(String name) {
    final current = ref.read(selectedStarsProvider);
    ref.read(selectedStarsProvider.notifier).state = current
        .where((s) => s != name)
        .toList();
  }

  void _calculate() {
    final term = _searchController.text.trim();
    if (term.isNotEmpty) _addStar(term);
  }

  void _selectSuggestion(StarCatalogEntry entry) {
    _addStar(entry.commonName);
  }

  void _toggleStarPreset(String name) {
    final current = ref.read(selectedStarsProvider);
    if (current.contains(name)) {
      _removeStar(name);
    } else {
      ref.read(selectedStarsProvider.notifier).state = [...current, name];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = ref.watch(starsFormatProvider);
    final selectedStars = ref.watch(selectedStarsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Star name input row with suggestions ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text('Star ', style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: theme.textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        hintText:
                            'Star name or Bayer designation (e.g. Spica, alVir)',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _calculate(),
                    ),
                    if (_suggestions.isNotEmpty)
                      Material(
                        elevation: 4,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final entry = _suggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(entry.commonName),
                                trailing: Text(
                                  entry.bayerDesig,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                onTap: () => _selectSuggestion(entry),
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
        // ── Format + export row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SegmentedButton<DisplayFormat>(
                  segments: DisplayFormat.values
                      .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                      .toList(),
                  selected: {fmt},
                  onSelectionChanged: (s) =>
                      ref.read(starsFormatProvider.notifier).state = s.first,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final outcome = ref.watch(starResultProvider);
                    final fmt2 = ref.watch(starsFormatProvider);
                    final results = switch (outcome) {
                      CalcOk(value: final r) => r,
                      CalcSweError() => const <StarResult>[],
                    };
                    return ExportButton(
                      hasResults: results.isNotEmpty,
                      getRows: () => starToExportRows(results, fmt2),
                      filenameStem: 'swe_stars',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // ── Preset star chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: commonStars.map((name) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: FilterChip(
                    label: Text(name),
                    selected: selectedStars.contains(name),
                    onSelected: (_) => _toggleStarPreset(name),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        _buildResults(theme),
      ],
    );
  }

  Widget _buildResults(ThemeData theme) {
    final outcome = ref.watch(starResultProvider);
    final fmt = ref.watch(starsFormatProvider);

    return switch (outcome) {
      CalcSweError(:final message) => Center(
        child: Text(
          'Calculation error: $message',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
      CalcOk(value: final results) =>
        results.isEmpty
            ? const Center(child: Text('No stars selected'))
            : _buildResultCards(results, fmt),
    };
  }

  Widget _buildResultCards(List<StarResult> results, DisplayFormat fmt) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1200
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
            children: results.map((r) {
              return SizedBox(
                width: cardWidth,
                child: Stack(
                  children: [
                    ResultCard(
                      title: r.resolvedName,
                      subtitle: 'fixstar2Ut("${r.searchTerm}")',
                      flagHex:
                          '0x${r.returnFlag.toRadixString(16).toUpperCase()}',
                      fields: r.errorMessage != null
                          ? [
                              ResultField(
                                label: 'Error',
                                value: r.errorMessage!,
                              ),
                            ]
                          : [
                              ResultField(
                                label: 'Longitude',
                                value: formatAngle(r.longitude, fmt),
                                rawValue: r.longitude,
                              ),
                              ResultField(
                                label: 'Latitude',
                                value: formatAngle(r.latitude, fmt),
                                rawValue: r.latitude,
                              ),
                              ResultField(
                                label: 'Distance',
                                value: formatDistance(r.distance, fmt),
                                rawValue: r.distance,
                              ),
                              ResultField(
                                label: 'Magnitude',
                                value: r.magnitude.isNaN
                                    ? '—'
                                    : r.magnitude.toStringAsFixed(2),
                                rawValue: r.magnitude,
                              ),
                              ResultField(
                                label: 'Spd Lon',
                                value: formatSpeed(r.speedLon, fmt),
                                rawValue: r.speedLon,
                              ),
                              ResultField(
                                label: 'Spd Lat',
                                value: formatSpeed(r.speedLat, fmt),
                                rawValue: r.speedLat,
                              ),
                              ResultField(
                                label: 'Spd Dist',
                                value: formatSpeed(r.speedDist, fmt),
                                rawValue: r.speedDist,
                              ),
                            ],
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Remove ${r.resolvedName}',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removeStar(r.searchTerm),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
