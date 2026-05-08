import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'code_emitter.dart';

final selectedEmitterProvider = StateProvider<CodeEmitter>((_) => const CEmitter());

const availableEmitters = <CodeEmitter>[CEmitter(), DartEmitter()];
