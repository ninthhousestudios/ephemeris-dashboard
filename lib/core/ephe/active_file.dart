import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calc_context.dart';
import 'scanner.dart';
import 'types.dart';

/// Return the [EpheFile] (if any) that would actually be read by
/// the C library for a calculation at [jdUt] in [family]. Only files
/// whose status is [EpheFileStatus.installed] count — a corrupt file
/// on disk won't actually be used, so we return null (→ "Moshier").
EpheFile? resolveActiveFile(
  EphemerisScan scan,
  double jdUt,
  BodyFamily family,
) {
  for (final f in scan.files) {
    if (f.family != family) continue;
    if (f.status != EpheFileStatus.installed) continue;
    if (jdUt >= f.startJd && jdUt < f.endJd) return f;
  }
  return null;
}

/// Family-keyed Riverpod provider. Watches the current JD + latest scan.
final activeFileProvider = Provider.family<EpheFile?, BodyFamily>((
  ref,
  family,
) {
  final jd = ref.watch(effectiveContextProvider).jdUt;
  final scan = ref.watch(ephemerisScanProvider).valueOrNull;
  if (scan == null) return null;
  return resolveActiveFile(scan, jd, family);
});
