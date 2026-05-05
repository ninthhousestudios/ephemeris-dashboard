import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swisseph/swisseph.dart';

import '../../core/calc_session.dart';
import '../../core/context_provider.dart';
import '../../core/display_format.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';
import '../../widgets/export_button.dart';
import '../../widgets/result_card.dart';
import '../../tabs/planets/planets_provider.dart' show defaultBodies, extraBodies, uranianBodies, namedAsteroids, asteroidOffset;
import 'differential_provider.dart';

class DifferentialTab extends ConsumerStatefulWidget {
  const DifferentialTab({super.key});

  @override
  ConsumerState<DifferentialTab> createState() => _DifferentialTabState();
}

class _DifferentialTabState extends ConsumerState<DifferentialTab> {
  bool _showExtraBodies = false;
  bool _showAsteroids = false;
  bool _isCustomTime = false;
  final _asteroidCtrlA = TextEditingController();
  final _asteroidCtrlB = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _jdCtrl = TextEditingController();

  @override
  void dispose() {
    _asteroidCtrlA.dispose();
    _asteroidCtrlB.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _jdCtrl.dispose();
    super.dispose();
  }

  JdUtils get _jdUtils => JdUtils(ref.read(sweProvider));

  bool get _hasCalculated =>
      ref.watch(calcSessionProvider.select((s) => s.tabHasRun('differential')));

  // ── Date/time helpers (same pattern as DatesTab) ──

  static String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

  void _syncTimeFromContext() {
    final ctx = ref.read(contextBarProvider);
    final dt = _jdUtils.jdToDateTime(ctx.jdUt);
    _dateCtrl.text = _fmtDate(dt);
    _timeCtrl.text = _fmtTime(dt);
    _jdCtrl.text = ctx.jdUt.toStringAsFixed(8);
  }

  double? _parseDateTime() {
    try {
      final parts = _dateCtrl.text.split('-');
      if (parts.length != 3) return null;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final tParts = _timeCtrl.text.split(':');
      final hour = tParts.isNotEmpty ? int.tryParse(tParts[0]) ?? 0 : 0;
      final min = tParts.length > 1 ? int.tryParse(tParts[1]) ?? 0 : 0;
      final sec = tParts.length > 2 ? int.tryParse(tParts[2]) ?? 0 : 0;
      return _jdUtils.dateTimeToJd(DateTime.utc(year, month, day, hour, min, sec));
    } catch (_) {
      return null;
    }
  }

  void _syncJdFromDateTimeFields() {
    final jd = _parseDateTime();
    if (jd != null) _jdCtrl.text = jd.toStringAsFixed(8);
  }

  void _setNow() {
    final now = DateTime.now().toUtc();
    _dateCtrl.text = _fmtDate(now);
    _timeCtrl.text = _fmtTime(now);
    _jdCtrl.text = _jdUtils.dateTimeToJd(now).toStringAsFixed(8);
    setState(() => _isCustomTime = true);
  }

  void _resetToContext() {
    setState(() {
      _isCustomTime = false;
      _syncTimeFromContext();
    });
    ref.read(diffOverrideJdProvider.notifier).state = null;
  }

  void _commitTimeOverride() {
    final jd = double.tryParse(_jdCtrl.text) ?? _parseDateTime();
    if (jd != null) {
      ref.read(diffOverrideJdProvider.notifier).state = jd;
    }
  }

  Future<void> _pickDate() async {
    DateTime? current;
    try {
      final parts = _dateCtrl.text.split('-');
      current = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {}
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(-4000),
      lastDate: DateTime(4000),
    );
    if (picked == null) return;
    _dateCtrl.text = _fmtDate(picked);
    _syncJdFromDateTimeFields();
    setState(() => _isCustomTime = true);
    _commitTimeOverride();
  }

