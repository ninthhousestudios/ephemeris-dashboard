import 'package:flutter/material.dart';

import '../../core/ephe/types.dart';

class EpheFileRow extends StatelessWidget {
  const EpheFileRow({
    super.key,
    required this.file,
    required this.onDelete,
    required this.onDownload,
    required this.onDropIn,
    required this.onCancel,
  });

  final EpheFile file;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;
  final VoidCallback? onDropIn;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = file.startYear == file.endYear
        ? '—'
        : '${file.startYear} – ${file.endYear}';
    final sizeMB = file.sizeBytes > 0
        ? '${(file.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '—';

    final statusChip = _StatusChip(status: file.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(file.filename, style: theme.textTheme.bodyMedium),
          Text(range, style: theme.textTheme.bodySmall),
          Text(sizeMB, style: theme.textTheme.bodySmall),
          statusChip,
          if (file.status == EpheFileStatus.downloading &&
              file.downloadProgress != null)
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(value: file.downloadProgress),
            ),
          ..._actions(),
        ],
      ),
    );
  }

  List<Widget> _actions() {
    switch (file.status) {
      case EpheFileStatus.installed:
        return [
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
          ),
        ];
      case EpheFileStatus.missing:
        return [
          if (onDownload != null)
            FilledButton.tonalIcon(
              onPressed: onDownload,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download'),
            ),
          if (onDropIn != null)
            TextButton.icon(
              onPressed: onDropIn,
              icon: const Icon(Icons.file_upload, size: 16),
              label: const Text('Drop in file…'),
            ),
        ];
      case EpheFileStatus.corrupt:
        return [
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
          ),
        ];
      case EpheFileStatus.downloading:
        return [
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
          ),
        ];
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final EpheFileStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String label, Color bg, Color fg) = switch (status) {
      EpheFileStatus.installed => (
          'Installed',
          theme.colorScheme.secondaryContainer,
          theme.colorScheme.onSecondaryContainer,
        ),
      EpheFileStatus.missing => (
          'Missing',
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurface,
        ),
      EpheFileStatus.corrupt => (
          'Corrupt',
          theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer,
        ),
      EpheFileStatus.downloading => (
          'Downloading',
          theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: fg)),
    );
  }
}
