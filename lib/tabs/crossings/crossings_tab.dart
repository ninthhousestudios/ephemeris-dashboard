import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_session.dart';
import '../../core/context_provider.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'crossings_provider.dart';

class CrossingsTab extends ConsumerStatefulWidget {
  const CrossingsTab({super.key});

  @override
  ConsumerState<CrossingsTab> createState() => _CrossingsTabState();
}

class _CrossingsTabState extends ConsumerState<CrossingsTab> {
  late final TextEditingController _lonController;

  @override
  void initState() {
    super.initState();
    final lon = ref.read(crossingLonProvider);
    _lonController = TextEditingController(
      text: lon == 0 ? '' : lon.toString(),
    );
  }

  @override
  void dispose() {
    _lonController.dispose();
    super.dispose();
  }

  bool get _hasCalculated =>
      ref.watch(calcSessionProvider.select((s) => s.tabHasRun('crossings')));

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(crossingTypeProvider);
    final helioBody = ref.watch(crossingHelioBodyProvider);
    final dir = ref.watch(crossingDirProvider);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final showLon = type != CrossingType.moonNode;
    final showHelio = type == CrossingType.helioCross;

    const helioBodies = [
      seMercury, seVenus, seMars, seJupiter, seSaturn,
      seUranus, seNeptune, sePluto,
    ];

    const bodyLabels = {
      seMercury: 'Mercury', seVenus: 'Venus', seMars: 'Mars',
      seJupiter: 'Jupiter', seSaturn: 'Saturn', seUranus: 'Uranus',
      seNeptune: 'Neptune', sePluto: 'Pluto',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Crossing type chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Type ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ...CrossingType.values.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(t.label),
                        selected: type == t,
                        onSelected: (_) =>
                            ref.read(crossingTypeProvider.notifier).state = t,
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
        ),
        // ── Target longitude + direction ──
        if (showLon)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                Text('Longitude ', style: labelStyle),
                Expanded(
                  child: TextField(
                    controller: _lonController,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: '°',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) {
                        ref.read(crossingLonProvider.notifier).state = parsed;
                      }
                    },
                  ),
                ),
                if (showHelio) ...[
                  const SizedBox(width: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('Forward')),
                      ButtonSegment(value: -1, label: Text('Backward')),
                    ],
                    selected: {dir},
                    onSelectionChanged: (s) =>
                        ref.read(crossingDirProvider.notifier).state = s.first,
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact),
                  ),
                ],
              ],
            ),
          ),
        // ── Helio body chips ──
        if (showHelio)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('Body ', style: theme.textTheme.labelLarge),
                  const SizedBox(width: 4),
                  ...helioBodies.map((b) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                          label: Text(bodyLabels[b] ?? 'Body $b'),
                          selected: helioBody == b,
                          onSelected: (_) => ref
                              .read(crossingHelioBodyProvider.notifier)
                              .state = b,
                          visualDensity: VisualDensity.compact,
                        ),
                      )),
                ],
              ),
            ),
          ),
        // ── Export row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Spacer(),
              Consumer(builder: (context, ref, _) {
                final result = ref.watch(crossingResultProvider);
                final jd = ref.watch(contextBarProvider).jdUt;
                return ExportButton(
                  hasResults: _hasCalculated && result != null,
                  getRows: () =>
                      result != null ? crossingToExportRows(result) : [],
                  filenameStem: 'swe_crossings_${jd.toStringAsFixed(4)}',
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        Expanded(
          child: _hasCalculated ? const _ResultView() : const _Placeholder(),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Configure a crossing and press Calculate'),
    );
  }
}

class _ResultView extends ConsumerWidget {
  const _ResultView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(crossingResultProvider);

    if (result == null) {
      return const Center(child: Text('No result'));
    }

    final isError = result.crossingJd.isNaN;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: ResultCard(
        title: result.description,
        subtitle: isError ? 'Error' : 'Crossing found',
        fields: [
          ResultField(
            label: 'JD (UT)',
            value: isError ? 'NaN' : result.crossingJd.toStringAsFixed(6),
            rawValue: result.crossingJd,
          ),
          ResultField(
            label: 'Date/Time',
            value: result.crossingDate,
            rawValue: null,
          ),
          if (result.crossingLongitude != null)
            ResultField(
              label: 'Node Longitude',
              value: '${result.crossingLongitude!.toStringAsFixed(6)}°',
              rawValue: result.crossingLongitude,
            ),
        ],
      ),
    );
  }
}
