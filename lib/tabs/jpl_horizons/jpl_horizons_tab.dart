// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

// The JPL Horizons tab: a request/response query console (ADR-0003). Left pane
// builds the request; right pane shows the raw response, the constructed URL,
// and disambiguation candidates. Blank by default; "Load from Context" pulls
// the Moment + location from the app Context.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/horizons/horizons_response.dart';
import '../../core/horizons/horizons_types.dart';
import 'horizons_draft.dart';
import 'horizons_tab_providers.dart';

class JplHorizonsTab extends ConsumerStatefulWidget {
  const JplHorizonsTab({super.key});

  @override
  ConsumerState<JplHorizonsTab> createState() => _JplHorizonsTabState();
}

class _JplHorizonsTabState extends ConsumerState<JplHorizonsTab> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    final d = ref.read(horizonsTabProvider).draft;
    _controllers = {
      'target': TextEditingController(text: d.target),
      'customCenter': TextEditingController(text: d.customCenter),
      'topoBodyId': TextEditingController(text: d.topoBodyId),
      'siteCoord': TextEditingController(text: d.siteCoord),
      'startTime': TextEditingController(text: d.startTime),
      'stopTime': TextEditingController(text: d.stopTime),
      'stepSize': TextEditingController(text: d.stepSize),
      'tlist': TextEditingController(text: d.tlistText),
      'quantities': TextEditingController(text: d.quantitiesText),
      'overrides': TextEditingController(text: d.rawOverridesText),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  HorizonsTabNotifier get _notifier => ref.read(horizonsTabProvider.notifier);

  TextEditingController _c(String key) =>
      _controllers[key] ?? (throw StateError('missing controller: $key'));

  void _loadFromContext() {
    _notifier.loadFromContext();
    // Sync the text controllers the pre-fill touched (dropdowns read the draft
    // directly and need no sync).
    final d = ref.read(horizonsTabProvider).draft;
    _c('siteCoord').text = d.siteCoord;
    _c('tlist').text = d.tlistText;
    _c('topoBodyId').text = d.topoBodyId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(horizonsTabProvider);
    final draft = state.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('JPL Horizons', style: theme.textTheme.titleSmall),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Load from Context'),
                  onPressed: _loadFromContext,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: state.running
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Run'),
                  onPressed: state.running ? null : _notifier.run,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        LayoutBuilder(
          builder: (context, constraints) {
            final form = _buildForm(draft);
            final result = _ResultPane(
              state: state,
              onSelectCandidate: _rerunWith,
            );
            if (constraints.maxWidth > 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(flex: 5, child: form),
                  const VerticalDivider(width: 1),
                  Flexible(flex: 4, child: result),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [form, const Divider(height: 1), result],
            );
          },
        ),
      ],
    );
  }

  void _rerunWith(String recordId) {
    _c('target').text = '$recordId;';
    _notifier
      ..updateDraft((d) => d.copyWith(target: '$recordId;'))
      ..run();
  }

  Widget _buildForm(HorizonsDraft draft) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _section('Ephemeris type'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in EphemType.values)
                ChoiceChip(
                  label: Text(t.wire),
                  selected: draft.ephemType == t,
                  onSelected: (_) =>
                      _notifier.updateDraft((d) => d.copyWith(ephemType: t)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _text('target', 'Target (COMMAND)', hint: "e.g. 499, Ceres, DES=1;"),
          const SizedBox(height: 12),
          _section('Center'),
          _enumDropdown<CenterMode>(
            'Observer center',
            draft.centerMode,
            CenterMode.values,
            (v) => _notifier.updateDraft((d) => d.copyWith(centerMode: v)),
            labelOf: (m) => m.name,
          ),
          if (draft.centerMode == CenterMode.custom)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _text('customCenter', "CENTER (site@body)"),
            ),
          if (draft.centerMode == CenterMode.topocentric) ...[
            const SizedBox(height: 8),
            _text('topoBodyId', 'Body id (e.g. 399)'),
            const SizedBox(height: 8),
            _enumDropdown<CoordType>(
              'Coord type',
              draft.coordType,
              CoordType.values,
              (v) => _notifier.updateDraft((d) => d.copyWith(coordType: v)),
              labelOf: (c) => c.wire,
            ),
            const SizedBox(height: 8),
            _text('siteCoord', 'SITE_COORD (E-lon,lat,alt-km)'),
          ],
          const SizedBox(height: 12),
          _section('Time'),
          Wrap(
            spacing: 6,
            children: [
              for (final m in TimeMode.values)
                ChoiceChip(
                  label: Text(m.name),
                  selected: draft.timeMode == m,
                  onSelected: (_) =>
                      _notifier.updateDraft((d) => d.copyWith(timeMode: m)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (draft.timeMode == TimeMode.range) ...[
            _text('startTime', 'START_TIME'),
            const SizedBox(height: 8),
            _text('stopTime', 'STOP_TIME'),
            const SizedBox(height: 8),
            _text('stepSize', "STEP_SIZE (e.g. 1 d, 10 m, 30)"),
          ] else
            _text('tlist', 'TLIST (one epoch per line)', maxLines: 4),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _enumDropdown<TimeScale>(
                'Time type',
                draft.timeScale,
                TimeScale.values,
                (v) => _notifier.updateDraft((d) => d.copyWith(timeScale: v)),
                labelOf: (s) => s.wire,
              ),
              _enumDropdown<CalendarFormat>(
                'Cal format',
                draft.calendarFormat,
                CalendarFormat.values,
                (v) =>
                    _notifier.updateDraft((d) => d.copyWith(calendarFormat: v)),
                labelOf: (c) => c.wire,
              ),
              _enumDropdown<RefSystem>(
                'Ref system',
                draft.refSystem,
                RefSystem.values,
                (v) => _notifier.updateDraft((d) => d.copyWith(refSystem: v)),
                labelOf: (r) => r.wire,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._optionSection(draft),
          const SizedBox(height: 12),
          _section('Output'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _switch(
                'CSV',
                draft.csvFormat,
                (v) => _notifier.updateDraft((d) => d.copyWith(csvFormat: v)),
              ),
              _switch(
                'Object data',
                draft.objData,
                (v) => _notifier.updateDraft((d) => d.copyWith(objData: v)),
              ),
              _switch(
                'Extra precision',
                draft.extraPrecision,
                (v) =>
                    _notifier.updateDraft((d) => d.copyWith(extraPrecision: v)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _section('Raw parameter overrides'),
          _text('overrides', 'KEY=VALUE per line', maxLines: 3),
        ],
      ),
    );
  }

  List<Widget> _optionSection(HorizonsDraft draft) {
    switch (draft.ephemType) {
      case EphemType.observer:
        return [
          _section('Observer quantities'),
          _text('quantities', 'QUANTITIES codes (e.g. 1,9,20,23,24)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _enumDropdown<AngleFormat>(
                'Angle format',
                draft.angleFormat,
                AngleFormat.values,
                (v) => _notifier.updateDraft((d) => d.copyWith(angleFormat: v)),
                labelOf: (a) => a.wire,
              ),
              _enumDropdown<ApparentType>(
                'Apparent',
                draft.apparent,
                ApparentType.values,
                (v) => _notifier.updateDraft((d) => d.copyWith(apparent: v)),
                labelOf: (a) => a.wire,
              ),
              _enumDropdown<RangeUnits>(
                'Range units',
                draft.rangeUnits,
                RangeUnits.values,
                (v) => _notifier.updateDraft((d) => d.copyWith(rangeUnits: v)),
                labelOf: (r) => r.wire,
              ),
              _switch(
                'Suppress range-rate',
                draft.suppressRangeRate,
                (v) => _notifier.updateDraft(
                  (d) => d.copyWith(suppressRangeRate: v),
                ),
              ),
              _switch(
                'Skip daylight',
                draft.skipDaylight,
                (v) =>
                    _notifier.updateDraft((d) => d.copyWith(skipDaylight: v)),
              ),
            ],
          ),
        ];
      case EphemType.vectors:
        return [
          _section('Vector table'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _enumDropdown<VectorTable>(
                'Table',
                draft.vectorTable,
                VectorTable.values,
                (v) => _notifier.updateDraft((d) => d.copyWith(vectorTable: v)),
                labelOf: (t) => t.wire,
              ),
              _enumDropdown<VectorCorrection>(
                'Correction',
                draft.vectorCorrection,
                VectorCorrection.values,
                (v) => _notifier.updateDraft(
                  (d) => d.copyWith(vectorCorrection: v),
                ),
                labelOf: (c) => c.wire,
              ),
              _enumDropdown<OutUnits>(
                'Out units',
                draft.vectorOutUnits,
                OutUnits.values,
                (v) =>
                    _notifier.updateDraft((d) => d.copyWith(vectorOutUnits: v)),
                labelOf: (u) => u.wire,
              ),
              _enumDropdown<RefPlane>(
                'Ref plane',
                draft.vectorRefPlane,
                RefPlane.values,
                (v) =>
                    _notifier.updateDraft((d) => d.copyWith(vectorRefPlane: v)),
                labelOf: (r) => r.wire,
              ),
            ],
          ),
        ];
      case EphemType.elements:
        return [
          _section('Elements'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _enumDropdown<OutUnits>(
                'Out units',
                draft.elementOutUnits,
                OutUnits.values,
                (v) => _notifier.updateDraft(
                  (d) => d.copyWith(elementOutUnits: v),
                ),
                labelOf: (u) => u.wire,
              ),
              _enumDropdown<RefPlane>(
                'Ref plane',
                draft.elementRefPlane,
                RefPlane.values,
                (v) => _notifier.updateDraft(
                  (d) => d.copyWith(elementRefPlane: v),
                ),
                labelOf: (r) => r.wire,
              ),
            ],
          ),
        ];
      case EphemType.spk:
        return [
          _section('SPK'),
          const Text(
            'Generates a binary .bsp over the time span. '
            'Small bodies only; no table options.',
          ),
        ];
      case EphemType.approach:
        return [
          _section('Close approach'),
          const Text('Close-approach table over the time span.'),
        ];
    }
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _text(String key, String label, {String? hint, int maxLines = 1}) {
    return TextField(
      controller: _c(key),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) => _notifier.updateDraft((d) => _applyText(d, key, v)),
    );
  }

  HorizonsDraft _applyText(HorizonsDraft d, String key, String v) {
    switch (key) {
      case 'target':
        return d.copyWith(target: v);
      case 'customCenter':
        return d.copyWith(customCenter: v);
      case 'topoBodyId':
        return d.copyWith(topoBodyId: v);
      case 'siteCoord':
        return d.copyWith(siteCoord: v);
      case 'startTime':
        return d.copyWith(startTime: v);
      case 'stopTime':
        return d.copyWith(stopTime: v);
      case 'stepSize':
        return d.copyWith(stepSize: v);
      case 'tlist':
        return d.copyWith(tlistText: v);
      case 'quantities':
        return d.copyWith(quantitiesText: v);
      case 'overrides':
        return d.copyWith(rawOverridesText: v);
      default:
        return d;
    }
  }

  Widget _enumDropdown<T>(
    String label,
    T value,
    List<T> values,
    ValueChanged<T> onChanged, {
    required String Function(T) labelOf,
  }) {
    return SizedBox(
      width: 200,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            items: [
              for (final v in values)
                DropdownMenuItem<T>(value: v, child: Text(labelOf(v))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
    );
  }
}

class _ResultPane extends StatelessWidget {
  const _ResultPane({required this.state, required this.onSelectCandidate});

  final HorizonsTabState state;
  final ValueChanged<String> onSelectCandidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = state.draft;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(
            draft.build().requestUrl(),
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          const Divider(height: 24),
          Text('Response', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (state.running) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final transportError = state.transportError;
    if (transportError != null) {
      return Text(
        transportError,
        style: TextStyle(color: theme.colorScheme.error),
      );
    }
    final result = state.result;
    if (result == null) {
      return Text(
        'Press Run to query Horizons.',
        style: theme.textTheme.bodySmall,
      );
    }
    return switch (result) {
      HorizonsTable(:final rawText, :final signature) => _rawBlock(
        context,
        rawText,
        footer: signature,
      ),
      HorizonsApiError(:final message, :final httpStatus, :final rawText) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              httpStatus == null ? message : 'HTTP $httpStatus: $message',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            if (rawText != null) ...[
              const SizedBox(height: 8),
              _rawBlock(context, rawText),
            ],
          ],
        ),
      HorizonsDisambiguation(:final candidates, :final rawText) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Non-unique target — pick one:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in candidates)
                ActionChip(
                  label: Text('${c.recordId} · ${c.name}'),
                  onPressed: () => onSelectCandidate(c.recordId),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _rawBlock(context, rawText),
        ],
      ),
      HorizonsSpk(:final bytes, :final suggestedFilename) => Text(
        'SPK ready: ${bytes.length} bytes'
        '${suggestedFilename == null ? '' : ' ($suggestedFilename)'}. '
        'Saving arrives with the SPK slice.',
        style: theme.textTheme.bodyMedium,
      ),
    };
  }

  Widget _rawBlock(BuildContext context, String text, {String? footer}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: 4),
          Text(footer, style: theme.textTheme.labelSmall),
        ],
      ],
    );
  }
}
