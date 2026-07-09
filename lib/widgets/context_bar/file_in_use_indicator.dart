// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/context_state.dart';
import '../../core/ephe/active_file.dart';
import '../../core/ephe/types.dart';
import '../../layout/app_shell.dart';
import '../../layout/tab_definitions.dart';

/// Small badge next to the time-and-place section that shows which
/// ephemeris file the C library will actually read for the current JD
/// (planets family). If no installed file covers the JD, shows "Moshier"
/// to warn the user the app silently fell back to the analytical model.
///
/// Tap → opens the Ephemeris Manager screen.
class FileInUseIndicator extends ConsumerWidget {
  const FileInUseIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contextBarProvider);
    final theme = Theme.of(context);

    final (
      String text,
      Color bg,
      Color fg,
      String tooltip,
    ) = switch (ctx.epheSource) {
      EpheSource.moshier => (
        'Moshier',
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
        'Analytical Moshier model — no ephemeris file is read.',
      ),
      EpheSource.jpl => (
        ctx.jplFilename ?? 'JPL',
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
        ctx.jplFilename == null
            ? 'JPL mode selected but no JPL file chosen.'
            : 'JPL file for JD ${ctx.jdUt.toStringAsFixed(2)}: ${ctx.jplFilename}',
      ),
      EpheSource.swissEph => _swissEphBadge(ref, ctx.jdUt, theme),
    };

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          ref.read(selectedTabProvider.notifier).state =
              AppTab.ephemerisManager;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  (String, Color, Color, String) _swissEphBadge(
    WidgetRef ref,
    double jdUt,
    ThemeData theme,
  ) {
    final file = ref.watch(activeFileProvider(BodyFamily.planets));
    if (file == null) {
      return (
        'Moshier',
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
        'No Swiss Ephemeris file covers JD ${jdUt.toStringAsFixed(2)} — '
            'the analytical Moshier model will be used.',
      );
    }
    return (
      file.filename,
      theme.colorScheme.secondaryContainer,
      theme.colorScheme.onSecondaryContainer,
      'Planets file for JD ${jdUt.toStringAsFixed(2)}: '
          '${file.filename} (${file.startYear}–${file.endYear} CE)',
    );
  }
}
