import '../calc_context.dart';

enum CallCategory { context, flags, calc, teardown }

class CallEntry {
  const CallEntry({
    required this.functionName,
    required this.args,
    required this.category,
    required this.traceId,
    this.result,
    this.returnFlag,
    this.errorMessage,
  });

  final String functionName;
  final Map<String, Object?> args;
  final Object? result;
  final int? returnFlag;
  final String? errorMessage;
  final CallCategory category;
  final String traceId;
}

class CallTrace {
  const CallTrace({
    required this.entries,
    required this.context,
    required this.capturedAt,
  });

  final List<CallEntry> entries;
  final EffectiveContext context;
  final DateTime capturedAt;

  TraceSlice sliceByCategory(CallCategory category) => TraceSlice(
    entries: entries.where((e) => e.category == category).toList(),
    context: context,
  );

  TraceSlice sliceByTraceId(String traceId) => TraceSlice(
    entries: entries.where((e) => e.traceId == traceId).toList(),
    context: context,
  );

  TraceSlice sliceByTab(String tabTag) => TraceSlice(
    entries: entries.where((e) => e.traceId.startsWith('$tabTag:')).toList(),
    context: context,
  );
}

class TraceSlice {
  const TraceSlice({required this.entries, required this.context});

  final List<CallEntry> entries;
  final EffectiveContext context;
}
