# swisseph_rs

Idiomatic Dart transliteration of the swisseph-rs Rust API (pure-Rust Swiss
Ephemeris), bound via swisseph-ffi. Design docs: `CONTEXT.md` (domain
language — use its vocabulary), `docs/adr/0002` (the transliteration
decision, supersedes 0001), `docs/prd-swisseph-rs-v2.md` (PRD),
`docs/enforcement-ledger.md` (claim → enforcement routing). Tracker: yojana
project `swisseph-rs-dart`.

## API reference

`docs/api-surface.md` is the sole source of truth for the swisseph-rs public
API and swisseph-ffi C ABI surface (pinned to the same rev as `rust/Cargo.toml`).
**Do not explore or read `../swisseph-rs` source code** for transliteration
work. Read the relevant section of `api-surface.md` instead — it is organized
by task (/22–/34) and contains every type, method signature, and FFI function
needed.

**Escape hatch**: reading `../swisseph-rs` source is permitted only when a
**runtime failure** (test failure, FFI crash, type mismatch at the C boundary)
cannot be diagnosed from the map. "I want to understand the semantics" or
"I want more context" is not a trigger — a failing test is. When you do read
the Rust source under this rule, **update `api-surface.md`** with whatever
was missing or wrong before moving on, so the next session doesn't need to
make the same trip.

## Binding implementation guide

`docs/binding-patterns.md` — layer sequence, agreement classes, oracle
statefulness, Moshier limitations, config marshaling duplication threshold,
and oracle flag naming gotchas. Read this before implementing any binding
task (/28–/34).

Ephemeris files: `ephe/` is a git-ignored **real directory** (never a symlink
— the browser test server will not follow one out of the package root, and
the web Swiss-file test silently skipped for exactly that reason). Populate
it per "Populating ephe/" in `docs/ephemeris-data-releases.md`. Run Swiss-file
tests with `SWE_EPHE_PATH=ephe dart test`, and the browser leg with
`dart test -p chrome <file>` — a bare `dart test -p chrome` also drags the
VM-only tests into the browser, where `dart:io` fails.

The agreement-class oracle harness is a **separate package** — it cannot
co-resolve with `swisseph_rs` (see enforcement-ledger, "Running the oracle
harness"). Run it with `cd test_oracle && SWE_EPHE_PATH=../ephe dart test`;
`dart test` at the repo root does not reach it.

Swiss-file goldens are valid only against the pinned ephemeris data release
(`docs/ephemeris-data-releases.md`). Refreshing `ephe/` invalidates them:
`test/integration/ephemeris_release_test.dart` fails first and names the
change. Bumping that pin without re-recording the goldens it lists defeats
the mechanism.

## Invariants (enforcement-ledger bucket c — reviewed, not machine-checked)

### API discipline

- **Transliteration rule**: every public Dart symbol mirrors exactly one
  `swisseph::*` counterpart, declared in a fixed-format
  `/// Counterpart: swisseph::…` dartdoc line. Deviation is legal only via
  the named systematic divergences (CONTEXT.md); case-by-case divergence is
  a defect, however reasonable it looks locally. Never add Dart-only public
  surface beyond the sanctioned `DateTime` helpers (ledger row 2).
- **bindings is declarations only**: typed FFI lookups and struct
  definitions, zero logic. Any branching, defaulting, or conversion belongs
  in marshal (ledger row 5).
- **marshal is the only meeting point of Dart and FFI types**: config
  packing, result unpacking, `(code, errBuf)` → typed exception. ephemeris
  bodies stay thin — marshal, call, unmarshal, throw — and never import
  bindings directly (ledger row 6; partial sutra teeth bind at scaffold).

### Process

- **Engine pin bumps are deliberate**: the rust/ shim crate pins swisseph-ffi
  to a git rev of ninthhousestudios/swisseph-rs. Never float the rev; a bump
  is a reviewed one-line change (ledger row 8).
- **No silent tolerance loosening**: any harness tolerance looser than an
  agreement class's default must carry a comment naming the documented
  swisseph-rs boundary artifact (deflection speed / Moshier node speed /
  SPEED3 file boundaries). Boundary-class assignments are R2 review material
  (ledger row 16).
- **Platform seams**: web/native file pairs join only through their
  conditional-import barrel; never cross-import halves (ledger row 7; sutra
  constraint live since scaffold).
