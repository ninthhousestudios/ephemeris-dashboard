// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'swe_utils.dart';

String safeGetName(SweUtils swe, int body) {
  try {
    return swe.getPlanetName(body);
  } catch (_) {
    return 'Body $body';
  }
}
