// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:ffi';

import 'bindings/bindings.dart' show swissephFree;

final _finalizer = NativeFinalizer(
  Native.addressOf<NativeFunction<Void Function(Pointer<Void>)>>(swissephFree),
);

void attachCleanup(Finalizable owner, Pointer<Void> handle) {
  _finalizer.attach(owner, handle, detach: owner);
}

void detachCleanup(Finalizable owner) {
  _finalizer.detach(owner);
}
