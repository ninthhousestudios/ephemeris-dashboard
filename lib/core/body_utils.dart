import 'package:swisseph/swisseph.dart';

String safeGetName(SwissEph swe, int body) {
  try {
    return swe.getPlanetName(body);
  } catch (_) {
    return 'Body $body';
  }
}
