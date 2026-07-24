# Code Review: swe_dashboard @ checkpoint b087532

**Date:** 2026-07-24
**Scope:** all of HEAD at `b087532` (branch `master`, tree clean) — checkpoint review after the series/calendar/time-scale/occultation/heliacal/rise-set arc
**Verdict:** continue with adjustments

## Verification

- Build: pass (`flutter analyze` — no issues)
- Tests: pass (279/279, includes real-engine parity tests and the layout invariants sweep)
- Lint: pass
- Format: clean (160 files, 0 would change)

## Design

The core architecture is in good shape and the governed invariants hold where I
could check them mechanically. **JD is canonical** is honored end to end: the
date/time/JD fields all commit through `setJd` after mapping scale-civil → UT1
(`JdUtils.localCivilToJdUt`), and the `Civil` record type (raw fields, not
`DateTime`) is a genuinely careful solution to the Julian-date normalization
trap — the doc comments explaining *why* (29 Feb 1900 must survive) are
exemplary. **Moment comes from the series step** holds structurally as claimed:
`runTabCalcSeries` is the only place the Context JD enters a series, computes
take `(Ephemeris, Moment)`, and even rise/set's tricky case (local-midnight
anchoring) keys off `moment.ut` with only the UTC offset as a deliberate,
documented Context input. **Locked Flags** are a single pure function
(`FlagBarState.lockedFlagsFrom`), and `package:swisseph_rs` imports are confined
to `lib/core/**` (verified by grep, 7 files, all core). The calculation kernel
(`run_tab_calc`, `SeriesSpec`, `calendar_step`) is the deep module the refactor
promised — pure, engine-free calendar math with floor-division correctness notes
is the kind of code that survives contact with users.

Where the design has a soft spot is exactly where the code-intel pack pointed:
**the flag surface between tabs and the engine has no owner.** Each call family
needs a different subset of `iflag` — eclipse/rise-trans functions want only the
ephemeris bits, heliacal wants ephemeris bits plus `HeliacalFlags`, the
horizontal/house-position feeds must be frame-of-date tropical — and each tab
hand-rolls its own mask (`& 0xF` in three places, one of which is wrong;
heliacal passes nothing at all; the meridian-distance RA feed strips no frame
bits). Four of the findings below are the same disease. The fix is small and
matches the house style: one `flag_masks.dart` in the kernel with named masks
(`epheMask`, `frameOfDateFlag`, …) and each recipe documenting which mask it
takes, the way `tropicalEclipticFlag` already does.

The second soft spot is the known one: cross-cutting features are hand-replicated
per tab. The series-provider block (`select` tuple → `read` → enabled gate →
`runTabCalcSeries`) is byte-identical in ~10 provider files; `describeBodyError`
was extracted to `body_utils` but the Planets tab still carries a private,
*diverged* copy. Nothing here is broken enough to pause the arc, but the
persistence finding below shows the cost model: co-change lockstep with no
round-trip test means a missed line is silent. That test is cheap and overdue —
`persistence.dart` has blast radius 102 and zero direct tests.

## Findings

