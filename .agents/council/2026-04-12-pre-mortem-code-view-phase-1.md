---
id: pre-mortem-2026-04-12-code-view-phase-1
type: pre-mortem
date: 2026-04-12
source: "[[.agents/plans/2026-04-12-code-view-phase-1]]"
mode: quick (inline, single-agent)
scope_mode: hold
prediction_ids:
  - pm-20260412-001
  - pm-20260412-002
  - pm-20260412-003
  - pm-20260412-004
  - pm-20260412-005
  - pm-20260412-006
  - pm-20260412-007
  - pm-20260412-008
  - pm-20260412-009
---

# Pre-Mortem: Code View Feature, Phase 1

## Council Verdict: WARN

Three significant findings must be resolved before `/implement`. Six moderate findings should be addressed in the plan text or acknowledged as accepted risks. The plan is fundamentally sound — the architecture (wrapper + Riverpod provider + emitter) is right. The issues are concrete details that will cause either rework or broken integrations if left unresolved.

| ID | Judge | Finding | Severity | Prediction |
|----|-------|---------|----------|------------|
| pm-20260412-001 | feasibility | `class SwissEph` is concrete with `late final` private FFI fields; `implements SwissEph` is legal in Dart but requires satisfying all 89 methods or the analyzer rejects the file | significant | A2 "implements SwissEph" blocked by analyzer errors for the 44 unused methods |
| pm-20260412-002 | feasibility | Plan specifies "forward all 45 methods" but doesn't define a pattern for the 44 unused methods; "throw UnimplementedError" produces silent future crashes | significant | Future tab adds `calc()` or `housesEx()`; app crashes in production; debugged by guesswork |
| pm-20260412-003 | missing-requirements | `CallEntry.cardKey` + `CallCategory.calc` alone is not enough to identify "THE calc call" for a card — `getPlanetName(body)` also runs during calc scope and appears in trace | significant | `forCard(body).lastOrNull` returns `getPlanetName` entry instead of `calcUt`; C emitter generates wrong C line |
| pm-20260412-004 | missing-requirements | `EffectiveContext.calculate` receives `SwissEph swe` typed param; `(swe as TracingSwissEph).setScope(...)` throws when production uses a non-tracing path (e.g., tests with a mock) | moderate | Tests substituting a `MockSwissEph` crash at runtime; masking the real failure |
| pm-20260412-005 | scope | Phase 1 pilots only the planets tab — every other tab's `ResultCard` still exists and will display a disabled C button (or worse, an enabled button with no trace). UX is incoherent | moderate | User loads houses tab, sees C button, clicks, gets empty modal or stale trace |
| pm-20260412-006 | spec-completeness | Button label `Text('C')` inside `IconButton` is unusual; Material conventions prefer `Icons.code` or `Icons.terminal`. Plan doesn't justify text choice | moderate | Designer pushback during review; rework the button |
| pm-20260412-007 | temporal (Hour 4) | 54 golden tests × 3 sizes × 2 themes will regenerate after A9. Visual-review burden is high; easy to rubber-stamp a regression | moderate | A genuine layout regression slips past golden regeneration because reviewer accepted the bulk diff |
| pm-20260412-008 | missing-requirements | `setEphePath` runs once during provider construction, *before* any Calculate press. The trace recorded at construction time is visible to every subsequent card's snippet. Plan doesn't clarify whether snippet mode includes this or not | moderate | Snippet shows bare `swe_calc_ut(...)` with no setEphePath preamble; C code is not runnable without additional context |
| pm-20260412-009 | test pyramid | No L2 integration test planned. Wrapper + provider + planets provider have only L1 units and a manual smoke test between them | moderate | A3/A4/A10 regression slips through because each unit test passes in isolation |

## Shared Findings

- The 45-method count (research) and 89-method surface (swisseph.dart 0.4.4) are in tension in the plan: A2 says "forward all 45 methods", but `implements SwissEph` demands 89. This needs to be one consistent story.
- "Disabled until first calc" from the design doc translates cleanly in A9 (`trace == null`), but only for planets cards in Phase 1. Every other tab's cards will either be disabled forever (until Phase 2) or broken. Phase 1 should hide the button entirely on non-pilot tabs.

