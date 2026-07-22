// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';

import '../core/export_service.dart';

/// One named projection of the same results, offered as a choice in the menu.
class ExportVariant {
  const ExportVariant(this.label, this.getRows);

  final String label;
  final List<ExportRow> Function() getRows;
}

/// Icon button (tap = copy TSV) + dropdown menu for all export formats.
///
/// Reusable across any tab — just provide a [getRows] callback and
/// a [filenameStem]. Disables when [hasResults] is false.
///
/// [ExportButton.variants] is the same button over several projections of one
/// result set (series vertical/horizontal): the menu grows a radio group above
/// the formats and every format — including tap-to-copy — uses the selected
/// one. Keeping it here rather than in a second button is what stops the
/// format list from being written twice.
///
/// The selection is *controlled* — [selected] in, [onSelected] out. The button
/// holds no notion of a current variant, so a caller that persists the choice
/// (as `SeriesView` does) cannot end up disagreeing with it.
class ExportButton extends StatefulWidget {
  ExportButton({
    super.key,
    required List<ExportRow> Function() getRows,
    required this.filenameStem,
    this.hasResults = true,
    this.disabledTooltip,
  }) : variants = [ExportVariant('', getRows)],
       selected = 0,
       onSelected = null;

  const ExportButton.variants({
    super.key,
    required this.variants,
    required this.selected,
    required this.onSelected,
    required this.filenameStem,
    this.hasResults = true,
    this.disabledTooltip,
  });

  /// Index into [variants] of the projection every format will use.
  final int selected;

  final ValueChanged<int>? onSelected;

  /// The projections on offer. The single-projection constructor makes one
  /// unnamed entry, so there is one code path and no nullable callback: the
  /// radio group is simply what a list longer than one renders as.
  final List<ExportVariant> variants;
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
    final variants = widget.variants;
    // Clamped rather than indexed raw: `selected` comes from persisted
    // settings, which can outlive the variant list that produced it.
    final rows = variants[widget.selected.clamp(0, variants.length - 1)]
        .getRows();
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
        if (widget.variants.length > 1) ...[
          for (final (index, variant) in widget.variants.indexed)
            RadioMenuButton<int>(
              value: index,
              groupValue: widget.selected,
              // The layout is a modifier on the format items below, so picking
              // one must leave the menu open.
              closeOnActivate: false,
              onChanged: (value) => widget.onSelected?.call(value ?? 0),
              child: Text(variant.label),
            ),
          const Divider(height: 8),
        ],
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