```yaml
- id: heliacal-optical-params-never-applied
  severity: high
  category: correctness
  title: Heliacal optical-instrument inputs are silently ignored (OPTICAL_PARAMS flag never set)
  location: lib/core/ephemeris/rust_eph.dart:794, lib/tabs/heliacal/heliacal_provider.dart:49-58
  evidence: |
    RustEph.heliacalUt always passes `rs.HeliacalFlags.none`; swisseph_rs forwards
    `epheflag.value | helflag.value` straight to swe_heliacal_ut. The heliacal tab
    exposes Monocular/Binocular, Magnification, Aperture, Transmission (swetest
    -opt, dobs[2..5]) and passes them through ObserverConditions.
  why: |
    swe_heliacal_ut zeroes dobs[2..5] unless SE_HELFLAG_OPTICAL_PARAMS (512) is
    set in helflag. Every value the user enters in those four fields has no
    effect on the result — a silently inert feature that claims to be applied.
  recommendation: |
    Set `HeliacalFlags.opticalParams` whenever any optical field departs from the
    naked-eye defaults (or always — SE's own default_heliacal_parameters treats
    all-zero dobs as naked eye). Add a parity test against swetest -opt with a
    telescope configured. Alternative (worse): drop the four inputs.
  confidence: high

- id: persistence-restore-drops-projection-and-user-ut
  severity: high
  category: correctness
  title: userAyanT0IsUt and projection are saved and loaded but never restored
  location: lib/core/context_provider.dart:50-72
  evidence: |
    PersistenceService.saveContextBar writes ctx_user_ayan_t0_is_ut and
    ctx_sidereal_projection; loadContextBar puts both in the overrides map
    ('userAyanT0IsUt', 'projection'). restoreFromPersistence's copyWith call
    applies neither key — it stops at userAyanValue/epheSource.
  why: |
    A user who sets the sidereal projection plane (SE_SIDBIT_ECL_T0 / SSY_PLANE)
    or the user-defined-ayanamsha "t0 is UT" toggle loses it on every restart,
    silently — the engine sid_mode is rebuilt without those bits. This is exactly
    the silent persistence gap the co-change data (persistence ↔ context_state
    jaccard 0.60) predicts.
  recommendation: |
    Add the two missing copyWith arguments. Then add a round-trip test: build a
    ContextBarState with every field non-default, save, restore into a default
    state, assert equality field by field (jd/dateTime excepted). That test also
    pins finding jpl-filename-not-persisted.
  confidence: high

- id: horizontal-meridian-uses-frame-shifted-ra
  severity: high
  category: correctness
  title: Meridian distance (and J2000/no-nut leakage) uses RA in the wrong frame under sidereal / non-default equinox contexts
  location: lib/tabs/planets/planets_provider.dart:251-258,292 (same pattern in other_bodies_provider.dart, stars_provider.dart)
  evidence: |
    The RA fed to horizontalCoordsOf's meridian-distance formula
    (GMST*15 + lon − ra) comes from `calcUt(body, (iflag | seFlgEquatorial) & ~seFlgXyz)`
    — sidereal (65536), J2000 (32) and no-nut (64) bits pass through. Likewise
    tropicalEclipticFlag strips sidereal/XYZ/equatorial but not J2000/no-nut, so
    an EqRef of "Mean Equinox (J2000)" leaks a J2000 ecliptic position into
    SE_ECL2HOR and swe_house_pos.
  why: |
    With a sidereal Context (a first-class mode here), RA is measured from the
    sidereal zero point, so meridian distance is off by the ayanamsha (~24°).
    With EqRef = J2000, az/alt and house positions are computed from J2000
    coordinates against an ARMC/obliquity of date — a smaller but systematic
    error. The existing invariance test covers Ecliptic/Equatorial/XYZ display
    modes but not the sidereal or J2000 locked flags.
  confidence: medium
  recommendation: |
    Derive the RA feed with `tropicalEclipticFlag(iflag) | seFlgEquatorial` and
    widen tropicalEclipticFlag (or add a sibling `frameOfDateFlag`) to strip
    seFlgJ2000/seFlgNoNut for the horizontal and house-pos feeds. Extend
    planets_horizontal_invariance_test with sidereal and J2000 rows — az/alt and
    meridian distance are physical and must be invariant across all frame flags.

- id: eclipse-type-filter-ignored-in-local-scope
  severity: medium
  category: contract
  title: Eclipse type filter chips stay active in Local scope but never reach the engine
  location: lib/tabs/eclipses/eclipses_provider.dart:344-368,398-422,477-507; lib/tabs/eclipses/eclipses_tab.dart:110-150
  evidence: |
    eclFilter is passed to solEclipseWhenGlob / lunEclipseWhen / lunOccultWhenGlob
    only. The *WhenLoc calls take no eclType (the SE API has none), yet the
    Filter chip row renders in both scopes and keeps its selection.
  why: |
    User selects Filter=Total + Scope=Local and gets partial eclipses back with
    "Total" still highlighted — the UI claims a constraint the calculation does
    not apply.
  recommendation: |
    Hide (or disable with a tooltip) the filter row when scope == local. Client-
    side post-filtering by returnFlag is the alternative but changes the "next N
    events" semantics.
  confidence: high

- id: heliacal-ignores-context-ephemeris-source
  severity: medium
  category: correctness
  title: Heliacal tab never passes the Ephemeris Source flag, unlike its sibling search tabs
  location: lib/tabs/heliacal/heliacal_provider.dart:151-191, lib/core/ephemeris/rust_eph.dart:785
  evidence: |
    _heliacalCalcProvider watches contextBarProvider but not flagBarProvider, and
    heliacalUt is called with the default `flags = 0`; eclipses and rise_set both
    forward `flags.iflag & 0xF`. swe_heliacal_ut with no ephemeris bit defaults
    to SEFLG_SWIEPH internally.
  why: |
    With Context = Moshier or JPL, heliacal results quietly compute on Swiss
    files (or on Moshier via SE's file-missing fallback) — the one tab where the
    Ephemeris Source selector does nothing, and the "ΔT depends on ephemeris"
    tooltip promise breaks for this tab.
  recommendation: |
    Pass the locked ephemeris bits (see epheflag-mask finding for the shared
    mask) into heliacalUt's flags parameter, and watch flagBarProvider so source
    changes recompute.
  confidence: high

- id: epheflag-mask-0xf-includes-helctr
  severity: low
  category: correctness
  title: "`iflag & 0xF` as \"ephe source bits\" also captures SEFLG_HELCTR (bit 8)"
  location: lib/tabs/rise_set/rise_set_provider.dart:358,413; lib/tabs/eclipses/eclipses_provider.dart:194
  evidence: |
    seFlgJplEph|seFlgSwiEph|seFlgMosEph = 0x7, but three sites mask with 0xF —
    which includes seFlgHelCtr = 8 — under the comment "low bits: ephe source".
    A heliocentric Origin therefore ORs SEFLG_HELCTR into the ifl argument of
    riseTrans and the eclipse searches.
  why: |
    Swiss Ephemeris masks ifl down to SEFLG_EPHMASK inside these functions today,
    so no observable bug — but the app-side mask is wrong by name and one engine
    version away from mattering. This is the same bit-mapping trap the recent
    rsmi/method fixes cleaned up elsewhere.
  recommendation: |
    Add `const epheMask = seFlgJplEph | seFlgSwiEph | seFlgMosEph;` to
    swe_constants (or the proposed flag_masks.dart) and replace all three sites.
  confidence: high

- id: jd-field-invalid-entry-silently-kept
  severity: low
  category: contract
  title: JD field neither reverts nor flags an unparseable entry, diverging from the just-fixed date/time pattern
  location: lib/widgets/context_bar/context_jd_field.dart:59-70
  evidence: |
    `_commit`: `if (entered == null) return;` — the bad text stays in the field
    and no snackbar is shown. Commit b087532 gave the date and time fields
    revert-plus-explain behaviour for exactly this case.
  why: |
    After a typo (e.g. "2460000.5.5" — the formatter permits multiple dots) the
    field displays a value that is not the Moment, the failure mode the invalid-
    entry work set out to kill.
  recommendation: |
    Mirror the date-field pattern: _sync() to revert, snackbar when non-empty.
    Consider allowing '-' in the formatter while at it (negative JDs are inside
    the picker's own -4000 range).
  confidence: high

- id: jpl-filename-not-persisted
  severity: low
  category: correctness
  title: epheSource=JPL survives restart but the chosen JPL file does not
  location: lib/core/persistence.dart:28-46, lib/core/ephemeris/runner.dart:50-71
  evidence: |
    saveContextBar has no ctx_jpl_filename entry; on restart appliedGlobalsProvider
    falls back to "first installed JPL file" from the scan.
  why: |
    A user with de406 and de440 installed who selected de440 may silently come
    back on de406 — differing results with no signal.
  recommendation: |
    Persist jplFilename alongside epheSource; the round-trip test from the
    persistence finding pins it.
  confidence: medium

- id: series-provider-boilerplate-replicated
  severity: medium
  category: design
  title: The series-provider block is copy-pasted across ~10 tabs (possible Shotgun Surgery)
  location: lib/tabs/*/[tab]_provider.dart (planets:404-419, phenomena:112-127, dates:268-279, nodes_apsides:127-144, rise_set:442-457, …)
  evidence: |
    `ref.watch(seriesSettingsProvider(id).select((s) => (s.enabled, s.stepValue,
    s.stepUnit, s.rowCount))); final settings = ref.read(...); if (!settings.enabled)
    return const []; return runTabCalcSeries(...)` appears near-verbatim in every
    migrated tab; the select-tuple (which fields trigger recompute) is a policy
    decision maintained in ten places.
  why: |
    The next series-shape field (e.g. a future "step anchor" option) needs ten
    synchronized edits, and a missed one is a silent per-tab divergence — the
    lockstep co-change pattern the health data already shows.
  recommendation: |
    Extract `List<(Moment, CalcOutcome<T>)> seriesFor<T>(Ref ref, String tabId,
    T Function(Ephemeris, Moment) Function(Ref) computeFactory)` into the kernel;
    each tab's series provider becomes one line. Ayanamsa keeps its overrides
    variant.
  confidence: high

- id: dates-tab-render-ignores-context-calendar
  severity: low
  category: correctness
  title: Dates tab renders and parses civil dates on Gregorian regardless of the Context Calendar
  location: lib/tabs/dates/dates_provider.dart:148, lib/tabs/dates/dates_tab.dart:48,68,147
  evidence: |
    computeDates calls swe.revjul(jdUt) with the default gregorian:true, and the
    tab's own date-entry fields use dateTimeToJd/jdToDateTime without passing
    ctx.calendar — while the context bar renders the same Moment calendar-aware.
  why: |
    With Calendar = Julian (or auto, pre-1582) the context bar shows 29 Feb 1500
    (Julian) while the Dates tab's Calendar card shows the Gregorian rendering of
    the same JD with no label saying so — two different dates for one Moment.
  recommendation: |
    Thread ctx.calendar into computeDates' revjul and the tab's entry fields; or,
    if showing the Gregorian date deliberately, label the card "Gregorian".
  confidence: medium

- id: series-apply-outside-outcome-envelope
  severity: low
  category: correctness
  title: runTabCalcSeries does not catch SweException from runner.apply, unlike the card path
  location: lib/core/calculation/run_tab_calc.dart:76,105 vs 26-31
  evidence: |
    _runTabCalc wraps runner.apply(globals) in try/on SweException → CalcError;
    the two series variants call runner.apply bare, so an engine-rebuild failure
    propagates out of the provider.
  why: |
    If reconfigure ever throws (bad ephe path/JPL config), card tabs degrade to
    an error card while series tabs take down the provider subtree — an
    inconsistent failure contract for the same fault.
  recommendation: |
    Wrap the series-side apply and return a single-row CalcError series (or an
    empty list) on SweException.
  confidence: low
```

