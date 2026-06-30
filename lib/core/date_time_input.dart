import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String fmtDate(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

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
  return (year: negative ? -y : y, month: mo, day: d);
}

({int hour, int minute, int second})? parseTimeFields(String text) {
  final parts = text.split(':');
  if (parts.isEmpty) return null;
  final h = int.tryParse(parts[0]);
  if (h == null) return null;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final s = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
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
