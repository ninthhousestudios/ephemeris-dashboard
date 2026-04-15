import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ephe/catalog.dart';
import '../../core/ephe/dir_provider.dart';
import '../../core/ephe/downloader.dart';
import '../../core/ephe/scanner.dart';
import '../../core/ephe/types.dart';
import '../../core/ephe/validation.dart';
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
  final Set<String> _selected = {};
  final Map<String, CancelToken> _cancels = {};

  @override
  void dispose() {
    // If the user closes the tab (or app) mid-download, explicitly cancel
    // every in-flight request. Otherwise dio keeps writing bytes into the
    // .part file in the background and our progress state is orphaned.
    for (final token in _cancels.values) {
      if (!token.isCancelled) token.cancel('manager screen disposed');
    }
    _cancels.clear();
    super.dispose();
  }

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
      data: (scan) {
        final allFiles = [..._buildAllFiles(scan)];
        // Drop stale selection IDs (files that no longer exist in the view).
        _selected.retainAll(allFiles.map((f) => f.filename).toSet());
        return Column(
          children: [
            if (_selected.isNotEmpty) _buildSelectionToolbar(allFiles),
            Expanded(
              child: ListView(
                children: [
                  _buildDirectoryHeader(settings, resolved ?? ''),
                  const Divider(height: 1),
                  _sectionHeader('Swiss Ephemeris'),
                  ..._buildSeRows(scan),
                  const Divider(height: 1),
                  _sectionHeader('JPL'),
                  ..._buildJplRows(scan),
                  const Divider(height: 1),
                  _sectionHeader('Asteroids'),
                  ..._buildAsteroidRows(scan),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Iterable<EpheFile> _buildAllFiles(EphemerisScan scan) sync* {
    final installedByName = {for (final f in scan.files) f.filename: f};
    yield* scan.files.where((f) =>
        f.family == BodyFamily.planets ||
        f.family == BodyFamily.moon ||
        f.family == BodyFamily.mainAsteroids ||
        f.family == BodyFamily.numberedAsteroid ||
        f.family == BodyFamily.fixedStars ||
        f.family == BodyFamily.jpl);
    yield* seCatalog
        .where((c) => !installedByName.containsKey(c.filename))
        .map(_catalogToMissing);
    yield* jplCatalog
        .where((c) => !installedByName.containsKey(c.filename))
        .map(_catalogToMissing);
    yield* asteroidCatalog
        .where((c) => !installedByName.containsKey(c.filename))
        .map(_catalogToMissing);
  }

  Widget _buildSelectionToolbar(List<EpheFile> allFiles) {
    final selectedFiles =
        allFiles.where((f) => _selected.contains(f.filename)).toList();
    EpheFileStatus statusOf(EpheFile f) =>
        _liveStatus[f.filename] ?? f.status;
    final deletable = selectedFiles
        .where((f) =>
            statusOf(f) == EpheFileStatus.installed ||
            statusOf(f) == EpheFileStatus.corrupt ||
            statusOf(f) == EpheFileStatus.partial)
        .toList();
    final downloadable = selectedFiles
        .where((f) =>
            (statusOf(f) == EpheFileStatus.missing ||
                statusOf(f) == EpheFileStatus.partial) &&
            catalogEntryFor(f.filename) != null)
        .toList();

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Clear selection',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_selected.clear),
            ),
            Text('${_selected.length} selected'),
            const Spacer(),
            if (downloadable.isNotEmpty)
              FilledButton.tonalIcon(
                onPressed: () => _handleBulkDownload(downloadable),
                icon: const Icon(Icons.download, size: 16),
                label: Text('Download ${downloadable.length}'),
              ),
            const SizedBox(width: 8),
            if (deletable.isNotEmpty)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onErrorContainer,
                ),
                onPressed: () => _handleBulkDelete(deletable),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text('Delete ${deletable.length}'),
              ),
          ],
        ),
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
                label: Text(settings.managedPath == null
                    ? 'Managed (unavailable — using bundled)'
                    : 'Managed'),
                tooltip: settings.managedPath == null
                    ? 'Could not resolve the app-support directory at '
                        'startup. The resolver is falling back to the '
                        'read-only bundled ephe path; deletes and '
                        'downloads will still be attempted against the '
                        'bundle.'
                    : null,
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
    // Known SE families + partials whose base name is also an SE file.
    final installedSe = scan.files
        .where((f) =>
            f.family == BodyFamily.planets ||
            f.family == BodyFamily.moon ||
            f.family == BodyFamily.mainAsteroids ||
            f.family == BodyFamily.fixedStars ||
            (f.status == EpheFileStatus.partial &&
                f.filename.endsWith('.se1')))
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
    final installed = scan.files
        .where((f) =>
            f.family == BodyFamily.jpl ||
            (f.status == EpheFileStatus.partial &&
                f.filename.endsWith('.eph')))
        .toList()
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
        subdir: c.subdir,
        mpcNumber: c.mpcNumber,
        sizeBytes: c.sizeBytes ?? 0,
        status: EpheFileStatus.missing,
      );

  List<Widget> _buildAsteroidRows(EphemerisScan scan) {
    final installedByName = {for (final f in scan.files) f.filename: f};
    final installed = scan.files
        .where((f) =>
            f.family == BodyFamily.numberedAsteroid ||
            (f.status == EpheFileStatus.partial &&
                f.filename.startsWith('se') &&
                f.filename.endsWith('.se1') &&
                RegExp(r'^se\d').hasMatch(f.filename)))
        .toList()
      ..sort((a, b) => (a.mpcNumber ?? 0).compareTo(b.mpcNumber ?? 0));
    final missing = asteroidCatalog
        .where((c) => !installedByName.containsKey(c.filename))
        .map(_catalogToMissing)
        .toList()
      ..sort((a, b) => (a.mpcNumber ?? 0).compareTo(b.mpcNumber ?? 0));
    return [
      for (final f in installed) _rowFor(f),
      for (final f in missing) _rowFor(f),
    ];
  }

  Widget _rowFor(EpheFile f) {
    final liveStatus = _liveStatus[f.filename] ?? f.status;
    final liveProgress = _progress[f.filename];
    final effective = f.copyWith(
      status: liveStatus,
      downloadProgress: liveProgress,
    );
    final selectable = effective.status != EpheFileStatus.downloading;
    final isPartial = effective.status == EpheFileStatus.partial;
    return EpheFileRow(
      file: effective,
      onDelete: effective.status == EpheFileStatus.installed ||
              effective.status == EpheFileStatus.corrupt ||
              isPartial
          ? () => _handleDelete(effective)
          : null,
      onDownload: effective.status == EpheFileStatus.missing || isPartial
          ? () => _handleDownload(effective)
          : null,
      onDropIn: effective.status == EpheFileStatus.missing
          ? () => _handleDropIn(effective)
          : null,
      onCancel: effective.status == EpheFileStatus.downloading
          ? () => _handleCancel(effective)
          : null,
      selected: _selected.contains(f.filename),
      onSelectedChanged: selectable
          ? (v) => setState(() {
                if (v == true) {
                  _selected.add(f.filename);
                } else {
                  _selected.remove(f.filename);
                }
              })
          : null,
    );
  }

  Future<void> _handleBulkDelete(List<EpheFile> files) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${files.length} file(s)?'),
        content: Text(
          'This will remove these files from disk:\n\n'
          '${files.map((f) => '• ${f.filename}').join('\n')}',
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
    final errors = <String>[];
    for (final f in files) {
      try {
        _deleteFileAndPart(dir, f);
        _selected.remove(f.filename);
      } catch (e) {
        errors.add('${f.filename}: $e');
      }
    }
    if (!mounted) return;
    setState(() {});
    ref.invalidate(ephemerisScanProvider);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Some deletes failed: ${errors.join('; ')}')),
      );
    }
  }

  Future<void> _handleBulkDownload(List<EpheFile> files) async {
    final prefs = ref.read(sharedPrefsProvider);
    final accepted = await maybeShowLicenseNotice(context, prefs);
    if (!accepted || !mounted) return;
    // Serialize to keep bandwidth predictable and UI tidy.
    for (final f in files) {
      if (!mounted) return;
      await _runDownload(f);
      _selected.remove(f.filename);
      if (mounted) setState(() {});
    }
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
      _deleteFileAndPart(dir, f);
      ref.invalidate(ephemerisScanProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  /// Remove both the final file and any matching .part alongside it.
  /// Safe on absent files. Honors [EpheFile.subdir] so asteroid files
  /// stored under `astX/` are deleted from the right location.
  void _deleteFileAndPart(String dir, EpheFile file) {
    final parent = file.subdir.isEmpty ? dir : '$dir/${file.subdir}';
    final full = File('$parent/${file.filename}');
    if (full.existsSync()) full.deleteSync();
    final part = File('$parent/${file.filename}.part');
    if (part.existsSync()) part.deleteSync();
  }

  Future<void> _handleDownload(EpheFile f) async {
    final prefs = ref.read(sharedPrefsProvider);
    final accepted = await maybeShowLicenseNotice(context, prefs);
    if (!accepted || !mounted) return;
    await _runDownload(f);
  }

  Future<void> _runDownload(EpheFile f) async {
    final entry = catalogEntryFor(f.filename);
    if (entry == null) return;
    final dir = ref.read(resolvedEphePathProvider);
    if (dir == null) return;

    final downloader = ref.read(downloaderProvider);
    final cancel = CancelToken();
    setState(() {
      _liveStatus[f.filename] = EpheFileStatus.downloading;
      _progress[f.filename] = 0;
      _cancels[f.filename] = cancel;
    });

    try {
      await for (final p in downloader.download(
        entry: entry,
        destDir: dir,
        cancel: cancel,
        confirmLargeDownload: (size) => _confirmLarge(entry.filename, size),
      )) {
        if (!mounted) return;
        setState(() => _progress[f.filename] = p.fraction);
      }
      if (!mounted) return;
      setState(() {
        _liveStatus.remove(f.filename);
        _progress.remove(f.filename);
        _cancels.remove(f.filename);
      });
      ref.invalidate(ephemerisScanProvider);
    } on DownloadFailed catch (e) {
      if (!mounted) return;
      setState(() {
        _liveStatus[f.filename] = EpheFileStatus.missing;
        _progress.remove(f.filename);
        _cancels.remove(f.filename);
      });
      // User-initiated cancel — don't blast a scary "failed" snackbar.
      if (cancel.isCancelled) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          showCloseIcon: true,
          content: Text(
            'Download failed (${f.filename}): ${_shortError(e.message)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _runDownload(f),
          ),
        ),
      );
    }
  }

  Future<void> _handleCancel(EpheFile f) async {
    final token = _cancels[f.filename];
    if (token != null && !token.isCancelled) {
      token.cancel('user-cancelled');
    }
    // Delete the stale .part so the next retry starts fresh rather than
    // resuming a possibly-bogus partial (e.g. 404 HTML written to disk).
    final dir = ref.read(resolvedEphePathProvider);
    if (dir != null) {
      final parent = f.subdir.isEmpty ? dir : '$dir/${f.subdir}';
      final part = File('$parent/${f.filename}.part');
      if (part.existsSync()) {
        try {
          part.deleteSync();
        } catch (_) {/* best-effort */}
      }
    }
  }

  /// Dio tacks a multi-paragraph MDN blurb onto HTTP-status errors.
  /// Keep just the first line so the snackbar stays dismissible.
  String _shortError(String raw) {
    final firstLine = raw.split('\n').first.trim();
    const maxLen = 160;
    return firstLine.length > maxLen
        ? '${firstLine.substring(0, maxLen)}…'
        : firstLine;
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
    // Sniff the source before copying so we don't seed the managed dir
    // with an HTML error page or a truncated file a user picked by mistake.
    final rej = validateEpheFile(File(src));
    if (rej != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejected: ${describeRejection(rej)}')),
      );
      return;
    }
    try {
      final parent = f.subdir.isEmpty ? dir : '$dir/${f.subdir}';
      if (f.subdir.isNotEmpty) {
        final d = Directory(parent);
        if (!d.existsSync()) d.createSync(recursive: true);
      }
      await File(src).copy('$parent/${f.filename}');
      ref.invalidate(ephemerisScanProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copy failed: $e')),
      );
    }
  }
}
