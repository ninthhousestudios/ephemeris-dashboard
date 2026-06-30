import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void showCodeModal(
  BuildContext context, {
  required String code,
  required String languageLabel,
}) {
  showDialog(
    context: context,
    builder: (ctx) => CodeModal(code: code, languageLabel: languageLabel),
  );
}

class CodeModal extends StatelessWidget {
  const CodeModal({super.key, required this.code, required this.languageLabel});

  final String code;
  final String languageLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.code, size: 20),
                  const SizedBox(width: 8),
                  Text(languageLabel, style: theme.textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy to clipboard',
                    onPressed: () async {
                      try {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copy failed'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Code body — scrollable both axes
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    code,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
