// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'code_emitter.dart';
export 'code_emitter.dart' show CodeEmitter;

final selectedEmitterProvider = StateProvider<CodeEmitter>(
  (_) => const CEmitter(),
);

const availableEmitters = <CodeEmitter>[CEmitter(), DartEmitter()];
