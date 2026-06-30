# Swiss Ephemeris Dashboard — Design Spec

**Date:** 2026-03-24
**Status:** Approved
**Version scope:** v1 (swetest parity), v2 outlined

## Overview

A Flutter cross-platform application (desktop, web, mobile) that provides a complete graphical interface to every Swiss Ephemeris calculation. Pure astronomical values — no astrological interpretation. Doubles as a validation tool for the swisseph.dart library.

**Core principle:** If someone can do it with swetest, they can do it with this app — but with a graphical interface.

**Dependency:** swisseph.dart (published package, full API: 70+ methods wrapping the complete Swiss Ephemeris C library).

## Architecture

### Layout: Tabs + Command Palette

Two paths to every function:

1. **Tabs** — browse organized function groups. Primary navigation for common workflows.
2. **Command Palette** (Ctrl+K / Cmd+K) — search any function by name. Pin results to a persistent area below the tabs. Power-user path for validation and ad-hoc queries.

**Pinned results:** Results from the command palette or from any tab (via a pin icon on each result card) can be pinned to the persistent area below the tab content. Pinned results are **live** — they recalculate when the context bar changes (unless they have a per-panel override). Maximum 20 pinned items. Pins persist across tab navigation and, under Full persistence mode, across sessions. **Exception to override ephemerality:** per-panel overrides on pinned results are retained across tab navigation (unlike regular tab panel overrides which are cleared). This is because pinned results exist outside the tab lifecycle — they are persistent by definition, so their overrides must be too.

### Context Bar

A persistent bar at the top of the application providing shared global state. All calculation tabs draw from these values by default.

**Per-panel override:** Any result card or calculation panel can override a context bar value locally. A small "use local value" toggle appears next to the relevant field within the panel, revealing an inline input that replaces the global value for that panel only. Overrides are ephemeral — they do not affect other tabs and are cleared on tab navigation unless persistence is set to Full. An override indicator (e.g., a dot or highlight) shows which panels are using local values. This is essential for comparison workflows (e.g., checking the same date with two different locations side by side via pinned results).

| Field | Description | Input modes |
|-------|-------------|-------------|
| **Date** | Calendar date | Calendar entry, Julian Day direct, "Now" button |
| **Time** | Time value | UT, ET, UTC, LMT, LAT |
| **JD (UT)** | Julian Day number | Computed from date/time, or entered directly |
| **Location** | Longitude, latitude, altitude | Decimal coords, DMS, city search, device GPS |
| **Origin** | Coordinate origin | Geocentric, Heliocentric, Barycentric, Topocentric, Planetocentric |
| **Eq. Reference** | Equinoctial reference point | Tropical (vernal equinox), Sidereal (arbitrary point) |
| **Ayanamsa** | Sidereal reference offset | 48 methods (Lahiri, Fagan/Bradley, etc.) + user-defined. Only visible when Eq. Reference = Sidereal. User-defined requires: reference JD and initial ayanamsa value in degrees, entered inline when "User-defined (#255)" is selected from the dropdown. |
| **Ephe** | Ephemeris data source | Swiss Ephemeris, JPL, Moshier |

Additional context (collapsed by default via progressive disclosure):
- Calendar type: Gregorian / Julian (auto-selects at Oct 15, 1582)
- Computed readout: JD(UT), JD(ET), delta-T — always shown regardless of input mode
- JD and calendar date stay in sync — editing either updates the other

### Flag Bar

Displayed below the context bar on the following tabs: **Planets, Houses, Stars, Crossings, Table View, Nodes/Apsides, Coordinates, Phenomena, Differential**. Not shown on: Ayanamsa (has its own mode selector), Rise/Set (uses rsmi flags not iflag), Eclipses (uses eclipse type flags not iflag), Heliacal (has its own atmospheric/observer params), Dates (pure conversions, no flags), Math (no flags), Config (no flags).

**Mutually exclusive group** (radio behavior):
- **Output coordinates:** Ecliptic / Equatorial / XYZ

**Composable toggles** (checkbox behavior, ORed together):
- SPEED, TRUEPOS, NOABERR, NODEFL, NONUT, J2000, ICRS, JPLHOR, RADIANS, COB

**Computed flag** shown as: `SEFLG_SWIEPH | SEFLG_SPEED = 0x0102 (258)`

Note: Origin, Eq. Reference, and Ephe source are set in the context bar only (not duplicated in the flag bar), even though they map to flag bits internally. This keeps the flag bar focused on composable options.

## Tab Structure

### Primary Tabs (always visible)

