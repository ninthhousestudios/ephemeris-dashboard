import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/chart_io.dart';

/// A themed in-app file browser dialog for opening chart files.
///
/// Shows a directory listing with navigation, a file-type filter dropdown,
/// and a path text field. Returns the selected file path or null.
class ChartFileDialog extends StatefulWidget {
  const ChartFileDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const ChartFileDialog(),
    );
  }

  @override
  State<ChartFileDialog> createState() => _ChartFileDialogState();
}

class _ChartFileDialogState extends State<ChartFileDialog> {
  late Directory _currentDir;
  final _pathController = TextEditingController();
  String _selectedFilter = _allFilesKey;
  String? _selectedPath;
  List<FileSystemEntity> _entries = [];
  bool _loading = true;
  String? _error;

  static const _allFilesKey = 'all';

  /// Filter options: "All supported" + one per format.
  static final _filters = <String, String>{
    _allFilesKey: 'All chart files (${ChartIO.supportedExtensions.join(", ")})',
    for (final entry in ChartIO.formatDescriptions.entries)
      entry.key: '${entry.value} (*${entry.key})',
  };

  @override
  void initState() {
    super.initState();
    _currentDir = Directory(Platform.environment['HOME'] ?? '/');
    _pathController.text = _currentDir.path;
    _loadDir();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Set<String> get _activeExtensions {
    if (_selectedFilter == _allFilesKey) {
      return ChartIO.supportedExtensions.toSet();
    }
    return {_selectedFilter};
  }

  void _loadDir() {
    setState(() {
      _loading = true;
      _error = null;
      _selectedPath = null;
    });

    try {
      final raw = _currentDir.listSync();
      final dirs = <Directory>[];
      final files = <File>[];
      final exts = _activeExtensions;

      for (final e in raw) {
        final name = p.basename(e.path);
        if (name.startsWith('.')) continue; // skip hidden
        if (e is Directory) {
          dirs.add(e);
        } else if (e is File) {
          final ext = p.extension(e.path).toLowerCase();
          if (exts.contains(ext)) {
            files.add(e);
          }
        }
      }

      dirs.sort(
        (a, b) => p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase()),
      );
      files.sort(
        (a, b) => p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase()),
      );

      setState(() {
        _entries = [...dirs, ...files];
        _loading = false;
        _pathController.text = _currentDir.path;
      });
    } catch (e) {
      setState(() {
        _entries = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _navigateTo(Directory dir) {
    _currentDir = dir;
    _loadDir();
  }

  void _goUp() {
    final parent = _currentDir.parent;
    if (parent.path != _currentDir.path) {
      _navigateTo(parent);
    }
  }

  void _commitPath() {
    final text = _pathController.text.trim();
    if (text.isEmpty) return;
    final entity = FileSystemEntity.typeSync(text);
    if (entity == FileSystemEntityType.directory) {
      _navigateTo(Directory(text));
    } else if (entity == FileSystemEntityType.file) {
      Navigator.of(context).pop(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
          maxHeight: 550,
          minWidth: 450,
          minHeight: 350,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text('Open Chart', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),

              // Path bar + up button
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    tooltip: 'Parent directory',
                    onPressed: _goUp,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _pathController,
                      style: theme.textTheme.bodySmall,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          tooltip: 'Go',
                          onPressed: _commitPath,
                        ),
                      ),
                      onSubmitted: (_) => _commitPath(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // File type filter
              Row(
                children: [
                  Text('Type: ', style: theme.textTheme.labelSmall),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      isExpanded: true,
                      isDense: true,
                      style: theme.textTheme.bodySmall,
                      underline: const SizedBox.shrink(),
                      items: _filters.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          _selectedFilter = v;
                          _loadDir();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // File listing
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                    color: colors.surfaceContainerLow,
                  ),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.error),
                          ),
                        )
                      : _entries.isEmpty
                      ? Center(
                          child: Text(
                            'No matching files',
                            style: theme.textTheme.bodySmall,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, i) {
                            final entry = _entries[i];
                            final isDir = entry is Directory;
                            final name = p.basename(entry.path);
                            final isSelected = entry.path == _selectedPath;

                            return GestureDetector(
                              onDoubleTap: () {
                                if (entry is Directory) {
                                  _navigateTo(entry);
                                } else {
                                  Navigator.of(context).pop(entry.path);
                                }
                              },
                              child: ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: colors.primaryContainer,
                                leading: Icon(
                                  isDir
                                      ? Icons.folder
                                      : Icons.insert_drive_file,
                                  size: 18,
                                  color: isDir
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                                title: Text(
                                  name,
                                  style: theme.textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: isDir
                                    ? null
                                    : Text(
                                        ChartIO.formatDescriptions[p
                                                .extension(entry.path)
                                                .toLowerCase()] ??
                                            '',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                onTap: () {
                                  if (entry is Directory) {
                                    _navigateTo(entry);
                                  } else {
                                    setState(() {
                                      _selectedPath = entry.path;
                                    });
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedPath != null
                        ? () => Navigator.of(context).pop(_selectedPath)
                        : null,
                    child: const Text('Open'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