## Synthesis

Three root causes explain almost everything above.

**1. No owned flag surface (findings: heliacal-optical, heliacal-ephe-source,
epheflag-mask, horizontal-meridian).** Every engine call family re-derives "which
bits of `iflag` do I forward" locally, and four of them got it wrong in four
different ways. Fix as one unit: add `flag_masks.dart` to the kernel with
`epheMask` and a `frameOfDateFlag` (superset of `tropicalEclipticFlag` that also
strips J2000/no-nut), route heliacal through it *and* through
`HeliacalFlags.opticalParams`, and extend the horizontal invariance test with
sidereal + J2000 rows. That test extension is the keystone — it converts the
medium-confidence meridian finding into a fact before you change anything.

**2. Persistence round-trips are asymmetric and untested (findings:
persistence-restore, jpl-filename).** One ~5-line fix plus one round-trip test
closes both and inoculates every future `ContextBarState` field. Do this first;
it is the smallest and most user-visible.

**3. Per-tab replication (findings: series-boilerplate, dates-calendar,
eclipse-filter; slop items 2-4).** The kernel absorbed the compute path but the
provider/UI glue is still copied by hand, and the copies are already diverging
(planets' private `_describeBodyError` lost the satellite-file branch the shared
one has). Extract the series-provider helper when convenient; fix the two UI
contract holes (eclipse filter in local scope, Dates-tab calendar) as ordinary
small tickets.

