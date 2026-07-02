import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_session.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/emitter_provider.dart';
import '../../core/ephemeris/runner.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../layout/responsive_layout.dart';
import '../../widgets/code_modal.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../stars/stars_provider.dart' show StarCatalogEntry, starCatalog;
import 'heliacal_provider.dart';

const _eventTypes = [
  (seHeliacalRising, 'Heliacal Rising'),
  (seHeliacalSetting, 'Heliacal Setting'),
  (seEveningFirst, 'Evening First'),
  (seMorningLast, 'Morning Last'),
];

/// Bodies available for heliacal events, matching the Planets tab default set.
/// The heliacalUt API takes a string name, so we map body ID → name.
const _heliacalBodies = [
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

class HeliacalTab extends ConsumerStatefulWidget {
  const HeliacalTab({super.key});

  @override
  ConsumerState<HeliacalTab> createState() => _HeliacalTabState();
}

class _HeliacalTabState extends ConsumerState<HeliacalTab> {
  bool _showAtmospheric = false;
  bool _showStarInput = false;
  List<StarCatalogEntry> _starSuggestions = [];

  late final TextEditingController _starController;
  final _starFocusNode = FocusNode();
  late final TextEditingController _pressureController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _humidityController;
  late final TextEditingController _extinctionController;
  late final TextEditingController _ageController;
  late final TextEditingController _snellenController;

  late final CalcSessionNotifier _calcNotifier;

  @override
  void initState() {
    super.initState();
    _calcNotifier = ref.read(calcSessionProvider.notifier);
    _starController = TextEditingController();
    _starController.addListener(_onStarChanged);
    _starFocusNode.addListener(() {
      if (!_starFocusNode.hasFocus) {
        setState(() => _starSuggestions = []);
      }
    });
    _pressureController = TextEditingController(text: '1013.25');
    _temperatureController = TextEditingController(text: '25.0');
    _humidityController = TextEditingController(text: '50.0');
    _extinctionController = TextEditingController(text: '0.2');
    _ageController = TextEditingController(text: '36.0');
    _snellenController = TextEditingController(text: '1.0');
    _calcNotifier.registerCommit('heliacal', _syncProviders);
  }

  @override
  void dispose() {
    _calcNotifier.unregisterCommit('heliacal');
    _starController.removeListener(_onStarChanged);
    _starController.dispose();
    _starFocusNode.dispose();
    _pressureController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    _extinctionController.dispose();
    _ageController.dispose();
    _snellenController.dispose();
    super.dispose();
  }

  void _onStarChanged() {
    final q = _starController.text.trim();
    if (q.isEmpty) {
      setState(() => _starSuggestions = []);
      return;
    }
    final lower = q.toLowerCase();
    final bayerQ = lower.startsWith(',') ? lower.substring(1) : lower;
    setState(() {
      _starSuggestions = starCatalog.where((e) {
        return e.commonName.toLowerCase().contains(lower) ||
            e.bayerDesig.toLowerCase().contains(bayerQ);
      }).toList();
    });
  }

  void _selectStarSuggestion(StarCatalogEntry entry) {
    _starController.text = entry.commonName;
    _starController.selection = TextSelection.collapsed(
      offset: entry.commonName.length,
    );
    ref.read(heliacalStarProvider.notifier).state = entry.commonName;
    setState(() => _starSuggestions = []);
  }

  void _selectBody(String name) {
    ref.read(heliacalStarProvider.notifier).state = name;
    // Clear the custom star field when selecting a chip
    _starController.clear();
    setState(() => _showStarInput = false);
  }

  void _syncProviders() {
    final star = _starController.text.trim();
    if (star.isNotEmpty) {
      ref.read(heliacalStarProvider.notifier).state = star;
    }
    _syncDouble(_pressureController, heliacalPressureProvider);
    _syncDouble(_temperatureController, heliacalTemperatureProvider);
    _syncDouble(_humidityController, heliacalHumidityProvider);
    _syncDouble(_extinctionController, heliacalExtinctionProvider);
    _syncDouble(_ageController, heliacalObserverAgeProvider);
    _syncDouble(_snellenController, heliacalSnellenRatioProvider);
  }

  void _syncDouble(TextEditingController ctrl, StateProvider<double> provider) {
    final v = double.tryParse(ctrl.text);
    if (v != null) ref.read(provider.notifier).state = v;
  }

  bool get _hasCalculated =>
      ref.watch(calcSessionProvider.select((s) => s.tabHasRun('heliacal')));

  void _calculate() {
    _syncProviders();
    ref.read(calcSessionProvider.notifier).calculate(activate: {'heliacal'});
  }

  @override
  Widget build(BuildContext context) {
    final eventType = ref.watch(heliacalEventTypeProvider);
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final selectedStar = ref.watch(heliacalStarProvider);
    final isMobile = ResponsiveLayout.of(context) == ScreenSize.mobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Body chips (matching Planets tab) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Body ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ..._heliacalBodies.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(b.$2),
                      selected: selectedStar == b.$2,
                      onSelected: (_) => _selectBody(b.$2),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // ── Fixed star input (progressive disclosure) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _showStarInput = !_showStarInput),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showStarInput ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Fixed Star by Name',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showStarInput) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Star ', style: theme.textTheme.labelLarge),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _starController,
                            focusNode: _starFocusNode,
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
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                ref.read(heliacalStarProvider.notifier).state =
                                    v.trim();
                                _calculate();
                              }
                            },
                          ),
                          if (_starSuggestions.isNotEmpty)
                            Material(
                              elevation: 4,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
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
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
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
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        // ── Event type chips + Calculate + Export ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('Event ', style: theme.textTheme.labelLarge),
                const SizedBox(width: 4),
                ..._eventTypes.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Text(e.$2),
                      selected: eventType == e.$1,
                      onSelected: (_) =>
                          ref.read(heliacalEventTypeProvider.notifier).state =
                              e.$1,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final result = ref.watch(heliacalResultProvider);
                    final jd = ref.watch(contextBarProvider).jdUt;
                    return ExportButton(
                      hasResults:
                          _hasCalculated && result != null && !result.hasError,
                      getRows: () => result != null
                          ? heliacalToExportRows(result, ref.read(sweProvider))
                          : [],
                      filenameStem: 'swe_heliacal_${jd.toStringAsFixed(4)}',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        // ── Progressive disclosure: atmospheric & observer params ──
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
                        'Atmospheric & Observer Conditions',
                        style: labelStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showAtmospheric) ...[
                const SizedBox(height: 8),
                // Atmosphere row
                Text(
                  'ATMOSPHERE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Pressure (mbar)',
                  _pressureController,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Temperature (°C)',
                  _temperatureController,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Humidity (%)',
                  _humidityController,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 4),
                _paramRow(
                  'Extinction coeff.',
                  _extinctionController,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 8),
                // Observer row
                Text(
                  'OBSERVER',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _paramRow('Age (years)', _ageController, theme, labelStyle),
                const SizedBox(height: 4),
                _paramRow(
                  'Snellen ratio',
                  _snellenController,
                  theme,
                  labelStyle,
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        if (isMobile)
          _hasCalculated ? const _ResultsView() : const _Placeholder()
        else
          Expanded(
            child: _hasCalculated ? const _ResultsView() : const _Placeholder(),
          ),
      ],
    );
  }

  Widget _paramRow(
    String label,
    TextEditingController ctrl,
    ThemeData theme,
    TextStyle? labelStyle,
  ) {
    return Row(
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ctrl,
            style: theme.textTheme.bodySmall,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Placeholder ───────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Enter a star or planet name and press Calculate'),
    );
  }
}