| Tab | Functions | Description |
|-----|-----------|-------------|
| **Planets** | `calcUt`, `calc`, `getPlanetName` | Planetary positions. Body selector with multi-select chips and presets (classical, full, hypothetical, all). Expandable sections for asteroids by MPC number, planetary moons, fictitious bodies. |
| **Houses** | `houses`, `housesEx`, `housesEx2`, `housesArmc`, `housesArmcEx2`, `housePos`, `gauquelinSector`, `houseName` | House cusps for 25 systems. House position of planets. Gauquelin sectors. |
| **Ayanamsa** | `getAyanamsaUt`, `getAyanamsa`, `getAyanamsaExUt`, `getAyanamsaEx`, `getAyanamsaName` | Ayanamsa values. Compare mode for side-by-side comparison of methods. User-defined ayanamsa support. |
| **Rise/Set** | `riseTrans` | Rising, setting, meridian transit (upper/lower). Modifiers: disc center, disc bottom, no refraction, Hindu mode. Twilight types: civil, nautical, astronomical. Atmospheric parameters (pressure, temperature) in progressive disclosure. |
| **Eclipses** | `solEclipseWhenLoc`, `solEclipseWhenGlob`, `solEclipseHow`, `solEclipseWhere`, `lunEclipseWhen`, `lunEclipseWhenLoc`, `lunEclipseHow`, `lunOccultWhenLoc`, `lunOccultWhenGlob`, `lunOccultWhere` | Solar eclipses (local + global), lunar eclipses, lunar occultations. Type filters: total, partial, annular, hybrid, penumbral, central, non-central. Saros series output. Forward/backward search starting from the context bar date, with configurable result count N (default 10). |
| **Stars** | `fixstar2Ut`, `fixstar2`, `fixstar2Mag` | Fixed star positions and magnitudes. Search by name or catalog number. |
| **Crossings** | `solCrossUt`, `solCross`, `moonCrossUt`, `moonCross`, `moonCrossNodeUt`, `moonCrossNode`, `helioCrossUt`, `helioCross` | When a body crosses a given ecliptic longitude. Solar, lunar, and heliocentric variants. Moon node crossings. Search starts from the context bar date. |
| **Table View** | (uses any calculation function) | Time-stepping ephemeris table. Configure: bodies, step size (day/month/year/minute/second), row count, forward/backward. Column chooser maps to swetest's ~40 format characters (longitude, latitude, distance, speed, RA, declination, azimuth, altitude, house position, phase, magnitude, elongation, etc.). Scrollable table with export. |

### More Dropdown

