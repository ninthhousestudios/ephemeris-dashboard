# Binding implementation patterns

Patterns and gotchas learned while building the positions family (/27).
Every binding task (/28–/34) follows the same layered architecture.

## Layer sequence

Build bottom-up — each layer depends on the one below:

1. **bindings_native.dart** — `@Native` FFI declarations matching
   `api-surface.md` C ABI signatures. No logic. Add the corresponding
   stub in **bindings_web.dart** (returns `_unsupported()`).
2. **marshal.dart** — arena-scoped FFI call wrapper. Allocates output
   buffers, calls the binding, checks the error code via `_checkResult`,
   unmarshals the result into a typed Dart object.
3. **ephemeris.dart** — thin method: `_checkOpen()`, delegate to marshal,
   return result. Every method needs a `/// Counterpart:` dartdoc line.
4. **oracle.dart** — add Oracle methods that call swisseph.dart. The oracle
   is stateful: sidereal/topo require set-then-call with `finally` reset.
5. **oracle_map.dart** — register every new public method. Use `direct` for
   1:1 oracle calls, `composite` for set-then-call sequences,
   `engineTrusted` when no oracle equivalent exists (with reason string).
6. **Differential tests** — compare swisseph-rs output against oracle output
   using `ComparisonSpec` with typed agreement classes.
7. **Totality verification** — run `totality_test.dart` to ensure Counterpart
   declarations and oracle-map entries are complete.

## Agreement classes

- **bitwise** — exact floating-point equality (pure math, no engine)
- **positional** — 1e-9° tolerance (default for positions and speeds)
- **boundary** — wider tolerance, requires `tolerance` + `boundaryArtifact`
  naming the documented swisseph-rs discrepancy source. Known artifacts:
  - SPEED3 (3-point numeric differentiation): tolerance 1e-7. Auto-enabled
    when SPEED+TOPOCTR+!NOABERR, or when the SPEED3 flag is set explicitly.
  - Deflection speed: 1e-7° (gravitational light deflection speed term)
  - Moshier osculating node speed: 5e-6°/day
  - Moshier osculating node position: 5e-5° (True Node), up to 1e-4° for
    outer planets (Saturn+). Position accumulates more error than speed;
    tolerance scales with orbital period.
  - Moshier star precession: 5e-6° (precession model differences between
    Moshier and Swiss ephemeris for fixed-star positions)
  - Moshier star parallax distance: 1e-3 AU (parallax distance precision
    limited by Moshier's simplified stellar distance model)
  - Moshier visibility model: 5e-6 (heliacal visibility magnitude
    differences from Moshier's simplified atmospheric model)
  - Search-derived occultation geometry: 1e-6° (iterative search uncertainty
    propagates into geometry attributes of occultation events)
  - Planetocentric subtraction amplification: 1e-8° (calcPctr subtracts two
    positions, amplifying FP rounding in both the Rust and C paths)
- **search** — iterative event-finding; tolerance per-algorithm

When a speed field exceeds positional tolerance, check whether the flag
combination triggers SPEED3 before loosening — that's the most common cause.

## Oracle statefulness

swisseph.dart's `SwissEph` is stateful (global C library state). Methods
like `setSidMode`, `setTopo` persist until explicitly reset.

Pattern for sidereal oracle calls:
```dart
_swe.setSidMode(sidMode, t0: t0, ayanT0: ayanT0);
try {
  final result = _swe.calcUt(jdUt, body, flags | swe.seFlgSidereal);
  return OracleCalcResult._fromSwe(result);
} finally {
  _swe.setSidMode(0);
}
```

Topo calls use `setTopo` — this state is also sticky but currently the
oracle does not reset it (no `setTopo(0,0,0)` in `finally`). Acceptable
because topo state only matters when TOPOCTR flag is set, and each topo
test sets its own values before calling. But if tests start interfering,
add a reset.

For composite mappings needing both sidereal + topo, the Oracle class
methods don't compose cleanly. The sidereal+topo combined test in
calc_test.dart works around this by directly calling `SwissEph.find()`
and managing both states manually.

## Moshier limitations

Several features require Swiss or JPL ephemeris files and will throw on
Moshier-only config:

- `CalcFlags.baryctr` → `UnsupportedFlagsException`
- `calcPctr` → `CErrorException` (planetocentric is internally barycentric)
- Asteroid calculations for undeclared MPC numbers →
  `EphemerisNotAvailableException`
- Fixed star functions → need `sefstars.txt`

When a feature can't be tested positively without ephemeris files, either:
- Gate the test on `SWE_EPHE_PATH` env var (see `ephemeris_test.dart`)
- Test the rejection path and use `engineTrusted` oracle-map entry

Ephemeris files are available at `ephe/` (symlink to `../swisseph-rs/ephe`).
To run Swiss-file tests: `SWE_EPHE_PATH=ephe dart test`

## Config marshaling duplication

`calcUtWithConfig` and `calcWithConfig` both marshal geopos/sidMode from
`EphemerisConfig` — the code is duplicated between the two marshal
functions. Project constraint: 2 copies is fine, extract a helper at 3.
Tasks /28–/34 may add `*WithConfig` variants that push this to 3+ copies,
at which point extract a shared `_marshalPerCallOverrides` helper.

## Flag constant naming (oracle side)

swisseph.dart constant names don't always match the Dart CalcFlags names:
- `CalcFlags.topoctr` → `swe.seFlgTopoCtr` (capital C)
- `CalcFlags.dpsideps1980` → `swe.seFlgJplHor` (different name entirely)
- `CalcFlags.helctr` → `swe.seFlgHelCtr`
- `CalcFlags.baryctr` → `swe.seFlgBaryCtr`

Always check `../swisseph.dart/lib/src/constants.dart` for the oracle
constant name before writing tests.