// ── Results view ──────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  const _ResultsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(heliacalResultProvider);
    if (result == null) {
      return const Center(child: Text('No result'));
    }

    if (result.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ResultCard(
            title: result.objectName,
            subtitle: HeliacalCalcResult.eventLabel(result.eventType),
            fields: [
              ResultField(
                label: 'Error',
                value: result.error!,
                rawValue: double.nan,
              ),
            ],
            onCode: () {
              final trace = ref.read(callTraceProvider);
              if (trace == null) return;
              final slice = trace.sliceByTab('heliacal');
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
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 900 ? 2 : 1;
        final cardWidth = (constraints.maxWidth - 16 - (cols - 1) * 4) / cols;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              SizedBox(
                width: cardWidth,
                child: _buildEventCard(
                  context,
                  ref,
                  result,
                  ref.read(sweProvider),
                  ref.read(contextBarProvider).utcOffset,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _buildJdCard(context, ref, result),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventCard(
    BuildContext context,
    WidgetRef ref,
    HeliacalCalcResult r,
    SwissEph swe,
    double utcOffset,
  ) {
    return ResultCard(
      title: r.objectName,
      subtitle: HeliacalCalcResult.eventLabel(r.eventType),
      fields: [
        ResultField(
          label: 'Start Visible',
          value: _fmtHeliacalJd(swe, r.startVisibleJd, utcOffset),
          rawValue: r.startVisibleJd,
        ),
        ResultField(
          label: 'Best Visible',
          value: _fmtHeliacalJd(swe, r.bestVisibleJd, utcOffset),
          rawValue: r.bestVisibleJd,
        ),
        ResultField(
          label: 'End Visible',
          value: _fmtHeliacalJd(swe, r.endVisibleJd, utcOffset),
          rawValue: r.endVisibleJd,
        ),
      ],
      onCode: () {
        final trace = ref.read(callTraceProvider);
        if (trace == null) return;
        final slice = trace.sliceByTab('heliacal');
        if (slice.entries.isEmpty) return;
        final emitter = ref.read(selectedEmitterProvider);
        final code = slice.entries.map(emitter.emitSnippet).join('\n');
        showCodeModal(context, code: code, languageLabel: emitter.displayName);
      },
    );
  }

  Widget _buildJdCard(
    BuildContext context,
    WidgetRef ref,
    HeliacalCalcResult r,
  ) {
    return ResultCard(
      title: 'Julian Days',
      subtitle: 'heliacalUt result',
      fields: [
        ResultField(
          label: 'Start (JD)',
          value: r.startVisibleJd.toStringAsFixed(6),
          rawValue: r.startVisibleJd,
        ),
        ResultField(
          label: 'Best (JD)',
          value: r.bestVisibleJd.toStringAsFixed(6),
          rawValue: r.bestVisibleJd,
        ),
        ResultField(
          label: 'End (JD)',
          value: r.endVisibleJd.toStringAsFixed(6),
          rawValue: r.endVisibleJd,
        ),
      ],
      onCode: () {
        final trace = ref.read(callTraceProvider);
        if (trace == null) return;
        final slice = trace.sliceByTab('heliacal');
        if (slice.entries.isEmpty) return;
        final emitter = ref.read(selectedEmitterProvider);
        final code = slice.entries.map(emitter.emitSnippet).join('\n');
        showCodeModal(context, code: code, languageLabel: emitter.displayName);
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtHeliacalJd(SwissEph swe, double jd, double utcOffset) =>
    formatJdDateTime(
      swe,
      jd,
      seconds: false,
      utcOffset: utcOffset,
      emptyPlaceholder: '—',
      fallbackDigits: 4,
    );
