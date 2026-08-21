// Web (no dart:io) no-op counterpart to nasa_trust_io.dart. In the browser the
// platform performs TLS against its own trust store — which carries the Sectigo
// R46 root — so there is nothing to patch. Selected via horizons_client.dart's
// `if (dart.library.io)` conditional import.

import 'package:dio/dio.dart';

/// No-op on web; see nasa_trust_io.dart for the native rationale.
void applyNasaTrust(Dio dio) {}
