// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter/material.dart';

class AppThemes {
  AppThemes._();

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5C6BC0), // indigo
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    fontFamily: 'RobotoMono',
  );

  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5C6BC0),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    fontFamily: 'RobotoMono',
  );

  static ThemeData get cosmic => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF7B1FA2), // deep purple
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    fontFamily: 'RobotoMono',
  );

  static ThemeData get forest => ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32), // green
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    fontFamily: 'RobotoMono',
  );

  static final List<({String name, ThemeMode mode, ThemeData? data})> all = [
    (name: 'Dark', mode: ThemeMode.dark, data: null),
    (name: 'Light', mode: ThemeMode.light, data: null),
    (name: 'System', mode: ThemeMode.system, data: null),
  ];
}
