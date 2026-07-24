// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layout/tab_definitions.dart';
import 'persistence.dart';

/// Which tab is on screen. The one source of truth.
///
/// It lives here rather than in `app_shell.dart` for two reasons. Widgets other
/// than the shell need to *set* it — the file-in-use indicator jumps to the
/// Charts tab — and importing the shell to reach a provider is what made
/// app_shell → context_bar → file_in_use_indicator a cycle. And a provider is
/// not a widget concern: the shell drives a TabController from it, but that is
/// the shell adapting to the state, not owning it.
final activeTabProvider = StateProvider<AppTab>((ref) {
  return ref.read(persistenceProvider).loadTab();
});

/// The active tab as its string id, for the keying that wants one (per-tab
/// series settings, export filenames).
///
/// Derived rather than a second [StateProvider] kept in step by hand. It was
/// the latter, mirrored on every tab change in the shell's TabController
/// listener — a mirror that can be forgotten, and that any writer other than
/// that one listener would have desynced silently.
final activeTabIdProvider = Provider<String>(
  (ref) => ref.watch(activeTabProvider).name,
);
