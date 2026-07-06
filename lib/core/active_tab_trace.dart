import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ephemeris/trace_model.dart';

final activeTraceSourceProvider = StateProvider<Provider<CallTrace>?>(
  (ref) => null,
);

final activeTabTraceProvider = Provider<CallTrace?>((ref) {
  final source = ref.watch(activeTraceSourceProvider);
  if (source == null) return null;
  return ref.watch(source);
});
