import 'package:flutter/material.dart';

import '../core/export_service.dart';

/// Icon button (tap = copy TSV) + dropdown menu for all export formats.
///
/// Reusable across any tab — just provide a [getRows] callback and
/// a [filenameStem]. Disables when [hasResults] is false.
class ExportButton extends StatefulWidget {
  const ExportButton({
    super.key,
    required this.getRows,
    required this.filenameStem,
    this.hasResults = true,
    this.disabledTooltip,
  });

  final List<ExportRow> Function() getRows;
  final String filenameStem;
  final bool hasResults;

  /// Shown instead of the default tooltip while disabled — e.g. to
  /// distinguish "no results selected" from "calculation failed".
  final String? disabledTooltip;

  @override
  State<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<ExportButton> {
  final _menuController = MenuController();

  Future<void> _export(ExportFormat format) async {
    final rows = widget.getRows();
    if (rows.isEmpty) return;
    final msg = await ExportService.export(rows, format, widget.filenameStem);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.content_copy, size: 18),
          child: const Text('Copy as TSV'),
          onPressed: () => _export(ExportFormat.tsvClipboard),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.text_snippet_outlined, size: 18),
          child: const Text('Copy colon-separated'),
          onPressed: () => _export(ExportFormat.colonClipboard),
        ),
        const Divider(height: 8),
        MenuItemButton(
          leadingIcon: const Icon(Icons.table_chart_outlined, size: 18),
          child: const Text('Save as CSV...'),
          onPressed: () => _export(ExportFormat.csvFile),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.data_object, size: 18),
          child: const Text('Save as JSON...'),
          onPressed: () => _export(ExportFormat.jsonFile),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.file_download, size: 18),
            tooltip: widget.hasResults
                ? 'Copy all results (TSV)'
                : (widget.disabledTooltip ?? 'Copy all results (TSV)'),
            onPressed: widget.hasResults
                ? () => _export(ExportFormat.tsvClipboard)
                : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_drop_down, size: 18),
            tooltip: widget.hasResults
                ? 'Export options'
                : (widget.disabledTooltip ?? 'Export options'),
            onPressed: widget.hasResults
                ? () => _menuController.isOpen
                      ? _menuController.close()
                      : _menuController.open()
                : null,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
