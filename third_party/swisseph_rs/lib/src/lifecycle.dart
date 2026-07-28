// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

export 'lifecycle_native.dart'
    if (dart.library.js_interop) 'lifecycle_web.dart';
