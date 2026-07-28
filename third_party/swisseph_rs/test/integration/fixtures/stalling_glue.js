// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC
//
// Stand-in for the Emscripten glue that loads fine and then never finishes
// initializing -- the shape a black-holed .wasm fetch presents to the loader.
//
// The real failure needs a server that completes the TCP handshake and then
// goes silent, which a browser test cannot stand up. But the loader does not
// observe the socket; it observes the factory promise. Reproducing that
// promise is enough, and needs nothing but a served file.
//
// `var` (not `globalThis.x =`) on purpose: the real glue declares its export
// as a top-level `var`, and it is precisely that binding being re-assigned by
// a duplicate <script> that the loader's factory wrapper has to survive.
var SwissEphRs = function () {
  return new Promise(function (resolve) {
    // Handing the resolver out is what makes the generation guard testable:
    // an abandoned attempt has to be able to resolve *late*, after a
    // subsequent attempt has already succeeded, and nothing else can stage
    // that ordering.
    globalThis.__stallRelease = resolve;
  });
};
