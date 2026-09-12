// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/date_time_input.dart';
import '../../core/timezone_offset.dart';

/// The linked IANA time zone, shown as a full visible string beneath the
/// location row (swe-dashboard/112). Names *which* zone is driving the derived
/// UTC offset, and flags it amber when the value is low-confidence (pre-1970,
/// LMT, DST gap/fold) — the honest "verify this" signal, never hidden behind a
/// hover. Self-hides (zero height) when the offset is manual/free.
class ContextTimeZoneLabel extends ConsumerWidget {
  const ContextTimeZoneLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(contextTzStatusProvider);
    if (status == null) return const SizedBox.shrink();

    final res = status.resolution;
    final theme = Theme.of(context);
    final low = res.lowConfidence;
    final color = low
        ? Colors.amber.shade800
        : theme.colorScheme.onSurfaceVariant;
    final icon = !res.resolved
        ? Icons.help_outline
        : (low ? Icons.warning_amber_rounded : Icons.public);

    final label = StringBuffer('Time zone: ${status.zoneId}');
    if (res.resolved && res.abbreviation != null) {
      label.write(' · ${res.abbreviation} ${fmtOffset(res.offsetHours)}');
    }
    String? tooltip;
    if (!res.resolved) {
      label.write(' — not in database, verify manually');
    } else if (low) {
      label.write(' — approximate, verify');
      // Full reasons on hover; the inline line stays short.
      tooltip = describeTzWarnings(res.warnings);
    } else {
      tooltip = 'Editing the offset unlinks it.';
    }

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label.toString(),
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: tooltip == null ? row : Tooltip(message: tooltip, child: row),
    );
  }
}
