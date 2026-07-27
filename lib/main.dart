// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/ephe/bootstrap.dart';
import 'core/persistence.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ephe = await bootstrapEpheSource();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        epheBootstrapProvider.overrideWithValue(ephe),
      ],
      child: const SweDashboardApp(),
    ),
  );
}
