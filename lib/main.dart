// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/ephe/bootstrap.dart';
import 'core/persistence.dart';
import 'core/user_ayanamsa.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ephe = await bootstrapEpheSource();
  final prefs = await SharedPreferences.getInstance();
  // Before any provider reads the store, so the Context and the user-defined
  // list both come up on the current shape and neither has to know the old one.
  migrateLegacyUserAyanamsa(prefs);
  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        epheSeedProvider.overrideWithValue(ephe),
      ],
      child: const SweDashboardApp(),
    ),
  );
}
