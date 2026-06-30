# Ephemeris Dashboard

A cross-platform Flutter GUI over the Swiss Ephemeris. It computes pure
astronomical values on demand — no interpretation — and can emit the equivalent
Swiss Ephemeris code (C, Dart) for any calculation it runs.

## Language

### Calculation context

**Context**:
The user-controlled global inputs that define *what instant, where, and in which
reference frame* to compute — a **Moment**, a **Location**, and the frame choices
(zodiac reference, origin, ephemeris source). This is what the context bar edits.
_Avoid_: effective context, calc context (implementation-level merges, not domain terms).

**Moment**:
The instant to compute for, canonically a **Julian Day** in Universal Time. The
single source of truth for "when." The **civil time** rendering (calendar date,
clock time, UTC offset) is a derived, advisory view — when civil and JD disagree,
JD wins; editing a civil field computes a new Moment.
_Avoid_: date, datetime, time (these name the advisory civil view, not the instant).

**Location**:
The observer point on Earth — latitude, longitude, and altitude — used for
topocentric calculations and as part of the **Context**.

**Applied Globals**:
The process-wide Swiss Ephemeris C state (ephemeris path, sidereal mode,
topocentric position, JPL file) set from the **Context** at calculation time. Named
because it is a hazard: this state is global and drifts across await points.
_Avoid_: globals, C state.

### Ephemeris and frame

**Ephemeris**:
The calculator — the abstraction that computes positions and phenomena for a
**Moment** under the **Applied Globals**. The Wave-1 seam is an `Ephemeris`
interface; the production adapter wraps the Swiss Ephemeris FFI object and records
calls, the test adapter is a fake.
_Avoid_: bare "ephemeris" for the data (that is the **Ephemeris Source**).

**Ephemeris Source**:
The data the **Ephemeris** computes from — Swiss precomputed files, Moshier
analytic, or JPL. Includes the file download-and-scan subsystem. Always qualified
with "source."
_Avoid_: ephemeris (unqualified).

**Zodiac Reference**:
The longitude zero-point frame — tropical, or sidereal with a chosen **Ayanamsa**.
(`ZodiacRef` in code.)

**Origin**:
The center the calculation is referred to — geocentric, topocentric (needs a
**Location**), heliocentric, or barycentric. (`Origin` in code.)

### Calculation and results

**Calculation**:
The live projection of **Results** from the **Context** — Results are a pure
function of the current Context and Flags, recomputed whenever either changes. No
"stale" or "out of sync" state exists by construction. There is no explicit
trigger (see ADR-0001).
_Avoid_: treating a Calculation as a discrete button press or a "compute now" event.

**Result**:
What a single tab produces from the current **Context** — its set of result fields
or rows. One tab yields one Result, always reflecting the current Context.

### Flags

**Flag**:
A single Swiss Ephemeris computation bit in the `iflag` bitfield (`SEFLG_*`).

**Locked Flag**:
A **Flag** derived from the **Context** — the sidereal, topocentric,
heliocentric/barycentric, and ephemeris-source bits. Not independently editable;
the context bar owns it and it renders locked. **Invariant: the set of Locked Flags
is a pure function of the Context** — one source of truth.
_Avoid_: auto-managed flag (the old name for this, maintained in two places).

**Toggle Flag**:
A **Flag** the user freely sets — speed, true position, no-nutation, J2000, etc.

The `iflag` for a **Calculation** is the selected coordinate-system flag (a
mutually-exclusive group), OR'd with the **Locked Flags**, OR'd with the
**Toggle Flags**.

### Charts

**Chart**:
Persisted birth/event data — a name, a **Moment**, a **Location**, and optional
metadata (gender, notes, Rodden rating). Fundamentally a convenient way to enter
time and place: loading a Chart *sets the Context's Moment and Location*, and the
dashboard recomputes everything from the **Ephemeris** rather than trusting any
positions stored in the file. The dashboard never holds a Chart as its own state.
_Avoid_: treating a Chart as the subject of computation — it is only an input source.

**Open Astrology Chart**:
The canonical interchange **Chart** format — a human-readable TOML file where the
**Moment** (`[moment].jd`) is the source of truth and civil fields are advisory.
The `charts_dart` library reads and writes this and seven other formats into one
`ChartData` model.

### Code emission

**Call Trace**:
The recorded sequence of Swiss Ephemeris calls made during a **Calculation** (each
call a `CallEntry`). The production **Ephemeris** adapter records it; it is sliceable
per tab. The raw material for code emission.

**Code Target**:
An output language for emitted code — currently C and Dart.

**Emitter**:
Renders a **Call Trace** (or a tab's slice of it) into source code for one **Code
Target**. One Emitter per Target.

**Symbol Catalog**:
The single source of truth mapping Swiss Ephemeris constants and functions (body
names, flag names, sidereal modes, call shapes) to their per-**Code Target**
renderings. The **Emitters** and the call recording derive from it rather than
re-listing symbols.

## Relationships

- A **Chart**, when loaded, sets the **Context**'s **Moment** and **Location**.
- A **Context** comprises a **Moment**, a **Location**, and frame choices
  (**Zodiac Reference**, **Origin**, **Ephemeris Source**).
- The **Context** determines the **Locked Flags** (pure function) and is set into the
  **Applied Globals** at calculation time.
- A **Calculation** projects the **Context** + **Flags** into one **Result** per tab,
  computed by the **Ephemeris** reading its **Ephemeris Source**.
- Each **Calculation** produces a **Call Trace**; an **Emitter** renders it into a
  **Code Target** using the **Symbol Catalog**.

## Example dialogue

> **Dev:** "When the user loads a `.chtk` **Chart**, do we keep its stored planet
> positions?"
> **Domain expert:** "No — a **Chart** is just a convenient way to enter time and
> place. We take its **Moment** and **Location** into the **Context** and recompute
> everything from the **Ephemeris**. Stored positions are ignored."
>
> **Dev:** "And if they then switch **Zodiac Reference** to sidereal?"
> **Domain expert:** "That flips a **Locked Flag**, which changes the **Context**, so
> every **Result** re-projects immediately. No button — the displayed values are
> never out of sync with the selected options."

## Flagged ambiguities

- "context" was used for three things along one pipeline — the raw user inputs,
  the inputs merged with flags, and the applied engine state. Resolved: **Context**
  is the input; **Applied Globals** is the engine state; the middle "effective"
  merge is not a named domain concept.
- The app was documented as having an "explicit Calculate button — calculations run
  on demand, not on every state change," but the real behavior is reactive: a tab
  activates once, then re-renders live on every Context change. Resolved: Results are
  a reactive projection of the Context; the button and activation gate are removed
  (ADR-0001). This supersedes Architecture Decision #1 in CLAUDE.md.
