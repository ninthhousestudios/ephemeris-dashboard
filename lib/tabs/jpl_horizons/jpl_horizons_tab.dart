// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

// The JPL Horizons tab: a request/response query console (ADR-0003). Left pane
// builds the request; right pane shows the raw response, the constructed URL,
// and disambiguation candidates. Blank by default; "Load from Context" pulls
// the Moment + location from the app Context.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/export_service.dart';
import '../../core/horizons/horizons_bodies.dart';
import '../../core/horizons/horizons_response.dart';
import '../../core/horizons/horizons_types.dart';
import '../../core/horizons/observer_quantities.dart';
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
      'extraQuantities': TextEditingController(text: d.extraQuantitiesText),
      'elevCut': TextEditingController(text: d.elevCut),
      'airmass': TextEditingController(text: d.airmass),
      'lhaCutoff': TextEditingController(text: d.lhaCutoff),
      'angRateCutoff': TextEditingController(text: d.angRateCutoff),
      'solarElong': TextEditingController(text: d.solarElong),
      'timeZone': TextEditingController(text: d.timeZone),
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

  /// Set the target COMMAND from a picked body, syncing the text controller.
  void _pickBody(HorizonsBody body) {
    _c('target').text = body.command;
    _notifier.updateDraft((d) => d.copyWith(target: body.command));
  }

  /// A popup that inserts a known Horizons id into the target field. Horizons
  /// takes one target per request, so this is a picker, not a multi-select.
  Widget _bodyPicker() {
    return PopupMenuButton<HorizonsBody>(
      tooltip: 'Insert a known Horizons body id',
      onSelected: _pickBody,
      itemBuilder: (context) => [
        for (final (i, group) in horizonsBodyGroups.indexed) ...[
          if (i > 0) const PopupMenuDivider(),
          PopupMenuItem<HorizonsBody>(
            enabled: false,
            child: Text(
              group.label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          for (final body in group.bodies)
            PopupMenuItem<HorizonsBody>(
              value: body,
              child: Text('${body.label}  ·  ${body.command}'),
            ),
        ],
      ],
      child: const Chip(
        avatar: Icon(Icons.public, size: 16),
        label: Text('Bodies'),
      ),
    );
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
          Row(
            children: [
              Expanded(
                child: _text(
                  'target',
                  'Target (COMMAND)',
                  hint: "e.g. 499, Ceres, DES=1;",
                ),
              ),
              const SizedBox(width: 8),
              _bodyPicker(),
            ],
          ),
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
          ] else ...[
            _text('tlist', 'TLIST (one epoch per line)', maxLines: 4),
            const SizedBox(height: 8),
            _enumDropdown<TimeListType>(
              'TLIST type',
              draft.tlistType,
              TimeListType.values,
              (v) => _notifier.updateDraft((d) => d.copyWith(tlistType: v)),
              labelOf: (t) => t.wire,
            ),
          ],
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
          _quantityGrid(draft.quantities),
          const SizedBox(height: 8),
          _text(
            'extraQuantities',
            'Additional codes (uncatalogued)',
            hint: 'e.g. 50,51',
          ),
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
              _switch(
                'Rise/transit/set only',
                draft.riseTransitSetOnly,
                (v) => _notifier.updateDraft(
                  (d) => d.copyWith(riseTransitSetOnly: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _section('Output filters'),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _shortField('elevCut', 'Elevation cut (deg)', hint: 'e.g. 10'),
              _shortField('airmass', 'Airmass cut', hint: '1=zenith, 38=off'),
              _shortField('solarElong', 'Solar elong. band', hint: 'min,max'),
              _shortField('lhaCutoff', 'Hour-angle cut (h)'),
              _shortField('angRateCutoff', 'Sky-rate cut ("/min)'),
              _shortField('timeZone', 'Time zone', hint: '+00:00'),
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
              _switch(
                'Component labels',
                draft.vectorLabels,
                (v) =>
                    _notifier.updateDraft((d) => d.copyWith(vectorLabels: v)),
              ),
              _switch(
                'Delta-T column',
                draft.vectorDeltaT,
                (v) =>
                    _notifier.updateDraft((d) => d.copyWith(vectorDeltaT: v)),
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
              _enumDropdown<PeriapsisTimeType>(
                'Tp type',
                draft.tpType,
                PeriapsisTimeType.values,
                (v) => _notifier.updateDraft((d) => d.copyWith(tpType: v)),
                labelOf: (t) => t.wire,
              ),
              _switch(
                'Element labels',
                draft.elementLabels,
                (v) =>
                    _notifier.updateDraft((d) => d.copyWith(elementLabels: v)),
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
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _enumDropdown<ApproachTableType>(
                'Table type',
                draft.approachTableType,
                ApproachTableType.values,
                (v) => _notifier.updateDraft(
                  (d) => d.copyWith(approachTableType: v),
                ),
                labelOf: (t) => t.wire,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Close-approach table over the time span. Distance/time limits '
            '(CALIM_SB, CALIM_PL, TCA3SG_LIMIT) via raw overrides.',
          ),
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

  /// Checkbox grid over the catalogued OBSERVER quantities. Toggling a chip
  /// adds/removes its code from the draft's [HorizonsDraft.quantities] set;
  /// uncatalogued codes go through the "Additional codes" field instead.
  Widget _quantityGrid(Set<int> selected) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final q in observerQuantities)
          FilterChip(
            label: Text('${q.code}. ${q.label}'),
            selected: selected.contains(q.code),
            onSelected: (on) => _notifier.updateDraft((d) {
              final next = {...d.quantities};
              if (on) {
                next.add(q.code);
              } else {
                next.remove(q.code);
              }
              return d.copyWith(quantities: next);
            }),
          ),
      ],
    );
  }

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

  /// A [_text] field sized for a [Wrap] row. Fixed width is unavoidable for a
  /// Wrap child, so scale it with zoom and floor it (CLAUDE.md).
  Widget _shortField(String key, String label, {String? hint}) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return SizedBox(
      width: (220 * scale).floorToDouble(),
      child: _text(key, label, hint: hint),
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
      case 'extraQuantities':
        return d.copyWith(extraQuantitiesText: v);
      case 'elevCut':
        return d.copyWith(elevCut: v);
      case 'airmass':
        return d.copyWith(airmass: v);
      case 'lhaCutoff':
        return d.copyWith(lhaCutoff: v);
      case 'angRateCutoff':
        return d.copyWith(angRateCutoff: v);
      case 'solarElong':
        return d.copyWith(solarElong: v);
      case 'timeZone':
        return d.copyWith(timeZone: v);
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
    // Fixed width is unavoidable for a Wrap child, so scale it with zoom and
    // floor it (CLAUDE.md) — a flat 200px squashes labels at >100%.
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return SizedBox(
      width: (220 * scale).floorToDouble(),
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
      HorizonsTable(:final rawText, :final signature, :final parsed) =>
        _TableResult(rawText: rawText, signature: signature, parsed: parsed),
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
              _rawResponseBlock(context, rawText),
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
          _rawResponseBlock(context, rawText),
        ],
      ),
      HorizonsSpk(:final bytes, :final suggestedFilename) => _SpkResult(
        bytes: bytes,
        suggestedFilename: suggestedFilename,
      ),
    };
  }
}