Suggested order: (1) persistence fix + round-trip test, (2) heliacal flags
(optical + ephe source together, one adapter + one provider), (3) flag-mask
module + frame-bit fix with the extended invariance test, (4) eclipse-filter and
JD-field UX consistency, (5) series-provider extraction and slop batch. Items
1-2 are afternoon-sized; item 3 needs a swetest parity check before and after.

## Slop list

Feature-arc slop (all confirmed by direct evidence, not the sutra dead list):

1. `lib/core/context_state.dart:39` — `ContextBarState.dateTime` is write-only:
   maintained by four setters (`setJd`, `setNow`, `setCalendar`, `loadFromChart`),
   read nowhere. `ContextBarNotifier.setDateTime` (context_provider.dart:78) has
   no callers, and `JdUtils.removeUtcOffset` (jd_utils.dart:147) is likewise
   uncalled. The raw-civil-fields refactor (7ec0754) obsoleted all three — remove
   the field, the setter, and the helper together (equality/hash shrink too).
2. `lib/tabs/planets/planets_provider.dart:521` — private `_describeBodyError`
   duplicates `body_utils.describeBodyError` minus the planet-moon branch; a
   moon-file error in the Planets tab loses its download hint. Delete the private
   copy, import the shared one.
3. `lib/core/swe_service_io.dart:132` / `swe_service_stub.dart:31` —
   `_listEpheAssets` is duplicated across the conditional-import pair (io's
   version also carries a hardcoded fallback list). Both only need
   flutter/services; extract to a shared file.
4. `lib/tabs/rise_set/rise_set_provider.dart:171-180,483` — card export renders
   times via `RiseSetDateTime.formatted()` (hardcoded Gregorian "… UT") while the
   tab's screen render uses `formatJdDateTime` with the clock view; an export no
   longer matches the screen once scale/calendar/clock are non-default. Route the
   export through `formatJdDateTime` and retire `RiseSetDateTime`.
5. `lib/tabs/eclipses/eclipses_provider.dart:334 vs 466` — solar-global passes
   `localNoonJd: g.localNoon` unwrapped while occultation-global wraps the same
   field in `_nonZero`; a zero localNoon renders as JD 0 in one mode and is
   omitted in the other.

Pack-filter feedback: the `sutra_dead` caveat in 20-code-intel is correct — the
symbols I confirmed dead above were found by grep, not by the dead list, and the
dead list's widget-private entries I spot-checked (`build` callees, state
helpers) are live. No new false-positive class to add.
