// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC
//
// Service worker that black-holes any request whose URL contains
// "__stall__": it accepts the request and then never responds.
//
// This is the only way to reach the loader's glue <script> timeout. A tag
// pointed at a served file always fires load or error, and a tag pointed at a
// dead port fires error -- neither is the failure being tested, which is a
// server that completes the handshake and then goes silent. The pending-
// promise fixture used for the instantiation timeout cannot help either: that
// one works because the loader observes the Emscripten factory promise, and
// this timeout fires before any factory exists.
//
// This file must sit beside the test page, not under fixtures/. A worker's
// default scope is the directory it is served from, and it can only control
// pages inside that scope -- from fixtures/ it would cover the stalled URL
// but not the page requesting it, so the page would stay uncontrolled and
// every fetch would bypass this worker. Widening scope instead would need a
// Service-Worker-Allowed header, which package:test's server cannot send.
//
// Matching on a marker substring rather than the real glue path is what keeps
// that requirement cheap: the stalled URL can live wherever we like.

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  // Claim the already-open test page; without this the page stays
  // uncontrolled and every fetch bypasses this worker entirely.
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  if (event.request.url.includes('__stall__')) {
    // Never settles. Not an error, not a response -- the tag sits waiting.
    event.respondWith(new Promise(function () {}));
  }
  // Everything else: no respondWith, so the browser goes to the network as
  // usual. The test page's own assets load through this worker.
});
