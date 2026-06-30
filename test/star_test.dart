// ignore_for_file: avoid_print
import 'package:swisseph/swisseph.dart';

void main() {
  final swe = SwissEph.find();
  print('version: ${swe.version()}');

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
