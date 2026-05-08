import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chart_formats/chart_io.dart';
import '../../chart_formats/model/chart_data.dart';
import '../../core/context_provider.dart';
import '../../core/ephemeris/emitter_provider.dart';
import '../chart_file_dialog.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../layout/responsive_layout.dart';
import 'origin_selector.dart';
import 'zodiac_ref_selector.dart';
import 'eq_ref_selector.dart';
import 'ayanamsa_selector.dart';
import 'ephe_source_selector.dart';
import 'file_in_use_indicator.dart';

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

  // Controllers and focus nodes for all text fields
  final _date = TextEditingController();
  final _time = TextEditingController();
  final _utc = TextEditingController();
  final _jd = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _alt = TextEditingController();
  final _city = TextEditingController();

  late final _dateFocus = _focusWithCommit(_commitDate);
  late final _timeFocus = _focusWithCommit(_commitTime);
  late final _utcFocus = _focusWithCommit(_commitUtc);
  late final _jdFocus = _focusWithCommit(_commitJd);
  late final _latFocus = _focusWithCommit(_commitLocation);
  late final _lonFocus = _focusWithCommit(_commitLocation);
  late final _altFocus = _focusWithCommit(_commitLocation);
  late final _cityFocus = _focusWithCommit(_commitLocation);

  /// Create a FocusNode that commits on focus loss.
  FocusNode _focusWithCommit(VoidCallback commit) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus) commit();
    });
    return node;
  }

  @override
  void dispose() {
    _date.dispose();
    _time.dispose();
    _utc.dispose();
    _jd.dispose();
    _lat.dispose();
    _lon.dispose();
    _alt.dispose();
    _city.dispose();
    _dateFocus.dispose();
    _timeFocus.dispose();
    _utcFocus.dispose();
    _jdFocus.dispose();
    _latFocus.dispose();
    _lonFocus.dispose();
    _altFocus.dispose();
    _cityFocus.dispose();
    super.dispose();
  }

  JdUtils get _jdUtils => JdUtils(ref.read(sweProvider));

  /// Sync controller text from state, but skip any field that has focus
  /// (the user is actively editing it).
  void _sync() {
    final ctx = ref.read(contextBarProvider);
    final local = _jdUtils.applyUtcOffset(ctx.dateTime, ctx.utcOffset);
    if (!_dateFocus.hasFocus) {
      _date.text = '${_p(local.year, 4)}-${_p(local.month, 2)}-${_p(local.day, 2)}';
    }
    if (!_timeFocus.hasFocus) {
      _time.text = '${_p(local.hour, 2)}:${_p(local.minute, 2)}:${_p(local.second, 2)}';
    }
    if (!_utcFocus.hasFocus) {
      _utc.text = _fmtOffset(ctx.utcOffset);
    }
    if (!_jdFocus.hasFocus) {
      _jd.text = ctx.jdUt.toStringAsFixed(6);
    }
    if (!_latFocus.hasFocus) {
      _lat.text = _fmtCoord(ctx.latitude);
    }
    if (!_lonFocus.hasFocus) {
      _lon.text = _fmtCoord(ctx.longitude);
    }
    if (!_altFocus.hasFocus) {
      _alt.text = ctx.altitude.round().toString();
    }
    if (!_cityFocus.hasFocus) {
      _city.text = ctx.cityLabel;
    }
  }

  String _p(int v, int w) => v.toString().padLeft(w, '0');

  String _fmtOffset(double offset) {
    final sign = offset >= 0 ? '+' : '-';
    final abs = offset.abs();
    final h = abs.truncate();
    final m = ((abs - h) * 60).round();
    return '$sign${_p(h, 2)}:${_p(m, 2)}';
  }

  /// Format a coordinate: show up to 4 decimals, but strip trailing zeros.
  /// 0.0 → "0", 51.5074 → "51.5074", 10.5000 → "10.5"
  String _fmtCoord(double v) {
    final s = v.toStringAsFixed(4);
    if (!s.contains('.')) return s;
    var trimmed = s.replaceAll(RegExp(r'0+$'), '');
    if (trimmed.endsWith('.')) trimmed = trimmed.substring(0, trimmed.length - 1);
    return trimmed;
  }

  void _commitDate() {
    final parts = _date.text.split('-');
    if (parts.length != 3) return;
    final y = int.tryParse(parts[0]);
    final mo = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || mo == null || d == null) return;
    final ctx = ref.read(contextBarProvider);
    final oldDt = ctx.dateTime;
    final newDt = DateTime.utc(y, mo, d, oldDt.hour, oldDt.minute, oldDt.second);
    final ut = _jdUtils.removeUtcOffset(newDt, ctx.utcOffset);
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setDateTime(ut);
  }

  void _commitTime() {
    final parts = _time.text.split(':');
    if (parts.length < 2) return;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final s = parts.length > 2 ? int.tryParse(parts[2]) : 0;
    if (h == null || m == null) return;
    final ctx = ref.read(contextBarProvider);
    final local = _jdUtils.applyUtcOffset(ctx.dateTime, ctx.utcOffset);
    final newLocal = DateTime.utc(local.year, local.month, local.day, h, m, s ?? 0);
    final ut = _jdUtils.removeUtcOffset(newLocal, ctx.utcOffset);
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setDateTime(ut);
  }

  void _commitUtc() {
    final text = _utc.text.trim();
    if (text.isEmpty) return;
    final sign = text.startsWith('-') ? -1.0 : 1.0;
    final stripped = text.replaceAll(RegExp(r'^[+-]'), '');
    final parts = stripped.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setUtcOffset(sign * (h + m / 60.0));
  }

  void _commitJd() {
    final jd = double.tryParse(_jd.text);
    if (jd == null) return;
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setJd(jd);
  }

  void _commitLocation() {
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setLocation(
      latitude: double.tryParse(_lat.text) ?? 0,
      longitude: double.tryParse(_lon.text) ?? 0,
      altitude: double.tryParse(_alt.text) ?? 0,
      cityLabel: _city.text,
    );
  }

  Future<void> _pickDate() async {
    final ctx = ref.read(contextBarProvider);
    final local = _jdUtils.applyUtcOffset(ctx.dateTime, ctx.utcOffset);
    final picked = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(-4000),
      lastDate: DateTime(4000),
    );
    if (picked == null) return;
    final newLocal = DateTime.utc(
      picked.year, picked.month, picked.day,
      local.hour, local.minute, local.second,
    );
    ref.read(contextBarProvider.notifier)
        .setDateTime(_jdUtils.removeUtcOffset(newLocal, ctx.utcOffset));
  }

  Future<void> _pickTime() async {
    final ctx = ref.read(contextBarProvider);
    final local = _jdUtils.applyUtcOffset(ctx.dateTime, ctx.utcOffset);
    final picked = await _showPreciseTimePicker(
      context: context,
      initialHour: local.hour,
      initialMinute: local.minute,
      initialSecond: local.second,
    );
    if (picked == null) return;
    final newLocal = DateTime.utc(
      local.year, local.month, local.day,
      picked.$1, picked.$2, picked.$3,
    );
    ref.read(contextBarProvider.notifier)
        .setDateTime(_jdUtils.removeUtcOffset(newLocal, ctx.utcOffset));
  }

  /// Time picker dialog with hour, minute, and second spinners.
  static Future<(int, int, int)?> _showPreciseTimePicker({
    required BuildContext context,
    required int initialHour,
    required int initialMinute,
    required int initialSecond,
  }) {
    var h = initialHour;
    var m = initialMinute;
    var s = initialSecond;
    final hCtrl = TextEditingController(text: h.toString().padLeft(2, '0'));
    final mCtrl = TextEditingController(text: m.toString().padLeft(2, '0'));
    final sCtrl = TextEditingController(text: s.toString().padLeft(2, '0'));
    return showDialog<(int, int, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final spinnerStyle = Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontFamily: 'monospace');

          void updateCtrl(TextEditingController ctrl, int value) {
            final text = value.toString().padLeft(2, '0');
            if (ctrl.text != text) {
              ctrl.text = text;
              ctrl.selection = TextSelection.collapsed(offset: text.length);
            }
          }
          updateCtrl(hCtrl, h);
          updateCtrl(mCtrl, m);
          updateCtrl(sCtrl, s);

          Widget spinner(String label, int value, int max, ValueChanged<int> onChanged, TextEditingController ctrl) {
            return IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: Theme.of(ctx).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_up),
                    onPressed: () => setState(() => onChanged((value + 1) % (max + 1))),
                  ),
                  TextField(
                    controller: ctrl,
                    textAlign: TextAlign.center,
                    style: spinnerStyle,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    onChanged: (text) {
                      final v = int.tryParse(text);
                      if (v != null && v >= 0 && v <= max) {
                        onChanged(v);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_down),
                    onPressed: () => setState(() => onChanged((value - 1 + max + 1) % (max + 1))),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            title: const Text('Set Time'),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                spinner('Hour', h, 23, (v) => h = v, hCtrl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':', style: spinnerStyle),
                ),
                spinner('Min', m, 59, (v) => m = v, mCtrl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':', style: spinnerStyle),
                ),
                spinner('Sec', s, 59, (v) => s = v, sCtrl),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop((h, m, s)),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Half-hour UTC offset options from -12:00 to +12:00.
  static final _utcOffsets = [
    for (int h = -12; h <= 12; h++)
      for (final m in [0, 30])
        if (h != 12 || m == 0) h + m / 60.0,
  ];

  String _offsetLabel(double offset) => _fmtOffset(offset);

  /// Combo field: editable text + dropdown of half-hour offsets.
  Widget _utcOffsetField() {
    return Row(
      children: [
        Text('UTC Offset ', style: _labelStyle),
        Expanded(
          child: TextField(
            controller: _utc,
            focusNode: _utcFocus,
            style: _fieldStyle,
            decoration: _deco('+00:00'),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d:+-]'))],
            onSubmitted: (_) => _commitUtc(),
            onEditingComplete: _commitUtc,
          ),
        ),
        PopupMenuButton<double>(
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: 'Select UTC offset',
          itemBuilder: (_) => _utcOffsets.map((o) => PopupMenuItem(
                value: o,
                height: 32,
                child: Text(_offsetLabel(o), style: _fieldStyle),
              )).toList(),
          onSelected: (offset) {
            ref.read(contextBarProvider.notifier).setUtcOffset(offset);
          },
        ),
      ],
    );
  }

  // --- Build helpers ---

  static const _colGap = 12.0;
  static const _rowGap = 6.0;

  TextStyle? get _labelStyle => Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );

  TextStyle? get _fieldStyle {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return isMobile
        ? Theme.of(context).textTheme.bodyMedium
        : Theme.of(context).textTheme.bodySmall;
  }

  InputDecoration _deco(String hint) => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        hintText: hint,
        border: const OutlineInputBorder(),
      );

  /// A labeled text field: [64px label] [expanding field] [optional icon]
  Widget _labeled(
    String label,
    TextEditingController controller,
    FocusNode focusNode, {
    required String hint,
    required VoidCallback onCommit,
    List<TextInputFormatter>? formatters,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Text('$label ', style: _labelStyle),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: _fieldStyle,
            decoration: _deco(hint),
            inputFormatters: formatters,
            onSubmitted: (_) => onCommit(),
            onEditingComplete: onCommit,
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 14),
      padding: const EdgeInsets.only(left: 4),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  /// Track whether the last provider change came from our own commit methods
  /// so we can skip syncing (the controllers already have the right text).
  bool _selfUpdate = false;

  Future<void> _openChart() async {
    final useFilePicker = kIsWeb || ResponsiveLayout.of(context) == ScreenSize.mobile;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded: ${chart.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chart: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded: ${chart.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chart: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(contextBarProvider, (_, _) {
      if (_selfUpdate) {
        _selfUpdate = false;
        return;
      }
      _sync();
    });
    // Initial sync on first build.
    if (_date.text.isEmpty) _sync();

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
    final local = _jdUtils.applyUtcOffset(ctx.dateTime, ctx.utcOffset);
    final summaryStyle = theme.textTheme.bodySmall;

    if (!_mobileExpanded) {
      // ── Collapsed: single-line summary ──
      return InkWell(
        onTap: () => setState(() => _mobileExpanded = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.expand_more, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_p(local.year, 4)}-${_p(local.month, 2)}-${_p(local.day, 2)}  '
                  '${_p(local.hour, 2)}:${_p(local.minute, 2)}:${_p(local.second, 2)}  '
                  '${_fmtOffset(ctx.utcOffset)}  '
                  '${_fmtCoord(ctx.latitude)}, ${_fmtCoord(ctx.longitude)}',
                  style: summaryStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Expanded: full editing layout ──
    final numFmt = FilteringTextInputFormatter.allow(RegExp(r'[\d.+-]'));
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
          // ── Header with collapse toggle ──
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => _mobileExpanded = false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.expand_less, size: 18, color: theme.colorScheme.onSurfaceVariant),
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
              const SizedBox(width: 4),
              Consumer(builder: (context, ref, _) {
                final emitter = ref.watch(selectedEmitterProvider);
                return PopupMenuButton<CodeEmitter>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minHeight: 24),
                  tooltip: 'Code language',
                  onSelected: (e) =>
                      ref.read(selectedEmitterProvider.notifier).state = e,
                  itemBuilder: (_) => availableEmitters
                      .map((e) => PopupMenuItem(
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
                          ))
                      .toList(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.code, size: 14),
                        const SizedBox(width: 4),
                        Text(emitter.displayName,
                            style: Theme.of(context).textTheme.labelSmall),
                        const Icon(Icons.arrow_drop_down, size: 14),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              const Flexible(child: FileInUseIndicator()),
              const Spacer(),
              _iconBtn(Icons.update, 'Set to now', () {
                ref.read(contextBarProvider.notifier).setNow();
              }),
            ],
          ),
          const SizedBox(height: 4),
          // Date | Time
          Row(
            children: [
              Expanded(
                child: _labeled('Date', _date, _dateFocus,
                    hint: 'YYYY-MM-DD',
                    onCommit: _commitDate,
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]'))],
                    trailing: _iconBtn(Icons.calendar_today, 'Pick date', _pickDate)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _labeled('Time', _time, _timeFocus,
                    hint: 'HH:MM:SS',
                    onCommit: _commitTime,
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d:]'))],
                    trailing: _iconBtn(Icons.access_time, 'Pick time', _pickTime)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // UTC | JD
          Row(
            children: [
              Expanded(child: _utcOffsetField()),
              const SizedBox(width: 8),
              Expanded(
                child: _labeled('JD (UT)', _jd, _jdFocus,
                    hint: '2460000.0',
                    onCommit: _commitJd,
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Lat | Lon
          Row(
            children: [
              Expanded(
                child: _labeled('Lat', _lat, _latFocus,
                    hint: '0', onCommit: _commitLocation, formatters: [numFmt]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _labeled('Lon', _lon, _lonFocus,
                    hint: '0', onCommit: _commitLocation, formatters: [numFmt]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Alt | City
          Row(
            children: [
              Expanded(
                child: _labeled('Alt', _alt, _altFocus,
                    hint: '0', onCommit: _commitLocation, formatters: [numFmt]),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _labeled('City', _city, _cityFocus,
                    hint: 'City', onCommit: _commitLocation),
              ),
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
              Expanded(child: EpheSourceSelector()),
              SizedBox(width: 8),
              Expanded(child: SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(double screenWidth) {
    final numFmt = FilteringTextInputFormatter.allow(RegExp(r'[\d.+-]'));
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
                              minWidth: 24, minHeight: 24),
                          tooltip: 'Open chart file',
                          onPressed: _openChart,
                        ),
                        const SizedBox(width: 4),
                        Consumer(builder: (context, ref, _) {
                          final emitter = ref.watch(selectedEmitterProvider);
                          return PopupMenuButton<CodeEmitter>(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minHeight: 24),
                            tooltip: 'Code language',
                            onSelected: (e) =>
                                ref.read(selectedEmitterProvider.notifier).state = e,
                            itemBuilder: (_) => availableEmitters
                                .map((e) => PopupMenuItem(
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
                                    ))
                                .toList(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.code, size: 14),
                                  const SizedBox(width: 4),
                                  Text(emitter.displayName,
                                      style: Theme.of(context).textTheme.labelSmall),
                                  const Icon(Icons.arrow_drop_down, size: 14),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(width: 8),
                        const Flexible(child: FileInUseIndicator()),
                      ],
                    ),
                    SizedBox(height: _rowGap),
                    // Row 1: Date | Time | UTC | JD [now]
                    Row(
                      children: [
                        Expanded(
                          child: _labeled('Date', _date, _dateFocus,
                              hint: 'YYYY-MM-DD',
                              onCommit: _commitDate,
                              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]'))],
                              trailing: _iconBtn(Icons.calendar_today, 'Pick date', _pickDate)),
                        ),
                        SizedBox(width: _colGap),
                        Expanded(
                          child: _labeled('Time', _time, _timeFocus,
                              hint: 'HH:MM:SS',
                              onCommit: _commitTime,
                              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d:]'))],
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _iconBtn(Icons.update, 'Set to now', () {
                                    ref.read(contextBarProvider.notifier).setNow();
                                  }),
                                  _iconBtn(Icons.access_time, 'Pick time', _pickTime),
                                ],
                              )),
                        ),
                        SizedBox(width: _colGap),
                        Expanded(
                          child: _utcOffsetField(),
                        ),
                        SizedBox(width: _colGap),
                        Expanded(
                          child: _labeled('JD (UT)', _jd, _jdFocus,
                              hint: '2460000.0',
                              onCommit: _commitJd,
                              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
                        ),
                      ],
                    ),
                    SizedBox(height: _rowGap),
                    // Row 2: Lat | Lon | Alt | City
                    Row(
                      children: [
                        Expanded(
                          child: _labeled('Lat', _lat, _latFocus,
                              hint: '0', onCommit: _commitLocation, formatters: [numFmt]),
                        ),
                        SizedBox(width: _colGap),
                        Expanded(
                          child: _labeled('Lon', _lon, _lonFocus,
                              hint: '0', onCommit: _commitLocation, formatters: [numFmt]),
                        ),
                        SizedBox(width: _colGap),
                        Expanded(
                          child: _labeled('Alt', _alt, _altFocus,
                              hint: '0', onCommit: _commitLocation, formatters: [numFmt]),
                        ),
                        SizedBox(width: _colGap),
                        Expanded(
                          child: _labeled('City', _city, _cityFocus,
                              hint: 'City', onCommit: _commitLocation),
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
                    // Row 1: Origin | Zodiac | Eq. Ref
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
                    // Row 2: Ayanamsa | Ephe | (empty)
                    const Row(
                      children: [
                        Expanded(child: AyanamsaSelector()),
                        SizedBox(width: _colGap),
                        Expanded(child: EpheSourceSelector()),
                        SizedBox(width: _colGap),
                        Expanded(child: SizedBox.shrink()),
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
