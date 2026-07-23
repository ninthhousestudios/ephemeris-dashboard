// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/chart_io.dart';
import '../../core/context_provider.dart';
import '../../core/date_time_input.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../layout/responsive_layout.dart';
import '../chart_file_dialog.dart';
import 'ayanamsa_selector.dart';
import 'calendar_selector.dart';
import 'clock_selector.dart';
import 'context_date_field.dart';
import 'context_jd_field.dart';
import 'context_location_field.dart';
import 'context_time_field.dart';
import 'context_utc_field.dart';
import 'ephe_source_selector.dart';
import 'eq_ref_selector.dart';
import 'jpl_file_selector.dart';
import 'file_in_use_indicator.dart';
import 'origin_selector.dart';
import 'projection_selector.dart';
import 'zodiac_ref_selector.dart';

/// Persistent top bar with shared global calculation context.
///
/// Two-panel grid layout:
///   Left — Time & Place
///     Row 1: Date | Time | UTC | JD  [now]
///     Row 2: Lat  | Lon  | Alt | City
///   Right — Options (3-col grid via LabeledDropdown)
class ContextBar extends ConsumerStatefulWidget {
  const ContextBar({super.key});

  @override
  ConsumerState<ContextBar> createState() => _ContextBarState();
}

class _ContextBarState extends ConsumerState<ContextBar> {
  bool _mobileExpanded = true;

  static const _colGap = 12.0;
  static const _rowGap = 6.0;

  Future<void> _openChart() async {
    final useFilePicker =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        ResponsiveLayout.of(context) == ScreenSize.mobile;

    if (useFilePicker) {
      await _openChartWithPicker();
    } else {
      await _openChartWithDialog();
    }
  }

  Future<void> _openChartWithDialog() async {
    final path = await ChartFileDialog.show(context);
    if (path == null || !mounted) return;
    try {
      final chart = ChartIO.read(path);
      ref.read(contextBarProvider.notifier).loadFromChart(chart);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Loaded: ${chart.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading chart: $e')));
      }
    }
  }

