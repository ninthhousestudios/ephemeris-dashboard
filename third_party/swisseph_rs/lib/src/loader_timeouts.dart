// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// The web loader's stall budgets, and the test-only seam for shortening them.
///
/// These live here rather than in `loader_web.dart` because that library *is*
/// public API: `swisseph_rs.dart` exports `loader.dart`, which conditionally
/// exports `loader_web.dart`, so every public symbol in it is callable by a
/// consumer on web -- Dart-only surface with no `swisseph::*` counterpart, and
/// asymmetric with the native half. `@visibleForTesting` warns inside this
/// package's own tests; it does not stop a consumer. Nothing exports this
/// file, so nothing here reaches the public surface. Tests import it directly.
library;

import 'package:meta/meta.dart';

/// How long to wait for the glue `<script>` tag to fire load or error.
///
/// A server that accepts the connection and then never responds -- a stalled
/// proxy, a hung CDN edge, a captive portal black-holing the request -- fires
/// neither event, so an unbounded wait is a silent forever-hang. This bounds
/// it.
///
/// 30s is chosen against what this timeout actually covers: the Emscripten
/// glue only (~68KB), not the ~857KB sibling `.wasm`, which is fetched later
/// inside `DynamicLibrary.open`. 68KB clears 30s on any connection above
/// ~20kbit/s, i.e. everything short of a link already too dead to run the
/// module. Anything shorter starts failing legitimate cold-mobile loads;
/// anything longer is indistinguishable from the hang it exists to prevent.
const defaultGlueLoadTimeout = Duration(seconds: 30);

/// How long to wait for `DynamicLibrary.open` to instantiate the module.
///
/// [defaultGlueLoadTimeout] bounds only the `<script>` tag. Everything
/// expensive happens after it, inside `DynamicLibrary.open`, on awaits with no
/// timeout of their own:
///
///  * a `http.head` probe for `<path>.js` / `<path>.wasm`, taken whenever
///    modulePath carries no extension -- which is the documented default;
///  * the Emscripten factory call, which fetches the ~857KB `.wasm` and
///    instantiates it.
///
/// The same stalled server that black-holes the glue URL black-holes these,
/// so bounding the script tag alone narrows the hang rather than closing it.
///
/// 60s is not proportional to the 12.5x larger payload, deliberately. What
/// this bounds is a stall (unbounded), not slowness, so the budget only has
/// to sit above any plausibly-legitimate load: 857KB lands inside 60s on
/// anything above ~120kbit/s, and below that the module is too slow to be
/// usable at all. Erring generous is cheap now that a failed init is
/// retryable.
const defaultModuleInstantiateTimeout = Duration(seconds: 60);

/// The timeouts actually applied, overridable only by tests.
///
/// Abandoning an attempt is reachable *only* by letting a timeout elapse, so
/// without a seam every test of the stall paths -- including the generation
/// guard, which is the piece standing between the instantiation timeout and a
/// corrupted `Memory.global` -- costs a full 90s of wall clock. See
/// [debugSetLoaderTimeouts].
Duration glueLoadTimeout = defaultGlueLoadTimeout;
Duration moduleInstantiateTimeout = defaultModuleInstantiateTimeout;

/// Shorten the loader's timeouts so the stall paths can be exercised.
///
/// Test-only, and deliberately *not* a caller-facing knob: see the library
/// doc for why it lives here rather than beside the loader. The duration
/// staying fixed for callers is a decision (swisseph-rs-dart/51), not an
/// oversight -- this seam exists to make a 90-second test a sub-second one,
/// nothing more.
///
/// Pair with [debugResetLoaderTimeouts] in a tearDown; the overrides are
/// process-global.
@visibleForTesting
void debugSetLoaderTimeouts({Duration? glueLoad, Duration? moduleInstantiate}) {
  if (glueLoad != null) glueLoadTimeout = glueLoad;
  if (moduleInstantiate != null) moduleInstantiateTimeout = moduleInstantiate;
}

/// Restore both loader timeouts to their shipping defaults.
@visibleForTesting
void debugResetLoaderTimeouts() {
  glueLoadTimeout = defaultGlueLoadTimeout;
  moduleInstantiateTimeout = defaultModuleInstantiateTimeout;
}