## Known Risks Applied

None — no compiled pre-mortem checks or findings registry present in this repo.

## Concerns Raised

### Significant (must address before /implement)

**S1 — SwissEph interface shape (pm-001, pm-002).**
`class SwissEph` is concrete with private FFI state. `implements SwissEph` forces the analyzer to require all 89 public methods. Recommended fix:

- Use `implements SwissEph` + `noSuchMethod` forwarding for unused methods:
  ```dart
  class TracingSwissEph implements SwissEph {
    final SwissEph _inner;
    final CallTrace _sink;
    CallCategory _scope = CallCategory.calc;
    Object? _cardKey;

    TracingSwissEph(this._inner, this._sink);

    @override
    dynamic noSuchMethod(Invocation inv) =>
        Function.apply(_inner.noSuchMethod, [inv]);

    @override
    CalcResult calcUt(double jdUt, int body, int flags) {
      final r = _inner.calcUt(jdUt, body, flags);
      _sink.entries.add(CallEntry(
        name: 'calcUt', args: [jdUt, body, flags],
        result: r, category: _scope, cardKey: _cardKey));
      return r;
    }
    // … 44 more typed overrides for the methods we want to record
  }
  ```
  The 44 unused swe methods silently forward through `noSuchMethod` → `_inner.noSuchMethod(inv)`. No UnimplementedError trap; no hand-written stubs. Loses type safety for the 44, but they're unused — a tab adding one will fail loudly the first time because Dart static analysis still sees the interface and recompiles with a typed override.

  Revise A2 acceptance criteria: "implements SwissEph, 45 methods have typed overrides that record, remaining methods forward via noSuchMethod."

**S2 — cardKey + method-name tagging (pm-003).**
`CallTrace.forCard(body)` returns every calc-scope entry with that cardKey, which in the planets flow includes `getPlanetName(body)`. Fix:

- Either: emitter receives `forCard(body).where((e) => e.name == 'calcUt').first`.
- Or: set cardKey only on the *primary* call. Change A10 to:
  ```dart
  (swe as TracingSwissEph).setScope(category: calc, cardKey: null);  // metadata scope
  final name = swe.getPlanetName(body);
  (swe as TracingSwissEph).setScope(category: calc, cardKey: body);  // headline scope
  final r = swe.calcUt(ectx.jdUt, body, flags);
  ```
  Cleaner: introduce a `CallCategory.metadata` (already in the enum draft in Implementation #1) and use it for `getPlanetName`. Then `forCard` filters out metadata automatically.

### Moderate (address in plan revision)

**M1 — cast safety (pm-004).** Wrap `setScope` calls in a helper: `void _markScope(SwissEph swe, {required CallCategory category, Object? cardKey}) { if (swe is TracingSwissEph) swe.setScope(...); }`. Non-tracing paths no-op instead of crashing. Tests become trivial.

**M2 — Phase 1 button visibility (pm-005).** Hide the C button on non-pilot tabs. Add a param `bool codeViewEnabled = false` to `ResultCard` (or derive from `trace != null`). Only planets tab passes `codeViewEnabled: true` in Phase 1. Design doc should be updated to reflect this progressive rollout.

**M3 — button icon (pm-006).** Decision: `Icons.code` (looks like `</>`) is the Material convention and is less ambiguous than the text "C". Plan should be updated to use it. Revisit when multi-language picker ships in Phase 3 — then the label matters.

**M4 — golden tests (pm-007).** Add a protocol step to A9: before regenerating, `git diff test/goldens/` should be inspected for only the action-row area. If any non-action-row pixel differs, investigate before accepting.

**M5 — setEphePath in snippet (pm-008).** Phase 1 explicitly emits snippet mode only — one line. Decision needed: does the C snippet include a preamble comment `// Assumes swe_set_ephe_path("…") has been called` or is it just the `swe_calc_ut` line? Lean: add a single-line comment preamble. Program mode (Phase 2) supersedes this.

**M6 — L2 integration test (pm-009).** Add to plan: `test/integration/trace_pipeline_test.dart` that spins up a real `ProviderContainer`, reads `sweProvider` + `traceProvider`, presses a synthetic calculate on the planets provider, asserts trace has a `calcUt` entry with `cardKey == SE_SUN`. This is the one test that proves A3+A4+A10 are glued correctly.

## Error & Rescue Map

No external APIs in Phase 1. Only I/O:

| Method | What Can Go Wrong | Rescued? | Rescue Action | User Sees |
|--------|-------------------|----------|---------------|-----------|
| `Clipboard.setData` (A8) | Platform clipboard unavailable / permission denied | Currently: no | Try/catch → show SnackBar "Copy failed" | Silent failure |
| `showDialog` (A8) | Widget tree disposed mid-click | Dart: auto-handled | — | None |
| `swe.calcUt` via wrapper (A2) | Underlying C call returns error code | Current app already handles | Unchanged | Unchanged |

Recommendation: add clipboard rescue to A8 acceptance criteria. Trivial. Worth the polish.

## Test Coverage Gaps

| Issue | L0 | L1 | L2 | L3 | Finding |
|-------|----|----|----|----|---------|
| A1 (types) | — | A14 covers maps; types themselves are data classes | — | — | OK — data class |
| A2 (wrapper) | — | A12 | M6 gap | — | Add L2 |
| A3 (provider) | — | — | M6 gap | — | Add L2 |
| A4 (context) | — | A12 extension | M6 gap | — | Add L2 |
| A5 (constants) | — | A14 | — | — | OK |
| A6 (flag decompose) | — | A13 | — | — | OK |
| A7 (emitter) | — | A11 | — | — | OK — pure function |
| A8 (modal) | — | — | Golden test | — | OK — UI |
| A9 (button) | — | — | Golden test | — | OK — UI |
| A10 (planets wiring) | — | — | M6 gap | Manual smoke | Add L2 |

Net add: one L2 integration test (`trace_pipeline_test.dart`), covered by M6.

## Timeline Risks

| Phase | Risk | Mitigation |
|-------|------|-----------|
| Hour 1 (A1, A5, A8 setup) | Low — isolated new files | Proceed |
| Hour 2 (A2 wrapper) | **High** — implements SwissEph interface shape. If S1 wrong, re-architect | Resolve S1 before starting A2 |
| Hour 4 (A3+A4 integration) | Medium — cast safety; trace lifecycle | M1 helper prevents cast failures |
| Hour 6+ (A9 goldens) | Medium — bulk golden review fatigue | M4 diff-review protocol |
| Hour 8+ (A10 wiring) | Medium — cardKey precision (S2) | Resolve S2 in A10 spec before implementing |

## Scope Check (HOLD SCOPE posture)

Plan is already minimum-viable. No scope reduction recommended. However, the pilot-tab-only rollout (M2) is implicit in the plan — make it explicit so workers don't accidentally wire the C button on non-planet tabs and create half-broken states.

## Recommendation

**ADDRESS before /implement.** Three significant findings (S1, S2) have concrete fixes that fit within the existing plan structure. Six moderate findings are plan-text clarifications (M1–M6), not architecture changes.

Action items for plan update:

1. Revise A2 acceptance criteria and Implementation #2 to specify `implements SwissEph + noSuchMethod` (S1, S2).
2. Revise A10 and Implementation #10 to use distinct scopes for metadata vs. headline calls (S3).
3. Add M1 helper spec to Implementation #4 (cast safety).
4. Add M2 `codeViewEnabled` param to Implementation #9 and acceptance criteria on A9.
5. Change button label to `Icons.code` in Implementation #9 (M3).
6. Add M4 golden-diff protocol note to A9's verification.
7. Clarify M5 snippet preamble comment in Implementation #7.
8. Add L2 integration test as Issue A15 (M6).
9. Add clipboard try/catch + SnackBar to A8.

After these edits, re-check the plan and proceed to `/implement` (starting with A1 and A5 in parallel — Wave 1).

## Decision Gate

- [ ] PROCEED — Council passed, ready to implement
- [x] ADDRESS — Fix concerns before implementing
- [ ] RETHINK — Fundamental issues, needs redesign
