// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

export 'ffi_types_native.dart'
    if (dart.library.js_interop) 'ffi_types_web.dart';
