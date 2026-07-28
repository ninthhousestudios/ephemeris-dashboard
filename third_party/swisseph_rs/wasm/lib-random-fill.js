// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC
//
// Emscripten JS library override for $initRandomFill.
//
// Emscripten's default implementation (src/lib/libwasi.js) calls
// crypto.getRandomValues directly on a view into WASM memory:
//
//   random_get = (buffer, size) => randomFill(HEAPU8.subarray(buffer, buffer + size))
//
// Under ALLOW_MEMORY_GROWTH, WebAssembly.Memory's buffer is exposed as a
// resizable ArrayBuffer on current Chrome, and Web Crypto rejects any view
// backed by a resizable buffer:
//
//   TypeError: Failed to execute 'getRandomValues' on 'Crypto':
//              The provided ArrayBufferView value must not be resizable.
//
// The engine's first entropy request is 16 bytes inside swisseph_new, so
// without this override every Ephemeris construction throws on web while
// module load still appears to succeed.
//
// Fix: fill a plain (non-resizable) buffer, then copy into WASM memory --
// the same strategy Emscripten already uses for its SHARED_MEMORY build,
// where Web Crypto likewise cannot write directly into the heap.
//
// This is passed via --js-library from build.sh, so the fix is baked into
// generated glue rather than hand-patched into the vendored artifact.

addToLibrary({
  $initRandomFill: () => {
    // crypto.getRandomValues rejects requests over 65536 bytes, so chunk.
    const fillPlain = (dest) => {
      for (let off = 0; off < dest.length; off += 65536) {
        crypto.getRandomValues(dest.subarray(off, Math.min(off + 65536, dest.length)));
      }
      return dest;
    };
    return (view) => (view.set(fillPlain(new Uint8Array(view.byteLength))), 0);
  },
});