  Future<void> _pickTime() async {
    final parts = _timeCtrl.text.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    final picked = await _showPreciseTimePicker(
      context: context, initialHour: h, initialMinute: m, initialSecond: s,
    );
    if (picked == null) return;
    _timeCtrl.text =
        '${picked.$1.toString().padLeft(2, '0')}:${picked.$2.toString().padLeft(2, '0')}:${picked.$3.toString().padLeft(2, '0')}';
    _syncJdFromDateTimeFields();
    setState(() => _isCustomTime = true);
    _commitTimeOverride();
  }

  // ── Body selection ──

  void _setBodyA(int body) => ref.read(diffBodyAProvider.notifier).state = body;
  void _setBodyB(int body) => ref.read(diffBodyBProvider.notifier).state = body;

  void _addAsteroidA() {
    final n = int.tryParse(_asteroidCtrlA.text.trim());
    if (n != null && n > 0) {
      _setBodyA(asteroidOffset + n);
      _asteroidCtrlA.clear();
    }
  }

  void _addAsteroidB() {
    final n = int.tryParse(_asteroidCtrlB.text.trim());
    if (n != null && n > 0) {
      _setBodyB(asteroidOffset + n);
      _asteroidCtrlB.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync time fields from context when not custom
    if (!_isCustomTime) {
      final ctx = ref.watch(contextBarProvider);
      final dt = _jdUtils.jdToDateTime(ctx.jdUt);
      final dateStr = _fmtDate(dt);
      final timeStr = _fmtTime(dt);
      final jdStr = ctx.jdUt.toStringAsFixed(8);
      if (_dateCtrl.text != dateStr) _dateCtrl.text = dateStr;
      if (_timeCtrl.text != timeStr) _timeCtrl.text = timeStr;
      if (_jdCtrl.text != jdStr) _jdCtrl.text = jdStr;
    }

    final bodyA = ref.watch(diffBodyAProvider);
    final bodyB = ref.watch(diffBodyBProvider);
    final fmt = ref.watch(diffFormatProvider);
    final jd = ref.watch(contextBarProvider).jdUt;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Date/Time input row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text('Date ', style: labelStyle),
              Expanded(
                child: TextField(
                  controller: _dateCtrl,
                  style: theme.textTheme.bodySmall,
                  decoration: _deco('YYYY-MM-DD'),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]'))],
                  onChanged: (_) {
                    setState(() => _isCustomTime = true);
                    _syncJdFromDateTimeFields();
                    _commitTimeOverride();
                  },
                ),
              ),
              _iconBtn(Icons.calendar_today, 'Pick date', _pickDate),
              const SizedBox(width: 12),
              Text('Time (UT) ', style: labelStyle),
              Expanded(
                child: TextField(
                  controller: _timeCtrl,
                  style: theme.textTheme.bodySmall,
                  decoration: _deco('HH:MM:SS'),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d:]'))],
                  onChanged: (_) {
                    setState(() => _isCustomTime = true);
                    _syncJdFromDateTimeFields();
                    _commitTimeOverride();
                  },
                ),
              ),
              _iconBtn(Icons.access_time, 'Pick time', _pickTime),
              const SizedBox(width: 12),
              Text('JD ', style: labelStyle),
              Expanded(
                child: TextField(
                  controller: _jdCtrl,
                  style: theme.textTheme.bodySmall,
                  decoration: _deco('2460000.0'),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  onChanged: (_) {
                    setState(() => _isCustomTime = true);
                    _commitTimeOverride();
                  },
                ),
              ),
              if (_isCustomTime) ...[
                const SizedBox(width: 4),
                _iconBtn(Icons.sync, 'Reset to context', _resetToContext),
              ],
              _iconBtn(Icons.update, 'Now', _setNow),
            ],
          ),
        ),
        // ── Body A chip row ──
        _buildBodyRow('Body A', bodyA, _setBodyA, _asteroidCtrlA, _addAsteroidA, theme),
        // ── Body B chip row ──
        _buildBodyRow('Body B', bodyB, _setBodyB, _asteroidCtrlB, _addAsteroidB, theme),
        // ── Progressive disclosure ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _showExtraBodies = !_showExtraBodies),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showExtraBodies ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text('More bodies', style: labelStyle),
                  ],
                ),
              ),
              if (_showExtraBodies) ...[
                const SizedBox(height: 4),
                _buildExtraSection(bodyA, bodyB, theme),
              ],
            ],
          ),
        ),
        // ── Format + export row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SegmentedButton<DisplayFormat>(
                  segments: DisplayFormat.values
                      .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                      .toList(),
                  selected: {fmt},
                  onSelectionChanged: (s) =>
                      ref.read(diffFormatProvider.notifier).state = s.first,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
                const SizedBox(width: 8),
                ExportButton(
                  hasResults: _hasCalculated,
                  getRows: () {
                    final result = ref.read(diffResultProvider);
                    if (result == null) return [];
                    return diffToExportRows(result, ref.read(diffFormatProvider));
                  },
                  filenameStem: 'swe_differential_${jd.toStringAsFixed(4)}',
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Results ──
        Expanded(
          child: _hasCalculated ? _DiffResults() : const _Placeholder(),
        ),
      ],
    );
  }

  /// Builds a single-select chip row for Body A or Body B (default bodies only).
  Widget _buildBodyRow(
    String label,
    int selected,
    ValueChanged<int> onSelect,
    TextEditingController asteroidCtrl,
    VoidCallback onAddAsteroid,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text('$label ', style: theme.textTheme.labelLarge),
            const SizedBox(width: 4),
            ...defaultBodies.map((body) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text(_bodyLabel(body)),
                    selected: selected == body,
                    onSelected: (_) => onSelect(body),
                    visualDensity: VisualDensity.compact,
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// Builds the progressive disclosure extra bodies section.
  Widget _buildExtraSection(int bodyA, int bodyB, ThemeData theme) {
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Extra bodies — two rows (A and B select)
        Text('Extra — click for A, long-press for B', style: labelStyle),
        const SizedBox(height: 2),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: extraBodies.map((body) => _dualSelectChip(body, bodyA, bodyB, theme)).toList(),
        ),
        const SizedBox(height: 4),
        Text('Uranian', style: labelStyle),
        const SizedBox(height: 2),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: uranianBodies.map((body) => _dualSelectChip(body, bodyA, bodyB, theme)).toList(),
        ),
        const SizedBox(height: 4),
        // Asteroids disclosure
        InkWell(
          onTap: () => setState(() => _showAsteroids = !_showAsteroids),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showAsteroids ? Icons.expand_less : Icons.expand_more,
                size: 18, color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text('Asteroids (by MPC number)', style: labelStyle),
            ],
          ),
        ),
        if (_showAsteroids) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: namedAsteroids.entries.map((e) {
              final bodyId = asteroidOffset + e.key;
              return _dualSelectChip(bodyId, bodyA, bodyB, theme, label: e.value);
            }).toList(),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('A: ', style: labelStyle),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _asteroidCtrlA,
                  decoration: const InputDecoration(
                    hintText: 'MPC #',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _addAsteroidA(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Set Body A to asteroid',
                onPressed: _addAsteroidA,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 12),
              Text('B: ', style: labelStyle),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _asteroidCtrlB,
                  decoration: const InputDecoration(
                    hintText: 'MPC #',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _addAsteroidB(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Set Body B to asteroid',
                onPressed: _addAsteroidB,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// A chip that sets Body A on tap, Body B on long-press.
  /// Highlighted if it matches either selection.
  Widget _dualSelectChip(int body, int bodyA, int bodyB, ThemeData theme, {String? label}) {
    final isA = body == bodyA;
    final isB = body == bodyB;
    final chipLabel = label ?? _bodyLabel(body);

    return GestureDetector(
      onLongPress: () => _setBodyB(body),
      child: ChoiceChip(
        label: Text(
          isA && isB
              ? '$chipLabel (A+B)'
              : isA
                  ? '$chipLabel (A)'
                  : isB
                      ? '$chipLabel (B)'
                      : chipLabel,
        ),
        selected: isA || isB,
        selectedColor: isA && isB
            ? theme.colorScheme.tertiary.withValues(alpha: 0.3)
            : isA
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : theme.colorScheme.secondary.withValues(alpha: 0.2),
        onSelected: (_) => _setBodyA(body),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  static InputDecoration _deco(String hint) => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        hintText: hint,
        border: const OutlineInputBorder(),
      );

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 14),
      padding: const EdgeInsets.only(left: 4),
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  /// Precise time picker dialog with hour/minute/second spinners.
  static Future<(int, int, int)?> _showPreciseTimePicker({
    required BuildContext context,
    required int initialHour,
    required int initialMinute,
    required int initialSecond,
  }) {
    var h = initialHour;
    var m = initialMinute;
    var s = initialSecond;
    return showDialog<(int, int, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final spinnerStyle = Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontFamily: 'monospace');
          final colonStyle = Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontFamily: 'monospace');

          Widget spinner(String label, int value, int max, ValueChanged<int> onChanged) {
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
                    controller: TextEditingController(text: value.toString().padLeft(2, '0')),
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
                      if (v != null && v >= 0 && v <= max) onChanged(v);
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
                spinner('Hour', h, 23, (v) => h = v),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(':', style: colonStyle)),
                spinner('Min', m, 59, (v) => m = v),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(':', style: colonStyle)),
                spinner('Sec', s, 59, (v) => s = v),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop((h, m, s)), child: const Text('OK')),
            ],
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Select two bodies and press Calculate'),
    );
  }
}