  Future<void> _openChartWithPicker() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ChartIO.pickerExtensions,
        withData: true,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      ChartData chart;
      if (file.bytes != null) {
        chart = ChartIO.readBytes(file.bytes!, file.name);
      } else if (file.path != null) {
        chart = ChartIO.read(file.path!);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file data')),
        );
        return;
      }
      ref.read(contextBarProvider.notifier).loadFromChart(chart);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Loaded: ${chart.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading chart: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 1224;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: isMobile ? _buildMobileLayout() : _buildDesktopLayout(screenWidth),
    );
  }

  Widget _buildMobileLayout() {
    final theme = Theme.of(context);
    final ctx = ref.watch(contextBarProvider);
    final jdUtils = JdUtils(ref.read(sweProvider));
    final local = jdUtils.applyUtcOffset(ctx.dateTime, ctx.utcOffset);
    final summaryStyle = theme.textTheme.bodySmall;

    if (!_mobileExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _mobileExpanded = true),
                child: Row(
                  children: [
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${fmtDate(local)}  '
                        '${fmtTime(local)}  '
                        '${fmtOffset(ctx.utcOffset)}  '
                        '${fmtCoord(ctx.latitude)}, ${fmtCoord(ctx.longitude)}',
                        style: summaryStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final sectionLabel = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: collapse toggle + actions ──
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => _mobileExpanded = false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.expand_less,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text('TIME & PLACE', style: sectionLabel),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.folder_open, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Open chart file',
                onPressed: _openChart,
              ),
              const Spacer(),
              dateTimeIconButton(Icons.update, 'Set to now', () {
                ref.read(contextBarProvider.notifier).setNow();
              }),
            ],
          ),
          // ── Secondary: ephemeris badge ──
          const Row(children: [Flexible(child: FileInUseIndicator())]),
          const SizedBox(height: 4),
          // Date | Time
          const Row(
            children: [
              Expanded(child: ContextDateField()),
              SizedBox(width: 8),
              Expanded(child: ContextTimeField()),
            ],
          ),
          const SizedBox(height: 4),
          // UTC | JD
          const Row(
            children: [
              Expanded(child: ContextUtcField()),
              SizedBox(width: 8),
              Expanded(child: ContextJdField()),
            ],
          ),
          const SizedBox(height: 4),
          // Lat | Lon
          const Row(
            children: [
              Expanded(child: ContextLocationField(LocationFieldKind.latitude)),
              SizedBox(width: 8),
              Expanded(
                child: ContextLocationField(LocationFieldKind.longitude),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Alt | City
          const Row(
            children: [
              Expanded(child: ContextLocationField(LocationFieldKind.altitude)),
              SizedBox(width: 8),
              Expanded(child: ContextLocationField(LocationFieldKind.city)),
            ],
          ),
          const Divider(height: 12),
          // ── OPTIONS ──
          Text('OPTIONS', style: sectionLabel),
          const SizedBox(height: 4),
          const Row(
            children: [
              Expanded(child: OriginSelector()),
              SizedBox(width: 8),
              Expanded(child: ZodiacRefSelector()),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Expanded(child: EqRefSelector()),
              SizedBox(width: 8),
              Expanded(child: AyanamsaSelector()),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Expanded(child: ProjectionSelector()),
              SizedBox(width: 8),
              Expanded(child: EpheSourceSelector()),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Expanded(child: JplFileSelector()),
              SizedBox(width: 8),
              Expanded(child: CalendarSelector()),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Expanded(child: ClockSelector()),
              SizedBox(width: 8),
              Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(double screenWidth) {
    final sectionLabel = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    );
    final minBarWidth = 1000.0 * MediaQuery.textScalerOf(context).scale(1.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: minBarWidth.clamp(screenWidth - 32, double.infinity),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left: Time & Place ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('TIME & PLACE', style: sectionLabel),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.folder_open, size: 14),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                          tooltip: 'Open chart file',
                          onPressed: _openChart,
                        ),
                        const SizedBox(width: 4),
                        const Flexible(child: FileInUseIndicator()),
                        const SizedBox(width: 8),
                        dateTimeIconButton(Icons.update, 'Set to now', () {
                          ref.read(contextBarProvider.notifier).setNow();
                        }),
                      ],
                    ),
                    SizedBox(height: _rowGap),
                    // Row 1: Date | Time | UTC | JD
                    const Row(
                      children: [
                        Expanded(child: ContextDateField()),
                        SizedBox(width: _colGap),
                        Expanded(child: ContextTimeField(showNowButton: true)),
                        SizedBox(width: _colGap),
                        Expanded(child: ContextUtcField()),
                        SizedBox(width: _colGap),
                        Expanded(child: ContextJdField()),
                      ],
                    ),
                    SizedBox(height: _rowGap),
                    // Row 2: Lat | Lon | Alt | City
                    const Row(
                      children: [
                        Expanded(
                          child: ContextLocationField(
                            LocationFieldKind.latitude,
                          ),
                        ),
                        SizedBox(width: _colGap),
                        Expanded(
                          child: ContextLocationField(
                            LocationFieldKind.longitude,
                          ),
                        ),
                        SizedBox(width: _colGap),
                        Expanded(
                          child: ContextLocationField(
                            LocationFieldKind.altitude,
                          ),
                        ),
                        SizedBox(width: _colGap),
                        Expanded(
                          child: ContextLocationField(LocationFieldKind.city),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Divider ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
              ),
              // ── Right: Options ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('OPTIONS', style: sectionLabel),
                    SizedBox(height: _rowGap),
                    const Row(
                      children: [
                        Expanded(child: OriginSelector()),
                        SizedBox(width: _colGap),
                        Expanded(child: ZodiacRefSelector()),
                        SizedBox(width: _colGap),
                        Expanded(child: EqRefSelector()),
                      ],
                    ),
                    SizedBox(height: _rowGap),
                    const Row(
                      children: [
                        Expanded(child: AyanamsaSelector()),
                        SizedBox(width: _colGap),
                        Expanded(child: ProjectionSelector()),
                        SizedBox(width: _colGap),
                        Expanded(child: EpheSourceSelector()),
                      ],
                    ),
                    SizedBox(height: _rowGap),
                    const Row(
                      children: [
                        Expanded(child: JplFileSelector()),
                        SizedBox(width: _colGap),
                        Expanded(child: CalendarSelector()),
                        SizedBox(width: _colGap),
                        Expanded(child: ClockSelector()),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
