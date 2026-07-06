import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/swe_constants.dart';

import '../../core/calculation/calc_outcome.dart';
import '../../core/display_format.dart';
import '../../core/ephemeris/emitter_provider.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/code_modal.dart';
import '../../widgets/result_card.dart';
import 'planets_provider.dart';

class PlanetsTab extends ConsumerStatefulWidget {
  const PlanetsTab({super.key});

  @override
  ConsumerState<PlanetsTab> createState() => _PlanetsTabState();
}

class _PlanetsTabState extends ConsumerState<PlanetsTab> {
  bool _showExtraBodies = false;
  bool _showAsteroids = false;
  final _asteroidController = TextEditingController();

  @override
  void dispose() {
    _asteroidController.dispose();
    super.dispose();
  }

  void _toggleBody(int body) {
    final current = ref.read(selectedBodiesProvider);
    final updated = current.contains(body)
        ? current.where((b) => b != body).toList()
        : [...current, body];
    ref.read(selectedBodiesProvider.notifier).state = updated;
  }

  void _applyPreset(BodyPreset preset) {
    ref.read(selectedBodiesProvider.notifier).state = List.of(preset.bodies);
  }

  void _addAsteroid(int mpcNumber) {
    final bodyId = asteroidOffset + mpcNumber;
    final current = ref.read(selectedBodiesProvider);
    if (!current.contains(bodyId)) {
      ref.read(selectedBodiesProvider.notifier).state = [...current, bodyId];
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedBodies = ref.watch(selectedBodiesProvider);
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.of(context) == ScreenSize.mobile;

    return Column(
      children: [
        // ── Row 1: Presets | divider | default body chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...bodyPresets.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ActionChip(
                      label: Text(p.label),
                      onPressed: () => _applyPreset(p),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(width: 16, color: theme.dividerColor),
                ),
                ...defaultBodies.map((body) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: FilterChip(
                      label: Text(_bodyLabel(body)),
                      selected: selectedBodies.contains(body),
                      onSelected: (_) => _toggleBody(body),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        // ── Row 2: More bodies (progressive disclosure) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              InkWell(
                onTap: () =>
                    setState(() => _showExtraBodies = !_showExtraBodies),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showExtraBodies ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'More bodies',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showExtraBodies) ...[
                const SizedBox(height: 4),
                // Chiron, Pholus, main asteroids, Earth, interp. apogee/perigee
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: extraBodies.map((body) {
                    return FilterChip(
                      label: Text(_bodyLabel(body)),
                      selected: selectedBodies.contains(body),
                      onSelected: (_) => _toggleBody(body),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                // Uranian section
                Text(
                  'Uranian',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: uranianBodies.map((body) {
                    return FilterChip(
                      label: Text(_bodyLabel(body)),
                      selected: selectedBodies.contains(body),
                      onSelected: (_) => _toggleBody(body),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                // Asteroids disclosure
                InkWell(
                  onTap: () => setState(() => _showAsteroids = !_showAsteroids),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showAsteroids ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Asteroids (by MPC number)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showAsteroids) ...[
                  const SizedBox(height: 4),
                  // Named asteroid quick-add chips
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: namedAsteroids.entries.map((e) {
                      final bodyId = asteroidOffset + e.key;
                      return FilterChip(
                        label: Text(e.value),
                        selected: selectedBodies.contains(bodyId),
                        onSelected: (_) {
                          if (selectedBodies.contains(bodyId)) {
                            _toggleBody(bodyId);
                          } else {
                            _addAsteroid(e.key);
                          }
                        },
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  // Custom MPC number entry
                  Row(
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _asteroidController,
                          decoration: const InputDecoration(
                            hintText: 'MPC #',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onSubmitted: (_) => _addCustomAsteroid(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: 'Add asteroid by MPC number',
                        onPressed: _addCustomAsteroid,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
        // ── Results ──
        if (isMobile) _buildResults() else Expanded(child: _buildResults()),
      ],
    );
  }

  void _addCustomAsteroid() {
    final text = _asteroidController.text.trim();
    final num = int.tryParse(text);
    if (num != null && num > 0) {
      _addAsteroid(num);
      _asteroidController.clear();
    }
  }

  Widget _buildResults() {
    final format = ref.watch(planetsFormatProvider);
    final outcome = ref.watch(planetsResultsProvider);

    return switch (outcome) {
      CalcSweError(:final message) => Center(
        child: Text('Calculation error: $message'),
      ),
      CalcOk(value: final results) =>
        results.isEmpty
            ? const Center(child: Text('No bodies selected'))
            : _buildResultCards(results, format),
    };
  }

  Widget _buildResultCards(List<PlanetResult> results, DisplayFormat format) {
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
                child: ResultCard(
                  title: r.bodyName,
                  subtitle: 'calcUt(${r.body})',
                  flagHex: '0x${r.returnFlag.toRadixString(16).toUpperCase()}',
                  onCode: () {
                    final traceId = 'planets:calc_ut:body=${r.body}';
                    final trace = ref.read(planetsTraceProvider);
                    final slice = trace.sliceByTraceId(traceId);
                    if (slice.entries.isEmpty) return;
                    final emitter = ref.read(selectedEmitterProvider);
                    final code = slice.entries
                        .map(emitter.emitSnippet)
                        .join('\n');
                    showCodeModal(
                      context,
                      code: code,
                      languageLabel: emitter.displayName,
                    );
                  },
                  fields: r.errorMessage != null
                      ? [ResultField(label: 'Error', value: r.errorMessage!)]
                      : [
                          ResultField(
                            label: 'Longitude',
                            value: formatAngle(r.longitude, format),
                            rawValue: r.longitude,
                          ),
                          ResultField(
                            label: 'Latitude',
                            value: formatAngle(r.latitude, format),
                            rawValue: r.latitude,
                          ),
                          ResultField(
                            label: 'Distance',
                            value: formatDistance(r.distance, format),
                            rawValue: r.distance,
                          ),
                          ResultField(
                            label: 'Spd Lon',
                            value: formatSpeed(r.speedLon, format),
                            rawValue: r.speedLon,
                          ),
                          ResultField(
                            label: 'Spd Lat',
                            value: formatSpeed(r.speedLat, format),
                            rawValue: r.speedLat,
                          ),
                          ResultField(
                            label: 'Spd Dist',
                            value: formatSpeed(r.speedDist, format),
                            rawValue: r.speedDist,
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

/// Short label for a body constant.
String _bodyLabel(int body) {
  const names = {
    seSun: 'Sun',
    seMoon: 'Moon',
    seMercury: 'Mercury',
    seVenus: 'Venus',
    seMars: 'Mars',
    seJupiter: 'Jupiter',
    seSaturn: 'Saturn',
    seUranus: 'Uranus',
    seNeptune: 'Neptune',
    sePluto: 'Pluto',
    seMeanNode: 'M.Node',
    seTrueNode: 'T.Node',
    seMeanApog: 'M.Lilith',
    seOscuApog: 'O.Lilith',
    seEarth: 'Earth',
    seChiron: 'Chiron',
    sePholus: 'Pholus',
    seCeres: 'Ceres',
    sePallas: 'Pallas',
    seJuno: 'Juno',
    seVesta: 'Vesta',
    seIntpApog: 'I.Apogee',
    seIntpPerg: 'I.Perigee',
    seCupido: 'Cupido',
    seHades: 'Hades',
    seZeus: 'Zeus',
    seKronos: 'Kronos',
    seApollon: 'Apollon',
    seAdmetos: 'Admetos',
    seVulkanus: 'Vulkanus',
    sePoseidon: 'Poseidon',
  };
  if (names.containsKey(body)) return names[body]!;
  // Asteroid by MPC number?
  if (body >= seAstOffset) return '#${body - seAstOffset}';
  return 'Body $body';
}