class _DiffResults extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(diffResultProvider);
    final fmt = ref.watch(diffFormatProvider);

    if (result == null) {
      return const Center(child: Text('Calculation failed — check body selection'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: ResultCard(
        title: '${result.nameA} — ${result.nameB}',
        subtitle: 'Differential',
        flagHex: '0x${result.returnFlagA.toRadixString(16).toUpperCase()} / '
            '0x${result.returnFlagB.toRadixString(16).toUpperCase()}',
        fields: [
          ResultField(label: 'Lon ${result.nameA}', value: formatAngle(result.lonA, fmt), rawValue: result.lonA),
          ResultField(label: 'Lon ${result.nameB}', value: formatAngle(result.lonB, fmt), rawValue: result.lonB),
          ResultField(label: 'Difference', value: formatAngle(result.difference, fmt), rawValue: result.difference),
          ResultField(label: 'Complement', value: formatAngle(result.complement, fmt), rawValue: result.complement),
          ResultField(label: 'Midpoint', value: formatAngle(result.midpoint, fmt), rawValue: result.midpoint),
        ],
      ),
    );
  }
}

/// Short label for a body constant.
String _bodyLabel(int body) {
  const names = {
    seSun: 'Sun', seMoon: 'Moon', seMercury: 'Mercury', seVenus: 'Venus',
    seMars: 'Mars', seJupiter: 'Jupiter', seSaturn: 'Saturn',
    seUranus: 'Uranus', seNeptune: 'Neptune', sePluto: 'Pluto',
    seMeanNode: 'M.Node', seTrueNode: 'T.Node',
    seMeanApog: 'M.Lilith', seOscuApog: 'O.Lilith',
    seEarth: 'Earth', seChiron: 'Chiron', sePholus: 'Pholus',
    seCeres: 'Ceres', sePallas: 'Pallas', seJuno: 'Juno', seVesta: 'Vesta',
    seIntpApog: 'I.Apogee', seIntpPerg: 'I.Perigee',
    seCupido: 'Cupido', seHades: 'Hades', seZeus: 'Zeus', seKronos: 'Kronos',
    seApollon: 'Apollon', seAdmetos: 'Admetos', seVulkanus: 'Vulkanus', sePoseidon: 'Poseidon',
  };
  if (names.containsKey(body)) return names[body]!;
  if (body >= seAstOffset) return '#${body - seAstOffset}';
  return 'Body $body';
}
