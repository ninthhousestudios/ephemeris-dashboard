// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:wasm_ffi/ffi.dart';

late DynamicLibrary wasmLibrary;
bool wasmInitialized = false;
Future<void>? initFuture;
String? initModulePath;

void ensureInitialized() {
  if (!wasmInitialized) {
    throw StateError(
      'WASM module not loaded. Call initializeWasm() before using the API.',
    );
  }
}

JSObject getEmscriptenFS() {
  final module = globalContext.getProperty('__swissephRsModule'.toJS);
  if (module == null || !module.isA<JSObject>()) {
    throw StateError('Emscripten module not available.');
  }
  final fs = (module as JSObject).getProperty('FS'.toJS);
  if (fs == null || !fs.isA<JSObject>()) {
    throw StateError(
      'Emscripten FS not available (built without FILESYSTEM=1?).',
    );
  }
  return fs as JSObject;
}
