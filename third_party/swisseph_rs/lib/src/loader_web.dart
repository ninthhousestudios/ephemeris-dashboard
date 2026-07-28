// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:wasm_ffi/ffi.dart';
import 'package:web/web.dart' as web;

import 'loader_timeouts.dart';
import 'wasm_state.dart' as wasm;

const _ephePath = '/ephe';
bool _dirCreated = false;

/// Attempt counter, bumped once per [initializeWasm] attempt.
///
/// Only the current attempt is allowed to publish its module. See the factory
/// wrapper in [_loadAndWrapFactory] for why an abandoned attempt must be
/// parked rather than left to finish.
int _initGeneration = 0;

/// The generation stamp no attempt ever carries.
///
/// Generations start at 1, so parking the JS-side stamp here retires whatever
/// attempt owned it without handing ownership to anything.
const _retiredGeneration = -1;

/// Retire [generation] the moment its attempt is abandoned.
///
/// The wrapper installed by [_loadAndWrapFactory] parks a factory promise only
/// when the JS-side stamp no longer matches the generation it closed over.
/// Bumping the stamp when the *next* attempt starts is too late: between a
/// timeout firing and that next attempt, the abandoned factory still matches,
/// so it would publish its module and let `DynamicLibrary.open` run on to
/// publish the orphan's [Memory.global] and `WasmTable.global` -- the exact
/// corruption the guard exists to prevent, through the one window it left
/// open. Retiring here closes it: the attempt is dead the instant it fails,
/// not once a successor exists.
///
/// Guarded on the stamp still belonging to [generation] so a late failure can
/// never retire someone else's attempt.
void _retireGeneration(int generation) {
  _jsEval(
    'if (globalThis.__swissephRsGen === $generation) {'
    '  globalThis.__swissephRsGen = $_retiredGeneration;'
    '}',
  );
}

/// Counterpart: (systematic divergence: web loader seam)
///
/// Load the swisseph_ffi WASM module. Must be called before constructing
/// [Ephemeris] or calling any API function on web.
///
/// [modulePath] is the URL to the swisseph_ffi.js Emscripten glue file
/// served from your web app's assets. Defaults to `'swisseph_ffi'`.
///
/// This function is single-flight and idempotent: concurrent or repeated
/// calls with the same [modulePath] return the same future. Calling with a
/// different path after initialization has started throws [StateError].
///
/// A *failed* initialization is not sticky: the single-flight latch is
/// released, so the call may be retried (with the same or a different
/// [modulePath]). Loading the glue script can fail transiently -- the
/// [TimeoutException] raised when the script neither loads nor errors within
/// 30 seconds is exactly such a case -- and a permanently poisoned latch
/// would make one bad network moment terminal for the isolate.
Future<void> initializeWasm([String? modulePath]) {
  final path = modulePath ?? 'swisseph_ffi';
  if (wasm.initFuture != null) {
    if (wasm.initModulePath != path) {
      throw StateError(
        'initializeWasm already called with "${wasm.initModulePath}"; '
        'cannot re-initialize with "$path".',
      );
    }
    return wasm.initFuture!;
  }
  wasm.initModulePath = path;
  wasm.initFuture = _doInit(path).onError<Object>((error, stack) {
    wasm.initFuture = null;
    wasm.initModulePath = null;
    Error.throwWithStackTrace(error, stack);
  });
  return wasm.initFuture!;
}

Future<void> _doInit(String path) async {
  // Load the Emscripten glue script and wrap the factory to capture the
  // module instance. wasm_ffi's EmscriptenModule wraps the raw JS module
  // with no public accessor, but getEmscriptenFS() needs it for MEMFS.
  // Pre-loading also bounds the fetch, which DynamicLibrary.open does not.
  final generation = ++_initGeneration;
  try {
    await _doInitGeneration(path, generation);
  } catch (_) {
    // Every exit from this attempt other than success is an abandonment, and
    // none of them cancel work already in flight. Retire the generation here,
    // while the single-flight latch still guarantees no successor exists.
    _retireGeneration(generation);
    rethrow;
  }
}