/// The scrollable monospace block for raw Horizons text — shared by the table,
/// api-error, and disambiguation results.
Widget _rawResponseBlock(BuildContext context, String text, {String? footer}) {
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

/// The SPK result: a decoded `.bsp` segment with a save button. SPK is a
/// binary payload (not table text), so it routes through
/// [ExportService.saveBytes] rather than the tabular exporters.
class _SpkResult extends StatelessWidget {
  const _SpkResult({required this.bytes, this.suggestedFilename});

  final Uint8List bytes;
  final String? suggestedFilename;

  Future<void> _save(BuildContext context) async {
    // Capture the messenger before the await — the save dialog is async and
    // `context` must not be used across it.
    final messenger = ScaffoldMessenger.of(context);
    final name = suggestedFilename ?? 'horizons.bsp';
    final stem = name.toLowerCase().endsWith('.bsp')
        ? name.substring(0, name.length - 4)
        : name;
    final msg = await ExportService.saveBytes(bytes, stem, 'bsp');
    messenger.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SPK ready: ${bytes.length} bytes'
          '${suggestedFilename == null ? '' : ' ($suggestedFilename)'}.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.save_alt, size: 18),
          label: const Text('Save .bsp'),
          onPressed: () => _save(context),
        ),
      ],
    );
  }
}

/// A successful ephemeris. Raw monospace text is always available; when
/// Horizons returned a delimited CSV block ([HorizonsTable.parsed]) a table
/// view and CSV export are offered, with a Table/Raw toggle.
class _TableResult extends StatefulWidget {
  const _TableResult({required this.rawText, this.signature, this.parsed});

  final String rawText;
  final String? signature;
  final ParsedEphemeris? parsed;

  @override
  State<_TableResult> createState() => _TableResultState();
}

class _TableResultState extends State<_TableResult> {
  bool _showRaw = false;

  Future<void> _exportCsv(ParsedEphemeris parsed) async {
    // Capture the messenger before the await — `context` must not cross it.
    final messenger = ScaffoldMessenger.of(context);
    final msg = await ExportService.saveText(
      ExportService.matrixToCsv(parsed.columns, parsed.rows),
      'horizons',
      'csv',
    );
    messenger.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = widget.parsed;
    // Non-CSV or prose result: nothing to tabulate, show raw only.
    if (parsed == null) {
      return _rawResponseBlock(
        context,
        widget.rawText,
        footer: widget.signature,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wrap (not Row+Spacer) so the controls reflow instead of overflowing
        // at high zoom.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Table')),
                ButtonSegment(value: true, label: Text('Raw')),
              ],
              selected: {_showRaw},
              onSelectionChanged: (s) => setState(() => _showRaw = s.first),
              showSelectedIcon: false,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.table_chart_outlined, size: 16),
              label: const Text('CSV'),
              onPressed: () => _exportCsv(parsed),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_showRaw)
          _rawResponseBlock(context, widget.rawText, footer: widget.signature)
        else
          _EphemerisTable(parsed: parsed, footer: widget.signature),
      ],
    );
  }
}

/// The parsed ephemeris rendered as a scrollable table. Nested scroll views
/// (vertical outer, horizontal inner) keep a wide/tall table inside its box
/// rather than overflowing — the CLAUDE.md rule for dense grids.
class _EphemerisTable extends StatelessWidget {
  const _EphemerisTable({required this.parsed, this.footer});

  final ParsedEphemeris parsed;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 36,
                  dataRowMinHeight: 28,
                  dataRowMaxHeight: 40,
                  columns: [
                    for (final column in parsed.columns)
                      DataColumn(
                        label: Text(column, style: theme.textTheme.labelSmall),
                      ),
                  ],
                  rows: [
                    for (final row in parsed.rows)
                      DataRow(
                        cells: [
                          for (final cell in row)
                            DataCell(
                              Text(
                                cell,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (footer != null) ...[
          const SizedBox(height: 4),
          Text(footer!, style: theme.textTheme.labelSmall),
        ],
      ],
    );
  }
}
