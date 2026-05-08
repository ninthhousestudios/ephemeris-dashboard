import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ephemeris/emitter_provider.dart';

class CodeActionButton extends ConsumerWidget {
  const CodeActionButton({
    super.key,
    required this.onCode,
    this.iconSize = 18,
    this.compact = false,
    this.visualDensity,
  });

  final VoidCallback? onCode;
  final double iconSize;
  final bool compact;
  final VisualDensity? visualDensity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(selectedEmitterProvider);

    if (compact) {
      return PopupMenuButton<Object>(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        icon: Icon(Icons.code, size: iconSize),
        tooltip: 'View ${current.displayName} code',
        onSelected: (value) {
          if (value is CodeEmitter) {
            ref.read(selectedEmitterProvider.notifier).state = value;
          }
          onCode?.call();
        },
        itemBuilder: (_) => [
          PopupMenuItem<Object>(
            value: 'run',
            child: Text('View as ${current.displayName}'),
          ),
          const PopupMenuDivider(),
          ...availableEmitters.map((e) => PopupMenuItem<Object>(
                value: e,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e.languageId == current.languageId)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(e.displayName),
                  ],
                ),
              )),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.code, size: iconSize),
          tooltip: 'View ${current.displayName} code',
          onPressed: onCode,
          visualDensity: visualDensity,
        ),
        SizedBox(
          width: 20,
          child: PopupMenuButton<CodeEmitter>(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.arrow_drop_down, size: iconSize),
            tooltip: 'Change language',
            onSelected: (emitter) {
              ref.read(selectedEmitterProvider.notifier).state = emitter;
              onCode?.call();
            },
            itemBuilder: (_) => availableEmitters
                .map((e) => PopupMenuItem(
                      value: e,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (e.languageId == current.languageId)
                            const Icon(Icons.check, size: 16)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(e.displayName),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