Future<void> _doInitGeneration(String path, int generation) async {
  final resolved = await _loadAndWrapFactory(path, generation);

  // Hand wasm_ffi the same absolute URL the tag carries, not the caller's
  // path. Its isImported() dedup compares an element's resolved .src against
  // the string it is given with endsWith, so any path the browser resolves --
  // anything relative, "../" above all -- fails to match, and it injects a
  // second glue tag. Correctness no longer rides on that match (the capture
  // is an accessor on globalThis; see _loadAndWrapFactory), but a duplicate
  // tag is still a wasted fetch and a second module instantiation. Passing
  // the resolved URL also carries an explicit extension, which skips
  // wasm_ffi's http.head probe for "<path>.js" / "<path>.wasm" -- one more
  // unbounded await removed from this path.
  wasm.wasmLibrary =
      await DynamicLibrary.open(
        resolved,
        moduleName: 'SwissEphRs',
        useAsGlobal: GlobalMemory.yes,
      ).timeout(
        moduleInstantiateTimeout,
        onTimeout: () => throw TimeoutException(
          'Timed out instantiating the WASM module from "$path"; the glue '
          'script loaded but the module never finished initializing (the '
          'sibling .wasm fetch is the usual culprit).',
          moduleInstantiateTimeout,
        ),
      );

  // The factory wrapper stores the module here, stamped with the generation
  // that captured it. Check the stamp rather than mere presence: an abandoned
  // earlier attempt can have left a module behind, and that stale value would
  // satisfy a presence check while __swissephRsModule points at a heap this
  // attempt does not own.
  //
  // A mismatch means the module this attempt received was never published
  // under its stamp -- e.g. an abandoned attempt's factory resolving under a
  // retired generation. Fail here, naming it, rather than at the first
  // getEmscriptenFS() with "module not available".
  final capturedGen = globalContext.getProperty<JSNumber?>(
    '__swissephRsModuleGen'.toJS,
  );
  if (capturedGen?.toDartInt != generation) {
    throw StateError(
      'WASM module loaded but was not captured from "$path"; the glue script '
      'appears to have been re-executed and replaced the factory wrapper.',
    );
  }
  _disarmCapture(generation);
  wasm.wasmInitialized = true;
}

/// Stop publishing captured modules, now that [generation] owns the one that
/// counts.
///
/// The accessor stays installed for the life of the page -- it has to, or a
/// later glue execution would leave a raw factory behind. But it must stop
/// *publishing* the moment this attempt's module is the one wasm_ffi bound to.
/// Any later call of the factory -- a host page instantiating the glue for its
/// own purposes, a caller driving it directly -- produces a second Emscripten
/// module with its own heap. Republishing that module would point
/// getEmscriptenFS() at the new heap while [wasm.wasmLibrary], [Memory.global]
/// and every bound function still address the old one, so staged .se1 files
/// would land in a filesystem the engine never reads. Silent, and miserable to
/// diagnose.
///
/// Disarming is not the same as retiring the generation: a retired generation
/// parks its factory promise forever, which is right for an abandoned attempt
/// but wrong here. A post-initialization caller gets its module back, it just
/// does not get to redirect ours.
void _disarmCapture(int generation) {
  _jsEval(
    'if (globalThis.__swissephRsArmed === $generation) {'
    '  globalThis.__swissephRsArmed = $_retiredGeneration;'
    '}',
  );
}

@JS('eval')
external void _jsEval(String code);

/// Loads the glue script and wraps the Emscripten factory, returning the
/// absolute URL the tag was given.
Future<String> _loadAndWrapFactory(String path, int generation) async {
  // wasm_ffi's DynamicLibrary.open resolves an extensionless modulePath to
  // "<path>.js". Mirror that here so the pre-load requests the same URL --
  // otherwise this fetches a 404, and hands wasm_ffi a URL the pre-load
  // never warmed.
  //
  // Test the extension on the parsed URI's last path segment, not the raw
  // string: modulePath is a URL, so a cache-busted "swisseph_ffi.js?v=1"
  // does not end in ".js" and must not have another ".js" appended.
  // wasm_ffi derives its extension the same way (uri.pathSegments.last).
  final segments = Uri.parse(path).pathSegments;
  final lastSegment = segments.isEmpty ? '' : segments.last;
  final withExtension =
      lastSegment.endsWith('.js') || lastSegment.endsWith('.wasm')
      ? path
      : '$path.js';
  // Resolve against the document URL up front. A script element's .src getter
  // always reports the resolved absolute URL, and wasm_ffi's dedup matches on
  // that string, so keeping the caller's relative form here is what lets a
  // duplicate tag through.
  final src = Uri.base.resolve(withExtension).toString();
  // Install the capture *before* the tag, so the assignment the glue performs
  // on execution is the one that arms it.
  _installFactoryCapture(generation);
  final script = web.HTMLScriptElement()
    ..type = 'text/javascript'
    ..src = src
    ..async = true;
  web.document.head!.appendChild(script);
  // A script that fails to fetch fires onError and never onLoad, so awaiting
  // onLoad alone turns any bad modulePath into a silent forever-hang.
  final loaded = Completer<void>();
  unawaited(
    script.onLoad.first.then((_) {
      if (!loaded.isCompleted) loaded.complete();
    }),
  );
  unawaited(
    script.onError.first.then((_) {
      if (!loaded.isCompleted) {
        loaded.completeError(
          StateError('Failed to load WASM glue script from "$src".'),
        );
      }
    }),
  );
  // Neither event fires if the server accepts the connection and then goes
  // quiet, so bound the wait. The fetch is not cancellable -- a <script> load
  // has no abort -- so this reports the failure rather than stopping it, and
  // drops the tag from the DOM: a retry appends a fresh one, and a stale tag
  // left behind would also confuse wasm_ffi's isImported() src-matching dedup
  // into skipping the real load.
  await loaded.future.timeout(
    glueLoadTimeout,
    onTimeout: () {
      script.remove();
      throw TimeoutException(
        'Timed out loading WASM glue script from "$src"; the server accepted '
        'the request but never completed it.',
        glueLoadTimeout,
      );
    },
  );
  return src;
}

