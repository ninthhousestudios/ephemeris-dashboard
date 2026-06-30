import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_session.dart';
import '../../core/ephemeris/emitter_provider.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/swe_service.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/code_modal.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import 'eclipses_provider.dart';

class EclipsesTab extends ConsumerStatefulWidget {
  const EclipsesTab({super.key});

  @override
  ConsumerState<EclipsesTab> createState() => _EclipsesTabState();
}

class _EclipsesTabState extends ConsumerState<EclipsesTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eclType = ref.watch(eclipseTypeProvider);
    final scope = ref.watch(eclipseScopeProvider);
    final filter = ref.watch(eclipseFilterProvider);
    final count = ref.watch(eclipseCountProvider);
    final results = ref.watch(eclipseResultsProvider);
    final triggered = ref.watch(
      calcSessionProvider.select((s) => s.tabHasRun('eclipses')),
    );
    final isMobile = ResponsiveLayout.of(context) == ScreenSize.mobile;

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
                          eclType == EclipseType.solar) {
                        return false;
                      }
                      // Annular/Hybrid not for lunar
                      if ((f.$2 == seEclAnnular || f.$2 == seEclHybrid) &&
                          eclType == EclipseType.lunar) {
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
                  hasResults: triggered && results.isNotEmpty,
                  filenameStem: 'eclipses',
                  getRows: () =>
                      eclipsesToExportRows(results, ref.read(sweProvider)),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        if (isMobile)
          triggered
              ? _buildResults(results)
              : const Center(
                  child: Text('Configure search and press Calculate'),
                )
        else
          Expanded(
            child: triggered
                ? _buildResults(results)
                : const Center(
                    child: Text('Configure search and press Calculate'),
                  ),
          ),
      ],
    );
  }

  Widget _buildResults(List<EclipseEvent> events) {
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

  Widget _eclipseCard(BuildContext context, EclipseEvent e, SwissEph swe) {
    final fields = <ResultField>[];

    if (e.error != null) {
      fields.add(ResultField(label: 'Error', value: e.error!));
    } else {
      fields.add(ResultField(label: 'Type', value: e.eclipseTypeLabel));

      if (e.maxEclipseJd != null) {
        fields.add(
          ResultField(
            label: 'Max Eclipse',
            value: _jdToDateStr(swe, e.maxEclipseJd!),
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

    final typeLabel = e.type == EclipseType.solar ? 'Solar' : 'Lunar';
    final scopeLabel = e.scope == EclipseScope.global ? 'Global' : 'Local';

    return ResultCard(
      title: '#${e.index} $typeLabel Eclipse',
      subtitle: scopeLabel,
      flagHex: '0x${e.returnFlag.toRadixString(16).toUpperCase()}',
      fields: fields,
      onCode: () {
        final trace = ref.read(callTraceProvider);
        if (trace == null) return;
        final slice = trace.sliceByTab('eclipses');
        if (slice.entries.isEmpty) return;
        final emitter = ref.read(selectedEmitterProvider);
        final code = slice.entries.map(emitter.emitSnippet).join('\n');
        showCodeModal(context, code: code, languageLabel: emitter.displayName);
      },
    );
  }

  void _addJdField(
    List<ResultField> fields,
    String label,
    double? jd,
    SwissEph swe,
  ) {
    if (jd == null) return;
    fields.add(ResultField(label: label, value: _jdToDateStr(swe, jd)));
  }
}

String _jdToDateStr(SwissEph swe, double jd) {
  try {
    final r = swe.revjul(jd);
    final h = r.hour.floor();
    final mFrac = (r.hour - h) * 60;
    final m = mFrac.floor();
    final s = ((mFrac - m) * 60).round();
    return '${r.year}-${_p(r.month)}-${_p(r.day)} ${_p(h)}:${_p(m)}:${_p(s)} UT';
  } catch (_) {
    return jd.toStringAsFixed(6);
  }
}

String _p(int n) => n.toString().padLeft(2, '0');
