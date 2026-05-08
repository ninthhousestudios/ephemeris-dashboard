import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'code_action_button.dart';

/// A single key-value pair in a result card.
class ResultField {
  const ResultField({required this.label, required this.value, this.rawValue});
  final String label;

  /// Formatted value (respects current DisplayFormat).
  final String value;

  /// Raw numeric value for copy/export (optional).
  final double? rawValue;
}

/// Generic result card used across all tabs.
///
/// Shows a header (function name, body, flag hex), a list of
/// key-value result fields, and action buttons (copy, pin).
/// Format toggle is tab-level only — not per-card.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.title,
    this.subtitle,
    this.flagHex,
    required this.fields,
    this.onCode,
  });

  final String title;
  final String? subtitle;
  final String? flagHex;
  final List<ResultField> fields;
  final VoidCallback? onCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.all(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            )),
                    ],
                  ),
                ),
                if (flagHex != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(flagHex!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Result fields
            ...fields.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80 * MediaQuery.textScalerOf(context).scale(1.0),
                        child: Text(f.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            )),
                      ),
                      Expanded(
                        child: SelectableText(f.value,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            )),
                      ),
                    ],
                  ),
                )),
            // Action row: copy + pin
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy to clipboard',
                  onPressed: () async {
                    final text = fields.map((f) => '${f.label}: ${f.value}').join('\n');
                    try {
                      await Clipboard.setData(ClipboardData(text: '$title\n$text'));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copy failed'), duration: Duration(seconds: 1)),
                        );
                      }
                    }
                  },
                ),
                CodeActionButton(onCode: onCode),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
