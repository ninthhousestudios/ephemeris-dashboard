// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

// ignore_for_file: avoid_print
import 'package:swisseph_rs/swisseph_rs.dart' as rs;
import 'package:swe_dashboard/core/ephemeris/tracing_rust_eph.dart';

void main() {
  final swe = TracingRustEph();
  print('version: ${rs.engineVersion}');

  for (final name in [
    'Aldebaran',
    'Sirius',
    'Spica',
    'Regulus',
    'Vega',
    'Arcturus',
    'Betelgeuse',
    'Canopus',
    'Fomalhaut',
    'Algol',
  ]) {
    try {
      final r = swe.fixstar2Ut(name, 2460000.5, 0);
      print('$name: OK → ${r.starName} lon=${r.longitude.toStringAsFixed(4)}');
    } catch (e) {
      print('$name: FAIL → $e');
    }
  }

  // Also try with setEphePath pointing to the ephe dir
  swe.setEphePath('/home/josh/nhs/soft/swisseph/ephe');
  print('\n--- With ephePath set ---');
  for (final name in ['Aldebaran', 'Sirius', 'Spica', 'Regulus', 'Vega']) {
    try {
      final r = swe.fixstar2Ut(name, 2460000.5, 0);
      print('$name: OK → ${r.starName} lon=${r.longitude.toStringAsFixed(4)}');
    } catch (e) {
      print('$name: FAIL → $e');
    }
  }

  swe.close();
}
