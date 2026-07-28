// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

export 'config_pack_native.dart'
    if (dart.library.js_interop) 'config_pack_web.dart';
