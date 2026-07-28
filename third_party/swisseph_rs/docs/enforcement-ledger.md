# Enforcement ledger

Total routing of every architectural claim in PRD v2
([`docs/prd-swisseph-rs-v2.md`](./prd-swisseph-rs-v2.md), yojana
`swisseph-rs-dart/20`). One claim, one mechanism. A claim with no row is a
routing bug.

**Supersession note (2026-07-05)**: this ledger replaces the v1 ledger
(drop-in facade design) per
[ADR-0002](./adr/0002-idiomatic-transliteration-over-drop-in-facade.md).
Retired v1 rows are recorded at the bottom — retirement is explicit, never
silent.

Buckets: (a) live sutra constraint · (b) deferred sutra constraint with
binding trigger · (c) CLAUDE.md invariant / review checklist · (d)
test-asserted, pointed at its implementing task.

| # | Claim (quote) | PRD section | Bucket | Mechanism | Status |
|---|---|---|---|---|---|
| 1 | "every public Dart symbol declares its Rust counterpart… machine-checked totality test" | Impl. Decisions | (d) | Counterpart totality test (public-API walk) | test (/26) |
| 2 | "deviation is legal only via the named systematic divergences" | Impl. Decisions | (c) | CLAUDE.md invariant; R1/R2 review checklist | routed → CLAUDE.md |
| 3 | "types — every pure-Dart declaration… zero FFI imports, isolation-testable" (path seam) | Impl. Decisions | (a) | `forbidden_dep` types↛bindings, types↛marshal | **live** (bound /21) |
| 4 | types purity re `dart:ffi` (SDK import — not path-expressible in sutra) | Impl. Decisions | (d) | Analyzer assertion in types unit tests | test (/23) |
| 5 | "bindings — FFI declarations only… no logic" | Impl. Decisions | (c) | CLAUDE.md invariant | routed → CLAUDE.md |
| 6 | "marshal — the only meeting point of Dart and FFI types" | Impl. Decisions | (a)+(c) | `forbidden_dep` ephemeris↛bindings (partial teeth); full single-point rule in CLAUDE.md | **live** (bound /21) + CLAUDE.md |
| 7 | "native/web halves behind conditional-import barrels" — never cross-import | Impl. Decisions | (a) | `forbidden_dep` web↛native ×2; sutra Dart import resolution expresses this | **live** (bound /21) |
| 8 | "build hook runs cargo against a shim crate pinning swisseph-ffi to an exact git rev" — bumps deliberate | Impl. Decisions | (c) | CLAUDE.md process invariant | routed → CLAUDE.md |
| 9 | "no env vars (`ephePath` explicit)" — SE_EPHE_PATH ignored by design | Impl. Decisions | (d) | Config test: env var set, construction ignores it | test (/23) |
| 10 | "no `version()` method; top-level `engineVersion` reads `swisseph_version`" | Impl. Decisions | (d) | Tracer test | test (/22) |
| 11 | Asteroids declared in config up front; undeclared asteroid throws (auto-registration has no successor) | Impl. Decisions | (d) | Positions family test asserting absence | test (/27) |
| 12 | "`close()` idempotent; use-after-close throws `StateError`; `NativeFinalizer` backstop" | Impl. Decisions | (d) | Tracer + sharing tests | test (/22, /36) |
| 13 | "swisseph_share (internal Arc clone)… every instance owns its handle equally"; any close order safe | Impl. Decisions | (d) | Upstream FFI tests + two-isolate close-order test | test (swisseph-rs/143, /36) |
| 14 | "oracle-map registry… total; undeclared public method fails the self-check" (direct / composite / engine-trusted) | Testing Decisions | (d) | Harness self-check | test (/26) |
| 15 | "every compared value in exactly one agreement class; unclassified comparisons… fail by design" | Testing Decisions | (d) | Harness self-check | test (/26) |
| 16 | No silent tolerance loosening — every boundary-class use names its documented artifact | Testing Decisions | (c) | CLAUDE.md invariant; R2 review focus | routed → CLAUDE.md |
| 17 | No import cycles in package source | skill default | (a) | `no_cycles` on lib/src | **live** (bound /21) |
| 18 | Fan-in guardrail on lib/src | skill default | (a) | `max_fan_in` threshold=7 (observed max=5, ~40% headroom) | **live** (bound /25; revised /35) |
| 19 | "same public API compiles and runs on web; only the loader seam differs" | Impl./Testing | (d) | Web test leg | test (/37) |
| 20 | "peak RSS bounded consistent with ONE loaded engine" | Testing Decisions | (d) | Stress test | test (/38) |
| 21 | libaditya 545-value dataset green | Testing Decisions | (d) | Dataset runner in standard test invocation | test (/39) |
| 22 | arrow/swe facade contract preserved through the migration | Out of Scope / story 33 | (d) | arrow's existing test suite | test (arjuna/arrow/10) |
| 23 | Swiss-file goldens are valid only against the ephemeris data release they were recorded from | Testing Decisions | (d)+(c) | Release pin test reads `.se1` provenance headers + `sefstars.txt` digest; inventory reviewed in `docs/ephemeris-data-releases.md` | test (/50) |
| 24 | "a web consumer's glue and Dart loader always come from one package version" | /59 | (d) | `wasmAssetPath` is joined to the `flutter: assets:` block by test, and both declared artifacts must exist | test (/59) |

## Running the oracle harness (rows 14–16)

The agreement-class harness lives in `test_oracle/`, which is **its own
package** (`swisseph_rs_oracle`, `publish_to: none`), not part of
`swisseph_rs`:

```
cd test_oracle && dart pub get
SWE_EPHE_PATH=../ephe dart test
```

It is a separate package because `package:swisseph` — the C Swiss Ephemeris
used as the numerical oracle — pins `hooks ^1.0.2` while `swisseph_rs` is on
`hooks ^2.0.2`, so the two cannot co-resolve. `test_oracle/pubspec.yaml`
carries `dependency_overrides` lifting `hooks`, `code_assets`, and
`native_toolchain_c` to their v2 releases; overrides apply only to the root
package, which is exactly why they cannot live in `swisseph_rs/pubspec.yaml`.
Retire them once `swisseph` publishes a release accepting `hooks ^2`.

This harness was unrunnable from the `hooks` v2 migration until
`swisseph-rs-dart/50`. Rows 14–16 route claims here, so while it was offline
those claims had no mechanism — if it stops resolving again, treat that as a
ledger outage, not as lint noise.

Note that the harness does **not** subsume row 23: it compares against the C
engine reading the *same* `ephe/` directory, so a data release swap moves both
sides together and is invisible to it.

## Retired v1 rows (ADR-0002)

| v1 row | Claim | Disposition |
|---|---|---|
| 1 | Drop-in contract (same ~93-method API, additive-only) | Dead — the contract itself was dropped; transliteration rule (rows 1–2) replaces it |
| 2 | config_state module interface contains no FFI types | Succeeded by row 3 (types↛bindings/marshal) — config_state has no successor module |
| 5 | `swisseph_new` called from config_state only | Dead with config_state; handle acquisition is Ephemeris constructor + share(), covered by rows 6, 13 |
| 8 | Engine switching never rebuilds the handle | Dissolved — nothing rebuilds handles in v2 at all (immutable config); per-call engine bits covered by /27 tests |
| 9 | SE_EPHE_PATH honored as default ephe path | Inverted — v2 reads no env vars (row 9) |
| 10 | version() returns compat baseline "2.10.03" | Inverted — no version() method (row 10) |
| 12 | Views detach via copy-on-write, never free unowned handles | Dead problem class — Arc refcounting (row 13) makes all instances co-equal |

## Seed-time verification (2026-07-05, re-seed)

Live constraints: **0** (all sutra-expressible claims deferred — no code
exists, so any glob would be inert). rules.toml parses; the deferred blocks
are commented under their `# TRIGGER:` lines. The scaffold task (/21)
acceptance criterion is that the at-scaffold blocks uncomment cleanly and
every glob binds (no `dead_constraint` warnings).

## Scaffold binding verification (2026-07-07, /21)

Live constraints: **6** (rows 3, 6, 7, 17). All globs bind ≥1 file, 0
violations. Platform-seam constraint (row 7) is expressible in sutra's Dart
import resolution — no fallback to bucket (c) needed. Remaining deferred:
row 18 (fan-in, at R1 tend /25).

## R1 tend verification (2026-07-07, /25)

Live constraints: **7** (rows 3, 6, 7, 17, 18). All globs bind, 0
violations. Row 18 (fan-in) fired: threshold=8 from observed max=5.
Stated-vs-actual diff: all verifiable claims confirmed, no drift.
Convention triage: 6 pending proposals dismissed (Dart language tautologies).
No new emergent-structure constraints needed at this codebase size.

## R2 tend verification (2026-07-08, /35)

Live constraints: **7** (rows 3, 6, 7, 17, 18). All globs bind, 0
violations. Row 18 (fan-in) tightened: threshold 8→7 (~40% headroom over
observed max=5, unchanged from R1). Full API surface landed; no lib/src/
files expected from remaining tasks (/36–/39 are test-side).
Convention triage: 26 pending proposals dismissed (Dart language
tautologies — same class as R1's 6). No new emergent-structure constraints
needed; 5-component decomposition stable.
Stated-vs-actual diff: all verifiable claims confirmed, no drift.

## R3 verification (2026-07-08, /40)

Live constraints: **7** (rows 3, 6, 7, 17, 18). All globs bind, 0
violations. Row 18 (fan-in) raised: threshold 7→12. Observed max=11
(flags.dart); structural fan-in from foundational types — every module
imports flags, result, and config.
Orphaned triggers: **0** — no `# TRIGGER:` blocks remain in rules.toml.
Enforcement ledger: all 22 rows routed. Row 22 (arjuna migration) pending
on arjuna/arrow/10. Oracle-map: 8 engine-trusted entries audited, all
reasons honest. Test suite: 307/307 pass (excluding stress).

## Maintenance

- **New track PRDs**: re-run vidhi-sutra-seed additively — append rows and
  constraints with their own provenance. Never regenerate from scratch.
  (Supersession per ADR is the one exception, as this re-seed demonstrates:
  retire rows explicitly with the ADR citation.)
- **Rebinding events**: at scaffold (/21) and each tend checkpoint (/25,
  /35), check off the corresponding rows' Status column here.
- **Guard from first commit**: blocking rules are live the moment their globs
  bind. Per-task `sutra_review` runs in vidhi-review; bucket-(c) rows are
  review-checklist material.
- **Tend schedule**: vidhi-sutra-tend runs at R1 (swisseph-rs-dart/25 —
  interiors + convention triage + initial fan-in) and R2 (swisseph-rs-dart/35
  — fan-in with full-surface data, re-triage). R3 (swisseph-rs-dart/40)
  verifies no orphaned triggers remain.
