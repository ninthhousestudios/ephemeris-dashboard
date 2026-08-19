// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sign_names.dart';

/// Define a new user-defined sign-name set from the context bar: an optional
/// name and 12 sign names (the equal 30° divisions, index 0 = the 0–30° sign).
/// The 12 fields are pre-filled with the zodiac names; a field left blank falls
/// back to its zodiac name so no slot renders empty.
///
/// The entry goes into the app-wide list, and on OK the selection points at it.
/// Returns true on OK, false on cancel. Mirrors [showUserAyanamsaDialog].
Future<bool> showUserSignSetDialog(BuildContext context, WidgetRef ref) async {
  final nameCtrl = TextEditingController();
  final nameCtrls = [
    for (final n in zodiacNames) TextEditingController(text: n),
  ];

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('User-defined Sign Names'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '12 names for the equal 30° signs, in order from 0°. Blank '
                'fields fall back to the zodiac name.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Set name (optional)',
                  helperText: 'Left blank, it is numbered "Sign set N"',
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < 12; i++) ...[
                TextField(
                  controller: nameCtrls[i],
                  decoration: InputDecoration(
                    labelText: '${i * 30}°–${(i + 1) * 30}°',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final names = [
              for (var i = 0; i < 12; i++)
                nameCtrls[i].text.trim().isEmpty
                    ? zodiacNames[i]
                    : nameCtrls[i].text.trim(),
            ];
            final name = nameCtrl.text.trim();
            final id = ref
                .read(userSignSetsProvider.notifier)
                .add(name: name.isEmpty ? null : name, names: names);
            ref.read(signNameSelectionProvider.notifier).selectUserSet(id);
            Navigator.of(ctx).pop(true);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
  return result ?? false;
}
