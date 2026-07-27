// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class ConfigTab extends ConsumerWidget {
  const ConfigTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── About card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Ephemeris Dashboard is a Flutter GUI for the Swiss Ephemeris. '
                    'It provides pure astronomical calculations with no '
                    'interpretation.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All calculations use the Swiss Ephemeris via the '
                    'swisseph_rs Dart/Rust package.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── License card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('License', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Copyright \u00a9 2026 Ninth House Studios',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ephemeris Dashboard is free software licensed under the '
                    'GNU Affero General Public License v3.0 (AGPL-3.0).',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This program is free software: you can redistribute it '
                    'and/or modify it under the terms of the GNU Affero '
                    'General Public License as published by the Free Software '
                    'Foundation, either version 3 of the License, or (at your '
                    'option) any later version.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This program is distributed in the hope that it will be '
                    'useful, but WITHOUT ANY WARRANTY; without even the '
                    'implied warranty of MERCHANTABILITY or FITNESS FOR A '
                    'PARTICULAR PURPOSE. See the GNU Affero General Public '
                    'License for more details.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If you interact with this software over a network, '
                    'you are entitled to receive the complete source code. '
                    'See the Source Code section below.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(
                    'The Swiss Ephemeris C library is '
                    'Copyright \u00a9 1997\u20132021 Astrodienst AG, '
                    'licensed under AGPL-3.0.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Bugs and Feature Requests card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bugs and Feature Requests',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Found something wrong, or want a calculation the app '
                    'does not do yet? Get in touch — by email, or by '
                    'filing an issue on GitHub.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _launchRow(
                    theme,
                    Icons.mail_outline,
                    'Email',
                    'josh@ninthhouse.studio',
                    'mailto:josh@ninthhouse.studio',
                  ),
                  const SizedBox(height: 8),
                  _launchRow(
                    theme,
                    Icons.bug_report_outlined,
                    'File an issue on GitHub',
                    'https://github.com/ninthhousestudios/swe-dashboard/issues',
                    'https://github.com/ninthhousestudios/swe-dashboard/issues',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Source Code card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Source Code', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'The complete source code for this application and its '
                    'dependencies is available at:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _repoLink(
                    theme,
                    'Ephemeris Dashboard',
                    'https://github.com/ninthhousestudios/swe-dashboard',
                  ),
                  const SizedBox(height: 8),
                  _repoLink(
                    theme,
                    'swisseph_rs.dart (Dart bindings)',
                    'https://github.com/ninthhousestudios/swisseph_rs.dart',
                  ),
                  const SizedBox(height: 8),
                  _repoLink(
                    theme,
                    'swisseph-rs (Rust engine)',
                    'https://github.com/ninthhousestudios/swisseph-rs',
                  ),
                  const SizedBox(height: 8),
                  _repoLink(
                    theme,
                    'Swiss Ephemeris (original C library)',
                    'https://github.com/aloistr/swisseph',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Library info card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Swiss Ephemeris Library',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _infoRow(theme, 'Engine (Rust)', '0.1.8'),
                  const SizedBox(height: 4),
                  _infoRow(theme, 'Dart Package', '0.2.9'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── v2 release notes ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New in v2', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _bullet(
                    theme,
                    'No Calculate button. Results are now live: change the '
                    'moment, the place, or any flag and every figure on '
                    'screen recomputes immediately.',
                  ),
                  _bullet(
                    theme,
                    'Series. Repeat any calculation over a stepped range of '
                    'moments — seconds through years — and read it as a grid '
                    'or a table, or export it. Monthly and yearly steps walk '
                    'the civil calendar, so a series holds its date instead '
                    'of drifting off it.',
                  ),
                  _bullet(
                    theme,
                    'Ephemeris file manager. Browse, download, and manage '
                    'Swiss Ephemeris data files (.se1) for extended date '
                    'ranges and precision, and see which file a result '
                    'actually came from.',
                  ),
                  _bullet(
                    theme,
                    'Far more calculations. The tab set now covers eclipses, '
                    'rise and set, heliacal events, planetary phenomena, '
                    'nodes and apsides, planetocentric and differential '
                    'positions, crossings, fixed stars, coordinate '
                    'transforms, and date and time conversions.',
                  ),
                  _bullet(
                    theme,
                    'A richer context. Sidereal and tropical zodiacs with '
                    'user-defined ayanamsas, geocentric, topocentric, '
                    'heliocentric, and barycentric origins, house systems, '
                    'calendars, time scales, and projections — with the '
                    'flags they imply locked and managed for you.',
                  ),
                  _bullet(
                    theme,
                    'Chart import. Open a chart from Kala, Jagannatha Hora, '
                    'Astrolog, Solar Fire, AAF, or a plain JSON, CSV, or '
                    'TOML file, and the date, time, and place load straight '
                    'into the context.',
                  ),
                  _bullet(theme, 'Export. Copy or save results from any tab.'),
                  _bullet(
                    theme,
                    'Display. Light and dark themes, per-body selection, '
                    'configurable coordinate formatting, and a layout that '
                    'stays usable at any zoom level.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A bullet for the release-notes list. The marker is a plain `Text` in a
  /// `Row` rather than an indented `SizedBox` so it reflows with the text at
  /// any zoom level.
  Widget _bullet(ThemeData theme, String text) {
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: style),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }

  Widget _repoLink(ThemeData theme, String label, String url) =>
      _launchRow(theme, Icons.open_in_new, label, url, url);

  Widget _launchRow(
    ThemeData theme,
    IconData icon,
    String label,
    String subtitle,
    String url,
  ) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
