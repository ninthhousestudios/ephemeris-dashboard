import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/context_provider.dart';
import '../../core/date_time_input.dart';
import '../../core/jd_utils.dart';
import '../../core/swe_service.dart';

class ContextDateField extends ConsumerStatefulWidget {
  const ContextDateField({super.key});

  @override
  ConsumerState<ContextDateField> createState() => _ContextDateFieldState();
}

class _ContextDateFieldState extends ConsumerState<ContextDateField> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;
  bool _selfUpdate = false;

  JdUtils get _jdUtils => JdUtils(ref.read(sweProvider));

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        if (!_focusNode.hasFocus) _commit();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sync() {
    if (_focusNode.hasFocus) return;
    final ctx = ref.read(contextBarProvider);
    final local = _jdUtils.applyUtcOffset(ctx.dateTime, ctx.utcOffset);
    _controller.text = fmtDate(local);
  }

  void _commit() {
    final parsed = parseDateFields(_controller.text);
    if (parsed == null) return;
    final ctx = ref.read(contextBarProvider);
    final oldDt = ctx.dateTime;
    final newDt = DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      oldDt.hour,
      oldDt.minute,
      oldDt.second,
    );
    final ut = _jdUtils.removeUtcOffset(newDt, ctx.utcOffset);
    _selfUpdate = true;
    ref.read(contextBarProvider.notifier).setDateTime(ut);
  }

  Future<void> _pick() async {
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
      picked.year,
      picked.month,
      picked.day,
      local.hour,
      local.minute,
      local.second,
    );
    ref
        .read(contextBarProvider.notifier)
        .setDateTime(_jdUtils.removeUtcOffset(newLocal, ctx.utcOffset));
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
    if (_controller.text.isEmpty) _sync();

    return labeledField(
      context: context,
      label: 'Date',
      controller: _controller,
      focusNode: _focusNode,
      hint: 'YYYY-MM-DD',
      onCommit: _commit,
      formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]'))],
      trailing: dateTimeIconButton(Icons.calendar_today, 'Pick date', _pick),
    );
  }
}
