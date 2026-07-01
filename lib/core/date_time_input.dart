import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String fmtDate(DateTime dt) {
  final sign = dt.year < 0 ? '-' : '';
  final year = dt.year.abs().toString().padLeft(4, '0');
  return '$sign$year-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String fmtTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

String fmtHms(int h, int m, int s) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

({int year, int month, int day})? parseDateFields(String text) {
  final negative = text.startsWith('-');
  final parts = (negative ? text.substring(1) : text).split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final mo = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || mo == null || d == null) return null;
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final year = negative ? -y : y;
  final check = DateTime.utc(year, mo, d);
  if (check.year != year || check.month != mo || check.day != d) return null;
  return (year: year, month: mo, day: d);
}

({int hour, int minute, int second})? parseTimeFields(String text) {
  final parts = text.split(':');
  if (parts.isEmpty) return null;
  final h = int.tryParse(parts[0]);
  if (h == null || h < 0 || h > 23) return null;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  if (m < 0 || m > 59) return null;
  final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  if (s < 0 || s > 59) return null;
  return (hour: h, minute: m, second: s);
}

InputDecoration dateTimeInputDecoration(String hint) => InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  hintText: hint,
  border: const OutlineInputBorder(),
);

Widget dateTimeIconButton(
  IconData icon,
  String tooltip,
  VoidCallback onPressed,
) {
  return IconButton(
    icon: Icon(icon, size: 14),
    padding: const EdgeInsets.only(left: 4),
    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

String fmtOffset(double offset) {
  final sign = offset >= 0 ? '+' : '-';
  final abs = offset.abs();
  final h = abs.truncate();
  final m = ((abs - h) * 60).round();
  return '$sign${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String fmtCoord(double v) {
  final s = v.toStringAsFixed(4);
  if (!s.contains('.')) return s;
  var trimmed = s.replaceAll(RegExp(r'0+$'), '');
  if (trimmed.endsWith('.')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

Widget labeledField({
  required BuildContext context,
  required String label,
  required TextEditingController controller,
  required FocusNode focusNode,
  required String hint,
  required VoidCallback onCommit,
  List<TextInputFormatter>? formatters,
  Widget? trailing,
}) {
  final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
  final isMobile = MediaQuery.sizeOf(context).width < 600;
  final fieldStyle = isMobile
      ? Theme.of(context).textTheme.bodyMedium
      : Theme.of(context).textTheme.bodySmall;
  return Row(
    children: [
      Text('$label ', style: labelStyle),
      Expanded(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: fieldStyle,
          decoration: dateTimeInputDecoration(hint),
          inputFormatters: formatters,
          onSubmitted: (_) => onCommit(),
          onEditingComplete: onCommit,
        ),
      ),
      ?trailing,
    ],
  );
}

Future<(int, int, int)?> showPreciseTimePicker({
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
        final spinnerStyle = Theme.of(
          ctx,
        ).textTheme.headlineSmall?.copyWith(fontFamily: 'monospace');

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

        Widget spinner(
          String label,
          int value,
          int max,
          ValueChanged<int> onChanged,
          TextEditingController ctrl,
        ) {
          return IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(ctx).textTheme.labelSmall),
                const SizedBox(height: 4),
                IconButton(
                  icon: const Icon(Icons.arrow_drop_up),
                  onPressed: () =>
                      setState(() => onChanged((value + 1) % (max + 1))),
                ),
                TextField(
                  controller: ctrl,
                  textAlign: TextAlign.center,
                  style: spinnerStyle,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
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
                  onPressed: () => setState(
                    () => onChanged((value - 1 + max + 1) % (max + 1)),
                  ),
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
