import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/ephe/dir_provider.dart';
import 'core/persistence.dart';
import 'core/swe_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSweEphePath();
  await bootstrapManagedEphe();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const SweDashboardApp(),
    ),
  );
}
