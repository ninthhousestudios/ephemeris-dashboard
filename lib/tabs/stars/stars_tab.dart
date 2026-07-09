// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/emitter_provider.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/code_modal.dart';
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
    setState(() {
      _suggestions = starCatalog.where((e) {
        return e.commonName.toLowerCase().contains(lower) ||
            e.bayerDesig.toLowerCase().contains(bayerQ);
      }).toList();
    });
  }

  void _calculate() {
    final term = _searchController.text.trim();
    if (term.isNotEmpty) {
      ref.read(starSearchProvider.notifier).state = term;
    }
    setState(() => _suggestions = []);
  }

  void _selectSuggestion(StarCatalogEntry entry) {
    _searchController.text = entry.commonName;
    _searchController.selection = TextSelection.collapsed(
      offset: entry.commonName.length,
    );
    ref.read(starSearchProvider.notifier).state = entry.commonName;
    setState(() => _suggestions = []);
  }

  void _setStarPreset(String name) {
    _searchController.text = name;
    ref.read(starSearchProvider.notifier).state = name;
    setState(() => _suggestions = []);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = ref.watch(starsFormatProvider);
    final isMobile = ResponsiveLayout.of(context) == ScreenSize.mobile;
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
                    final result = switch (outcome) {
                      CalcOk(value: final r) => r,
                      CalcSweError() => null,
                    };
                    return ExportButton(
                      hasResults: result != null,
                      getRows: () =>
                          result != null ? starToExportRows(result, fmt2) : [],
                      filenameStem:
                          'swe_star_${result?.resolvedName ?? 'unknown'}',
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
                  child: ActionChip(
                    label: Text(name),
                    onPressed: () => _setStarPreset(name),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        if (isMobile)
          _buildResults(theme)
        else
          Expanded(child: _buildResults(theme)),
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
      CalcOk(value: null) => Center(
        child: Text(
          'Star not found — check the name or catalog number',
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ),
      CalcOk(value: final result) => _buildResultCard(result!, fmt),
    };
  }

  Widget _buildResultCard(StarResult result, DisplayFormat fmt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: ResultCard(
        title: result.resolvedName,
        subtitle: 'fixstar2Ut("${result.searchTerm}")',
        flagHex: '0x${result.returnFlag.toRadixString(16).toUpperCase()}',
        fields: [
          ResultField(
            label: 'Longitude',
            value: formatAngle(result.longitude, fmt),
            rawValue: result.longitude,
          ),
          ResultField(
            label: 'Latitude',
            value: formatAngle(result.latitude, fmt),
            rawValue: result.latitude,
          ),
          ResultField(
            label: 'Distance',
            value: formatDistance(result.distance, fmt),
            rawValue: result.distance,
          ),
          ResultField(
            label: 'Magnitude',
            value: result.magnitude.isNaN
                ? '—'
                : result.magnitude.toStringAsFixed(2),
            rawValue: result.magnitude,
          ),
          ResultField(
            label: 'Spd Lon',
            value: formatSpeed(result.speedLon, fmt),
            rawValue: result.speedLon,
          ),
          ResultField(
            label: 'Spd Lat',
            value: formatSpeed(result.speedLat, fmt),
            rawValue: result.speedLat,
          ),
          ResultField(
            label: 'Spd Dist',
            value: formatSpeed(result.speedDist, fmt),
            rawValue: result.speedDist,
          ),
        ],
        onCode: () {
          final trace = ref.read(starTraceProvider);
          final slice = trace.sliceByTab('stars');
          if (slice.entries.isEmpty) return;
          final emitter = ref.read(selectedEmitterProvider);
          final code = slice.entries.map(emitter.emitSnippet).join('\n');
          showCodeModal(
            context,
            code: code,
            languageLabel: emitter.displayName,
          );
        },
      ),
    );
  }
}