| Tab | Functions | Description |
|-----|-----------|-------------|
| **Dates** | `julday`, `revjul`, `utcToJd`, `jdToUtc`, `jdetToUtc`, `utcTimeZone`, `dateConversion`, `dayOfWeek`, `deltat`, `deltatEx`, `timeEqu`, `sidTime`, `sidTime0`, `lmtToLat`, `latToLmt` | Date/time conversions. JD ↔ calendar, UTC, LMT, LAT, delta-T, sidereal time, equation of time. |
| **Coordinates** | `azAlt`, `azAltRev`, `cotrans`, `refrac`, `refracExtended` | Azimuth/altitude conversion, ecliptic ↔ equatorial, atmospheric refraction. |
| **Nodes/Apsides** | `nodApsUt`, `nodAps`, `getOrbitalElements`, `orbitMaxMinTrueDistance` | Mean + osculating nodes, apsides, orbital elements, orbit distance extremes. |
| **Heliacal** | `heliacalUt`, `heliacalPhenoUt`, `visLimitMag` | Heliacal rising/setting, evening first/morning last. Search starts from context bar date. Atmospheric conditions (pressure hPa, temperature °C, humidity %, meteorological range km). Observer parameters (age, Snellen ratio). Optical instrument config (monocular/binocular, magnification, aperture mm, transmission). |
| **Phenomena** | `phenoUt`, `pheno` | Phase angle, elongation, apparent magnitude, disc diameter, illuminated fraction. |
| **Differential** | `calcUt` + `difDeg2n` / `degMidp` | Two body pickers (Body A, Body B). Displays: longitude difference (shorter arc via `difDeg2n`), complement (longer arc), midpoint (via `degMidp`). v2 adds: midpoints in mod-16 (22°30') system. Both bodies share the same flags and date from the context bar — independent flag overrides per body are not supported. To compare bodies under different flag settings, use two pinned results with per-panel overrides instead. |
| **Math** | `degnorm`, `radNorm`, `degMidp`, `radMidp`, `splitDeg`, `difDegn`, `difDeg2n` | Degree normalization, splitting, midpoint, difference utilities. |
| **Config** | `setEphePath`, `setSidMode`, `setTopo`, `setJplFile`, `setInterpolateNut`, `setLapseRate`, `setDeltaTUserdef`, `setTidAcc`, `getTidAcc`, `getCurrentFileData`, `getLibraryPath`, `version`, `close` | Ephemeris configuration, library info, advanced settings. |

## Input Methods

### Date/Time

Three entry modes (toggle):
- **Calendar** — year, month, day, time fields. Calendar type: Gregorian/Julian (auto-selects at Oct 15, 1582, overridable).
- **Julian Day** — direct numeric JD entry.
- **Now** — current moment, auto-populates.

Time type selector: UT, ET, UTC, LMT, LAT. LMT and LAT require a location to be set.

### Location

Three entry modes (toggle):
- **Coordinates** — decimal degrees or DMS notation. Longitude, latitude, altitude (meters).
- **City Search** — type-ahead search against a city database.
- **Device GPS** — uses platform location services (mobile, desktop with GPS).

### Chart File Import

**Deferred to v1.1.** File format research is in progress. Chart file import will populate the context bar (date, time, location) from astrological chart files. Potential formats under investigation: AAF (Astro Exchange), QHP (Solar Fire), JHora, ADB XML, CSV. The UI scaffolding (drop zone on desktop/web, file picker on mobile) will be built in v1 but disabled until at least one format is fully specified. Missing fields (e.g., chart file has no altitude) will use sensible defaults (altitude = 0m, time type = UT).

## Output Methods

### Display Formats

Per-result-card toggle:
- **DMS** — degrees, minutes, seconds (3° 43' 42.2")
- **Decimal** — decimal degrees (3.7284°)
- **Raw** — exact C return values at full precision, no formatting. Essential for validation.

Each result card shows: function name, body ID, flag hex value.

### Export Formats

- **CSV** — for spreadsheets
- **JSON** — for programmatic use
- **Copy** — clipboard, tab-separated
- **stdout** — desktop-only, write to process stdout for terminal piping (v1 stretch goal, not applicable to web/mobile)

Available on individual result cards (copy single) and on the Table View (export full table).

### Table View Specifics

- Step size: day, month, year, minute, second (with numeric multiplier)
- Row count: configurable
- Direction: forward or backward
- Column chooser: toggle chips for each output column
- Horizontal mode: all selected bodies on one row per timestep

**Column-to-function mapping:**

| Column | Source function | Required context |
|--------|---------------|-----------------|
| Date, JD | `revjul` / context bar | date/time |
| Lon, Lat, Dist, Speed | `calcUt` | body, flags |
| RA, Dec | `calcUt` with SEFLG_EQUATORIAL | body, flags |
| Az, Alt | `azAlt` | body, location (from context bar) |
| House | `housePos` | body, house system, location |
| Phase, Elongation, Mag, Disc | `phenoUt` | body |
| Sidereal Time | `sidTime` | — |
| Delta-T | `deltat` | — |
| Ayanamsa | `getAyanamsaUt` | sid mode |

Columns requiring additional parameters (Az/Alt needs location, House needs house system) use the context bar values. If a required context value is not set, the column is greyed out in the chooser with a tooltip explaining what is needed.

## Responsive Layout

All breakpoints are in logical pixels (dp), not physical pixels.

### Desktop (1200dp+)
- Context bar: single row, all fields visible
- All tabs visible in tab bar
- 3-column result grid
- Flag bar fully expanded
- Pinned results visible below tabs

### Tablet (600–1199dp)
- Context bar: wraps to two rows
- Tabs scroll horizontally
- 2-column result grid
- Flag bar in progressive disclosure ("more options")
- Pinned results collapsible

### Mobile (< 600dp)
- Context bar: compact summary, tap to expand full editor
- Tabs as horizontally scrollable pill chips
- Single-column compact cards (body name + primary value left, secondary values right)
- Flags accessible via bottom sheet
- Command palette opens full-screen

## Progressive Disclosure

Every tab and panel follows the same pattern:
- Essential parameters visible by default (body, event type, etc.)
- "More options" expander reveals all parameters for the underlying function
- Advanced/rare parameters start collapsed
- User's expanded state is remembered (per persistence setting)

## Persistence

User-configurable with three levels:
- **Full** — save context bar values, expanded states, pinned results, last-used parameters per tab. Resume exactly where you left off.
- **Settings only** — persist preferences (ayanamsa, location, house system, theme) but start fresh with results and UI state.
- **Stateless** — always start from defaults.

## Theming

Multiple curated themes. Dark theme is the default (astronomical tools convention). Additional themes TBD — likely similar to gandiva's approach (Cosmic, Forest, Light or similar). Theme picker accessible from a settings icon in the app bar (top-right), alongside the persistence level setting.

## Technology

- **Framework:** Flutter (Dart)
- **Platforms:** Linux, macOS, Windows, Web, iOS, Android
- **Calculation engine:** swisseph.dart (published package, depends on Swiss Ephemeris C library compiled via native asset build hook)
- **State management:** TBD during implementation planning
- **Local storage:** TBD (shared_preferences, Hive, or similar for persistence)

## Version Scope

### v1 — Swetest Parity
- All tabs and functions listed above
- Manual input methods (calendar, JD, now, coordinates, city search, GPS)
- Display output (DMS, decimal, raw) + export (CSV, JSON, copy)
- Responsive layout for all platforms
- Multiple themes
- Configurable persistence
- Command palette
- Table View with time stepping

**v1 stretch goals** (may slip to v1.1):
- stdout export (desktop only)

### v1.1 — Chart Import
- Chart file import (formats finalized, UI scaffolding from v1 enabled)

### v2 — Extended Ephemeris
- JPL ephemeris file management and tests
- Extra ephemeris data from astro.com/swisseph/swepha_e.htm
- Midpoints in the 22°30' (mod 16) system
- Additional calculation modes from extended ephemeris files

## Open Questions

- Project name (unnamed)
- Chart file formats to support (Josh researching)
- City database source for location search
- State management approach (Riverpod, Bloc, Provider, etc.)
- Specific theme designs
