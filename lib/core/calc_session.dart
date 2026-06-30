import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalcSession {
  const CalcSession({
    this.version = 0,
    this.lastRunAt,
    this.tabsRun = const {},
  });

  final int version;
  final DateTime? lastRunAt;
  final Set<String> tabsRun;

  bool tabHasRun(String tabId) => tabsRun.contains(tabId);
}

class CalcSessionNotifier extends StateNotifier<CalcSession> {
  CalcSessionNotifier() : super(const CalcSession());

  final Map<String, VoidCallback> _commits = {};

  void registerCommit(String tabId, VoidCallback cb) => _commits[tabId] = cb;
  void unregisterCommit(String tabId) => _commits.remove(tabId);

  void calculate({required Set<String> activate}) {
    for (final c in _commits.values) {
      c();
    }
    state = CalcSession(
      version: state.version + 1,
      lastRunAt: DateTime.now(),
      tabsRun: {...state.tabsRun, ...activate},
    );
  }
}

final calcSessionProvider =
    StateNotifierProvider<CalcSessionNotifier, CalcSession>(
      (_) => CalcSessionNotifier(),
    );

final activeTabIdProvider = StateProvider<String>((_) => 'planets');

const kContextOnlyTabs = <String>{
  'planets',
  'houses',
  'phenomena',
  'tableView',
  'differential',
  'nodesApsides',
  'crossings',
  'planetocentric',
};
