import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ephe/catalog.dart';
import '../../core/ephe/dir_provider.dart';
import '../../core/ephe/downloader.dart';
import '../../core/ephe/scanner.dart';
import '../../core/ephe/types.dart';
import '../../core/persistence.dart';
import 'file_row.dart';
import 'license_notice.dart';

class EphemerisManagerScreen extends ConsumerStatefulWidget {
  const EphemerisManagerScreen({super.key});

  @override
  ConsumerState<EphemerisManagerScreen> createState() =>
      _EphemerisManagerScreenState();
}

class _EphemerisManagerScreenState
    extends ConsumerState<EphemerisManagerScreen> {
  final Map<String, double> _progress = {};
  final Map<String, EpheFileStatus> _liveStatus = {};

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The ephemeris file manager is only available on desktop. '
            'The web build uses the analytical Moshier model.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final scanAsync = ref.watch(ephemerisScanProvider);
    final settings = ref.watch(ephemerisDirectoryProvider);
    final resolved = ref.watch(resolvedEphePathProvider);

    return scanAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Scan failed: $e')),
      data: (scan) => ListView(
        children: [
          _buildDirectoryHeader(settings, resolved ?? ''),
          const Divider(height: 1),
          _sectionHeader('Swiss Ephemeris'),
          ..._buildSeRows(scan),
          const Divider(height: 1),
          _sectionHeader('JPL'),
          ..._buildJplRows(scan),
        ],
      ),
    );
  }

  Widget _buildDirectoryHeader(
    EphemerisDirectorySettings settings,
    String resolvedPath,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Current directory',
                  style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Rescan',
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => ref.invalidate(ephemerisScanProvider),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            resolvedPath.isEmpty ? '(none)' : resolvedPath,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Managed'),
                selected: settings.useManaged,
                onSelected: (_) =>
                    ref.read(ephemerisDirectoryProvider.notifier).useManaged(),
              ),
              FilterChip(
                label: Text(
                  settings.useManaged
                      ? 'Custom…'
                      : 'Custom: ${settings.customPath ?? '(not set)'}',
                ),
                selected: !settings.useManaged,
                onSelected: (_) async {
                  final path = await FilePicker.platform.getDirectoryPath();
                  if (path == null || !mounted) return;
                  ref
                      .read(ephemerisDirectoryProvider.notifier)
                      .useCustom(path);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  List<Widget> _buildSeRows(EphemerisScan scan) {
    final installedByName = {for (final f in scan.files) f.filename: f};
    // Installed SE files first (all of scan minus JPL/unknown), then catalog-only missing.
    final installedSe = scan.files
        .where((f) =>
            f.family == BodyFamily.planets ||
            f.family == BodyFamily.moon ||
            f.family == BodyFamily.mainAsteroids ||
            f.family == BodyFamily.fixedStars)
        .toList()
      ..sort((a, b) => a.filename.compareTo(b.filename));

    final missingSe = seCatalog
        .where((c) => !installedByName.containsKey(c.filename))
        .map(_catalogToMissing)
        .toList();

    return [
      for (final f in installedSe) _rowFor(f),
      for (final f in missingSe) _rowFor(f),
    ];
  }

  List<Widget> _buildJplRows(EphemerisScan scan) {
    final installedByName = {for (final f in scan.files) f.filename: f};
    final installed =
        scan.files.where((f) => f.family == BodyFamily.jpl).toList()
          ..sort((a, b) => a.filename.compareTo(b.filename));
    final missing = jplCatalog
        .where((c) => !installedByName.containsKey(c.filename))
        .map(_catalogToMissing)
        .toList();
    return [
      for (final f in installed) _rowFor(f),
      for (final f in missing) _rowFor(f),
    ];
  }

  EpheFile _catalogToMissing(CatalogEntry c) => EpheFile(
        filename: c.filename,
        family: c.family,
        startJd: 0,
        endJd: 0,
        startYear: c.startYear,
        endYear: c.endYear,
        sizeBytes: c.sizeBytes ?? 0,
        status: EpheFileStatus.missing,
      );

  Widget _rowFor(EpheFile f) {
    final liveStatus = _liveStatus[f.filename] ?? f.status;
    final liveProgress = _progress[f.filename];
    final effective = f.copyWith(
      status: liveStatus,
      downloadProgress: liveProgress,
    );
    return EpheFileRow(
      file: effective,
      onDelete: effective.status == EpheFileStatus.installed ||
              effective.status == EpheFileStatus.corrupt
          ? () => _handleDelete(effective)
          : null,
      onDownload: effective.status == EpheFileStatus.missing
          ? () => _handleDownload(effective)
          : null,
      onDropIn: effective.status == EpheFileStatus.missing
          ? () => _handleDropIn(effective)
          : null,
      onCancel: null, // Phase 1: cancel UX deferred.
    );
  }

  Future<void> _handleDelete(EpheFile f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${f.filename}?'),
        content: Text(
          'This will remove the file from disk. You can re-download it '
          'from the catalog afterwards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final dir = ref.read(resolvedEphePathProvider);
    if (dir == null) return;
    try {
      File('$dir/${f.filename}').deleteSync();
      ref.invalidate(ephemerisScanProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _handleDownload(EpheFile f) async {
    final prefs = ref.read(sharedPrefsProvider);
    final accepted = await maybeShowLicenseNotice(context, prefs);
    if (!accepted || !mounted) return;

    final entry = catalogEntryFor(f.filename);
    if (entry == null) return;
    final dir = ref.read(resolvedEphePathProvider);
    if (dir == null) return;

    final downloader = ref.read(downloaderProvider);
    setState(() {
      _liveStatus[f.filename] = EpheFileStatus.downloading;
      _progress[f.filename] = 0;
    });

    try {
      await for (final p in downloader.download(
        entry: entry,
        destDir: dir,
        confirmLargeDownload: (size) => _confirmLarge(entry.filename, size),
      )) {
        if (!mounted) return;
        setState(() => _progress[f.filename] = p.fraction);
      }
      if (!mounted) return;
      setState(() {
        _liveStatus.remove(f.filename);
        _progress.remove(f.filename);
      });
      ref.invalidate(ephemerisScanProvider);
    } on DownloadFailed catch (e) {
      if (!mounted) return;
      setState(() {
        _liveStatus[f.filename] = EpheFileStatus.missing;
        _progress.remove(f.filename);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.message}'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _handleDownload(f),
          ),
        ),
      );
    }
  }

  Future<bool> _confirmLarge(String filename, int size) async {
    final mb = (size / (1024 * 1024)).toStringAsFixed(0);
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Download $filename — $mb MB?'),
        content: const Text(
          'This will use significant disk space and bandwidth. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _handleDropIn(EpheFile f) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['se1', 'eph'],
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final src = picked.files.single.path;
    if (src == null) return;
    final dir = ref.read(resolvedEphePathProvider);
    if (dir == null) return;
    try {
      await File(src).copy('$dir/${f.filename}');
      ref.invalidate(ephemerisScanProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copy failed: $e')),
      );
    }
  }
}
