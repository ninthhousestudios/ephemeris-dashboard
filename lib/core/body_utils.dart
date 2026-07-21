// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'swe_constants.dart';
import 'swe_utils.dart';

String safeGetName(SweUtils swe, int body) {
  try {
    return swe.getPlanetName(body);
  } catch (_) {
    return 'Body $body';
  }
}

String describeBodyError(int body, String rawMessage) {
  if (body >= sePlmoonOffset && body < seAstOffset) {
    return 'Missing satellite file sepm$body.se1 (sat/). '
        'Open the Ephemeris tab to download. '
        'SE error: $rawMessage';
  }
  if (body >= seAstOffset) {
    final mpc = body - seAstOffset;
    final sub = mpc ~/ 1000;
    final prefix = mpc >= 100000 ? 's' : 'se';
    final digits = mpc >= 100000 ? 6 : 5;
    final fname = '$prefix${mpc.toString().padLeft(digits, '0')}s.se1';
    return 'Missing file $fname (ast$sub/). '
        'Open the Ephemeris tab to download. '
        'SE error: $rawMessage';
  }
  return rawMessage;
}
