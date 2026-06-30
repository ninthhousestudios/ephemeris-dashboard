import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_themes.dart';
import 'theme/theme_provider.dart';
import 'layout/app_shell.dart';

class SweDashboardApp extends ConsumerWidget {
  const SweDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final scale = ref.watch(scaleFactorProvider);

    return MaterialApp(
      title: 'Swiss Ephemeris Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: themeMode,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
              zoomIn(ref),
          const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
              zoomOut(ref),
          const SingleActivator(LogicalKeyboardKey.digit0, control: true): () =>
              zoomReset(ref),
        },
        child: const Focus(autofocus: true, child: AppShell()),
      ),
    );
  }
}
