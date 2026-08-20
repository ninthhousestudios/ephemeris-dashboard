---
status: accepted
---

# The JPL Horizons tab is request/response, exempt from reactive projection

**The JPL Horizons tab fetches on an explicit Run button and holds its own
draft + last-result state; it is deliberately outside ADR-0001's reactive
projection.** Every other tab's Results are a pure function of the Context,
recomputed synchronously on change. Horizons is not: it is a remote,
latency-bound, rate-limited HTTP call to NASA/JPL that can return multi-megabyte
tables, and its query surface (target, center, five ephemeris types, time
grammar, ~40 output parameters) is far larger and more independent than the
shared Context.

Firing such a call on every keystroke or Context edit would get the app
rate-limited by JPL and make the UI feel broken. So this one tab reintroduces a
Calculate trigger — under a different name (Run) — on purpose. The draft is
free-to-edit UI state; only Run builds an immutable `HorizonsRequest` and
executes it; the result is an `AsyncValue<HorizonsResponse>` that persists until
the next Run.

## Considered options

- **Debounced auto-fetch** (rejected): would still hammer JPL on rapid edits and
  couple an external service's availability to the tab feeling responsive; the
  staleness the reactive model avoids is real and desirable here (you want to see
  exactly the query you launched, not a moving target).
- **Reuse the Context Moment/flags as the query** (rejected as the *primary*
  model): Horizons' time and frame model is richer and independent of the
  Context. The Context is instead offered as a one-shot pre-fill ("Load from
  Context"), not a live binding.

## Consequences

- HTTP is confined to the `lib/core/horizons/` seam (dio behind a Provider),
  mirroring the SIMBAD/downloader discipline; tabs and widgets never import
  `package:dio`. See `.sutra/rules.toml` intent, ADR-0002.
- The tab declares `hasFlags: false` — the Locked Flag bar is meaningless for a
  remote engine and is not shown.
- Responses are cached by normalized-request hash (`HorizonsCache`), so a re-Run
  of an identical query is instant and rate-limit friendly.
- The synchronous-recompute invariant (CLAUDE.md) does not apply to this tab: it
  has no Context-derived compute pass. Its result comes from an awaited fetch,
  which is exactly why it is fenced off here rather than living among the
  reactive tabs.
