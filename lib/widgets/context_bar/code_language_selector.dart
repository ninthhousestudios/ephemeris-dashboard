import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ephemeris/emitter_provider.dart';

class CodeLanguageSelector extends ConsumerWidget {
  const CodeLanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emitter = ref.watch(selectedEmitterProvider);
    return PopupMenuButton<CodeEmitter>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minHeight: 24),
      tooltip: 'Code language',
      onSelected: (e) => ref.read(selectedEmitterProvider.notifier).state = e,
      itemBuilder: (_) => availableEmitters
          .map(
            (e) => PopupMenuItem(
              value: e,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.languageId == emitter.languageId)
                    const Icon(Icons.check, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(e.displayName),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.code, size: 14),
            const SizedBox(width: 4),
            Text(
              emitter.displayName,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const Icon(Icons.arrow_drop_down, size: 14),
          ],
        ),
      ),
    );
  }
}
