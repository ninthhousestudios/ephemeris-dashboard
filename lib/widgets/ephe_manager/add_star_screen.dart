// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ephe/dir_provider.dart';
import '../../core/ephe/simbad.dart';
import '../../tabs/stars/stars_provider.dart';

/// "Add Stars" subtab of the Ephemeris Manager: look a star up on SIMBAD and
/// append its entry (plus any user-chosen search names) to `sefstars.txt` on
/// the active ephe path, then reload the in-memory star catalog.
class AddStarScreen extends ConsumerStatefulWidget {
  const AddStarScreen({super.key});

  @override
  ConsumerState<AddStarScreen> createState() => _AddStarScreenState();
}

class _AddStarScreenState extends ConsumerState<AddStarScreen> {
  final _queryCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  final _customNames = <String>[];

  SimbadStar? _result;
  bool _loading = false;
  bool _writing = false;
  String? _error;

  @override
  void dispose() {
    _queryCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final star = await querySimbad(q, ref.read(simbadDioProvider));
      if (!mounted) return;
      setState(() {
        _result = star;
        _loading = false;
      });
    } on SimbadException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _addCustomName() {
    final name = _customCtrl.text.trim();
    if (name.isEmpty || _customNames.contains(name)) return;
    setState(() {
      _customNames.add(name);
      _customCtrl.clear();
    });
  }

  Future<void> _addToCatalogue() async {
    final result = _result;
    if (result == null || _writing) return;

    final ephePath = ref.read(resolvedEphePathProvider);
    if (ephePath == null) {
      _snack('No ephemeris directory is resolved — set one in the manager.');
      return;
    }

    final lines = buildEntryLines(result, extraNames: _customNames);
    if (!validateEntry(lines)) {
      _snack('SIMBAD data was incomplete — the entry would be malformed.');
      return;
    }

    setState(() => _writing = true);
    try {
      final file = File('$ephePath/sefstars.txt');
      final existing = file.existsSync() ? file.readAsStringSync() : '';
      final dedup = dedupEntries(existing, lines);
      if (dedup.append.isEmpty) {
        _snack('Every name is already in the catalogue.');
        return;
      }
      // Guard against gluing our first line onto a file that lacks a trailing
      // newline (which would corrupt the last existing entry).
      final prefix = existing.isNotEmpty && !existing.endsWith('\n')
          ? '\n'
          : '';
      file.writeAsStringSync(
        prefix + dedup.append.join(),
        mode: FileMode.append,
      );

      // The search fields read the catalog from memory; reload it so the new
      // names are immediately selectable.
      ref.invalidate(starCatalogProvider);

      final skippedNote = dedup.skipped.isEmpty
          ? ''
          : ' (skipped duplicates: ${dedup.skipped.join(', ')})';
      _snack('Added ${dedup.added.join(', ')}$skippedNote');
    } catch (e) {
      _snack('Write failed: $e');
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Adding stars to the catalogue is only available on desktop. The '
          'web build reads a bundled, read-only sefstars.txt.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Look a fixed star up on SIMBAD and add it to the catalogue on the '
            'active ephemeris path. Every name becomes searchable in the star '
            'fields across the app.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _queryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SIMBAD query',
                    hintText: 'e.g. 62 Sagittarii, HIP 98688, alf Tau',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : _search,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search, size: 18),
                label: const Text('Search'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            _buildResult(theme, _result!),
          ],
        ],
      ),
    );
  }

  Widget _buildResult(ThemeData theme, SimbadStar star) {
    final lines = buildEntryLines(star, extraNames: _customNames);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SIMBAD result', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _field('Nomenclature', star.nomenName),
        _field('Long form', nomenToLongForm(star.nomenName)),
        if (star.tradName.isNotEmpty) _field('Traditional name', star.tradName),
        if (star.hipId != 'no hip id') _field('HIP id', star.hipId),
        _field(
          'ICRS',
          'RA ${star.raHour} ${star.raMinute} ${star.raSec}  '
              'Dec ${star.decDegree} ${star.decMinute} ${star.decSec}',
        ),
        _field('Magnitude (V)', star.magV),
        const SizedBox(height: 20),
        Text('Extra search names', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Add any additional names you want to search this star by. Each '
          'becomes its own catalogue line.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: TextField(
                controller: _customCtrl,
                decoration: const InputDecoration(
                  labelText: 'Custom name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _addCustomName(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _addCustomName,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add name'),
            ),
          ],
        ),
        if (_customNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in _customNames)
                InputChip(
                  label: Text(name),
                  onDeleted: () => setState(() => _customNames.remove(name)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Catalogue lines to be written',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            lines.join(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _writing ? null : _addToCatalogue,
          icon: _writing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.library_add, size: 18),
          label: const Text('Add to Catalogue'),
        ),
      ],
    );
  }

  Widget _field(String label, String value) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: (140 * scale).floorToDouble(),
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