/// Arms the module capture for [generation] and keeps it armed.
///
/// The Emscripten factory has to be wrapped so the module instance lands in
/// `globalThis.__swissephRsModule` -- wasm_ffi's EmscriptenModule holds it
/// with no public accessor, and getEmscriptenFS() needs it for MEMFS.
///
/// The wrapping is installed as an accessor property rather than by assigning
/// over `globalThis.SwissEphRs` after the glue has run, because a plain
/// assignment only survives until the next time the glue executes. The glue's
/// top-level `var SwissEphRs = ...` does not redefine an existing own property
/// of the global object -- it assigns through it -- so a getter/setter pair
/// re-wraps every load instead of being overwritten by it. Any duplicate tag
/// (wasm_ffi's isImported() dedup matches a script's *resolved* .src with
/// endsWith, so it re-injects for any "../"-relative path), any late arrival
/// from an abandoned attempt, any host page that loads the glue itself: all of
/// them now feed the capture rather than strip it off.
///
/// Wrapping and *publishing* are separate concerns. The wrapper stays in place
/// for the life of the page; whether it publishes what it sees into
/// `__swissephRsModule` is gated on `__swissephRsArmed`, which [_disarmCapture]
/// clears once this attempt's module is the one wasm_ffi bound to. Every
/// resolution the wrapper sees, published or not, bumps `__swissephRsCaptures`
/// -- a liveness counter, so "is the wrapper still on the call path?" is an
/// observable question rather than an inference from a global that may
/// legitimately not have changed.
///
/// Two details exist for the sake of a *second* attempt, which the retry
/// semantics of initializeWasm() make reachable:
///
///  * the raw factory is closed over per attempt, and mirrored into
///    `__swissephRsRaw` only so a re-install can recover it without
///    double-wrapping its own predecessor's wrapper.
///  * a stale attempt's promise is parked, never resolved -- stale meaning the
///    JS-side stamp has moved on, which [_retireGeneration] makes true the
///    instant an attempt fails rather than whenever a successor happens to
///    start. Timing out DynamicLibrary.open does not cancel it: the abandoned
///    open() is still parked on this promise, and if it ever resolved it would
///    run the rest of open() and publish the *orphan's* [Memory.global] and
///    `WasmTable.global` over a successful retry's. Half the pointer
///    arithmetic would then resolve against one heap and half against another
///    -- silent memory corruption, strictly worse than the hang this timeout
///    replaces. Parking leaks one JS continuation per failed attempt, which is
///    the cheaper side of that trade.
void _installFactoryCapture(int generation) {
  _jsEval(
    '(function() {'
    '  var gen = $generation;'
    '  var raw = globalThis.__swissephRsRaw;'
    '  var d = Object.getOwnPropertyDescriptor(globalThis, "SwissEphRs");'
    '  if (d && !d.get && d.value !== undefined) { raw = d.value; }'
    '  var wrap = function(f) {'
    '    if (typeof f !== "function") { return f; }'
    '    return function(a) {'
    '      return f(a).then(function(m) {'
    '        globalThis.__swissephRsCaptures ='
    '          (globalThis.__swissephRsCaptures || 0) + 1;'
    '        if (globalThis.__swissephRsGen !== gen) {'
    '          return new Promise(function() {});'
    '        }'
    '        if (globalThis.__swissephRsArmed === gen) {'
    '          globalThis.__swissephRsModule = m;'
    '          globalThis.__swissephRsModuleGen = gen;'
    '        }'
    '        return m;'
    '      });'
    '    };'
    '  };'
    '  var wrapped = wrap(raw);'
    '  globalThis.__swissephRsRaw = raw;'
    '  globalThis.__swissephRsGen = gen;'
    '  globalThis.__swissephRsArmed = gen;'
    '  Object.defineProperty(globalThis, "SwissEphRs", {'
    '    configurable: true,'
    '    enumerable: true,'
    '    get: function() { return wrapped; },'
    '    set: function(f) {'
    '      raw = f;'
    '      globalThis.__swissephRsRaw = f;'
    '      wrapped = wrap(f);'
    '    },'
    '  });'
    '})();',
  );
}

/// Counterpart: (systematic divergence: web loader seam)
///
/// Stage an ephemeris file (.se1) into Emscripten's MEMFS virtual filesystem.
/// After staging all needed files, construct [Ephemeris] with
/// `EphemerisConfig(ephemerisSource: EphemerisSource.swiss, ephePath: '/ephe')`.
void loadEpheFile(String filename, Uint8List bytes) {
  if (filename.isEmpty ||
      filename.contains('/') ||
      filename.contains(r'\') ||
      filename == '.' ||
      filename == '..' ||
      filename.contains('\x00')) {
    throw ArgumentError.value(filename, 'filename', 'must be a bare filename');
  }
  wasm.ensureInitialized();
  final fs = wasm.getEmscriptenFS();
  if (!_dirCreated) {
    try {
      fs.callMethod('mkdir'.toJS, _ephePath.toJS);
    } catch (_) {}
    _dirCreated = true;
  }
  fs.callMethod('writeFile'.toJS, '$_ephePath/$filename'.toJS, bytes.toJS);
}
