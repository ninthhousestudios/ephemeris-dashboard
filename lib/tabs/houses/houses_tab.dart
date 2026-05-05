import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calc_session.dart';
import '../../core/display_format.dart';
import '../../core/persistence.dart';
import '../../widgets/result_card.dart';
import 'houses_provider.dart';

class HousesTab extends ConsumerStatefulWidget {
  const HousesTab({super.key});

  @override
  ConsumerState<HousesTab> createState() => _HousesTabState();
}

class _HousesTabState extends ConsumerState<HousesTab> {
  bool get _hasCalculated =>
      ref.watch(calcSessionProvider.select((s) => s.tabHasRun('houses')));

  @override
  Widget build(BuildContext context) {
    final hsys = ref.watch(selectedHouseSystemProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // House system selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.sizeOf(context).width - 24,
              ),
              child: Row(
                children: [
                  Text('House System:', style: theme.textTheme.labelMedium),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<int>(
                      initialValue: hsys,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: OutlineInputBorder(),
                      ),
                      items: houseSystems
                          .map((h) => DropdownMenuItem(
                                value: h.code,
                                child: Text('${h.char} — ${h.label}',
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(selectedHouseSystemProvider.notifier).state = v;
                          ref.read(persistenceProvider).saveHouseSystem(v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        // Results
        Expanded(
          child: _hasCalculated ? _buildResults() : _buildPlaceholder(),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Text('Select a house system and press Calculate'),
    );
  }

  Widget _buildResults() {
    final format = ref.watch(housesFormatProvider);
    final result = ref.watch(housesResultProvider);

    if (result == null) {
      return const Center(child: Text('Calculation error'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1200
            ? 3
            : constraints.maxWidth > 600
                ? 2
                : 1;
        final cardWidth =
            (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;
        final cuspCount = (result.hsys == 0x47 ? 36 : 12)
            .clamp(0, result.cusps.length - 1);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (int i = 1; i <= cuspCount; i++)
                    SizedBox(
                      width: cardWidth,
                      child: ResultCard(
                        title: 'Cusp $i',
                        subtitle: result.hsysName,
                        flagHex: null,
                        fields: [
                          ResultField(
                            label: 'Longitude',
                            value: formatAngle(result.cusps[i], format),
                            rawValue: result.cusps[i],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              ResultCard(
                title: 'Angles',
                subtitle: result.hsysName,
                fields: [
                  ResultField(label: 'Asc', value: formatAngle(result.asc, format), rawValue: result.asc),
                  ResultField(label: 'MC', value: formatAngle(result.mc, format), rawValue: result.mc),
                  ResultField(label: 'ARMC', value: formatAngle(result.armc, format), rawValue: result.armc),
                  ResultField(label: 'Vertex', value: formatAngle(result.vertex, format), rawValue: result.vertex),
                  ResultField(label: 'Eq Asc', value: formatAngle(result.equatorialAsc, format), rawValue: result.equatorialAsc),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
