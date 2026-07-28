# swisseph-rs public API surface

Extracted from rev `14a1df683525dfbecff213e546c64f5d54331ba3` of
ninthhousestudios/swisseph-rs. This is the transliteration source of truth —
every public Dart symbol mirrors exactly one entry here.

Scope note: the crate's re-exported public API (`src/lib.rs` `pub use` list)
is what matters for transliteration — it is what a downstream consumer of
`swisseph` actually sees. Several `pub mod`s (`calc`, `moshier`, `corrections`,
`fictitious`, `topocentric`, `precession`, `nutation`, `obliquity`, `bias`,
`sidereal_time`, `deltat`, `constants`) are technically reachable
(`swisseph::calc::plaus_iflag`, etc.) but are pipeline internals — the
crate's own module docs say "prefer `Ephemeris` methods". They are excluded
below except where an internal helper is the *only* place a documented
behavior lives (noted inline). The Dart bindings additionally do not call
this Rust API at all — they call the C ABI in `swisseph-ffi`, covered in its
own section at the end.

---

## Types (→ lib/src/types/, task /23)

All in `src/types.rs` unless noted.

### Newtypes (validated body IDs)

```rust
pub struct FictitiousId(i32); // private inner field; range 40–999 (SE_FICT_OFFSET + index)
impl FictitiousId {
    pub fn new(raw_id: i32) -> crate::Result<Self>;   // validates 40..=999
    pub fn raw_id(self) -> i32;
}

pub struct AsteroidId(i32); // private inner field; MPC number >= 0 (SE_AST_OFFSET + mpc_number)
impl AsteroidId {
    pub fn new(mpc_number: i32) -> crate::Result<Self>;  // validates >= 0
    pub fn mpc_number(self) -> i32;
}

pub struct PlanetMoonId(i32); // private inner field; encoded 0–999 (SE_PLMOON_OFFSET + encoded)
impl PlanetMoonId {
    pub fn new(encoded: i32) -> crate::Result<Self>;  // validates 0..=999
    pub fn encoded(self) -> i32;
}
```
All three: `#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]` (+ serde behind feature).

### `Body`

```rust
pub enum Body {
    Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto,
    MeanNode, TrueNode, MeanApogee, OscuApogee, Earth,
    Chiron, Pholus, Ceres, Pallas, Juno, Vesta,
    IntpApogee, IntpPerigee,
    Fictitious(FictitiousId),
    Asteroid(AsteroidId),
    PlanetMoon(PlanetMoonId),
    EclipticNutation,
}
```
Raw C IDs: `Sun`=0 … `Pluto`=9, `MeanNode`=10, `TrueNode`=11, `MeanApogee`=12,
`OscuApogee`=13, `Earth`=14, `Chiron`=15, `Pholus`=16, `Ceres`=17, `Pallas`=18,
`Juno`=19, `Vesta`=20, `IntpApogee`=21, `IntpPerigee`=22, `EclipticNutation`=-1.
`Fictitious`/`Asteroid`/`PlanetMoon` map through their newtype + crate offset
constants (`FICT_OFFSET`, `AST_OFFSET`, `PLMOON_OFFSET`).

```rust
impl Body {
    pub fn fictitious(raw_id: i32) -> crate::Result<Self>;
    pub fn asteroid(mpc_number: i32) -> crate::Result<Self>;
    pub fn planet_moon(encoded: i32) -> crate::Result<Self>;
    pub fn to_raw_id(self) -> i32;
}
impl TryFrom<i32> for Body { type Error = crate::Error; fn try_from(v: i32) -> Result<Self, Self::Error>; }
```
`#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]` (+ serde behind feature).

### `FictitiousBody` (named companion for `Body::Fictitious`, IDs 40–58)

```rust
#[repr(i32)]
pub enum FictitiousBody {
    Cupido = 40, Hades = 41, Zeus = 42, Kronos = 43, Apollon = 44, Admetos = 45,
    Vulkanus = 46, Poseidon = 47, Isis = 48, Nibiru = 49, Harrington = 50,
    NeptuneLeverrier = 51, NeptuneAdams = 52, PlutoLowell = 53, PlutoPickering = 54,
    Vulcan = 55, WhiteMoon = 56, Proserpina = 57, Waldemath = 58,
}
impl From<FictitiousBody> for Body { fn from(f: FictitiousBody) -> Self; }
impl TryFrom<i32> for FictitiousBody { type Error = crate::Error; fn try_from(v: i32) -> Result<Self, Self::Error>; }
```

### `HouseSystem`

```rust
pub enum HouseSystem {
    Equal, Alcabitius, Campanus, EqualMC, Carter, Gauquelin, Horizon, Sunshine,
    SunshineAlt, SavardA, Koch, PullenSD, Morinus, EqualAries, Porphyry, Placidus,
    PullenSR, Regiomontanus, Sripati, PolichPage, KrusinskiPisaGoelzer, Vehlow,
    WholeSign, Meridian, APC,
}
impl HouseSystem {
    pub fn to_char(self) -> u8;         // 'A'..'Y' single-char C house-system code
    pub fn name(self) -> &'static str;  // human-readable name
}
impl TryFrom<u8> for HouseSystem { type Error = crate::Error; fn try_from(v: u8) -> Result<Self, Self::Error>; }
// 'E' also maps to Equal on the TryFrom<u8> path (alias).
```
Char codes: Equal=`A`, Alcabitius=`B`, Campanus=`C`, EqualMC=`D`, Carter=`F`,
Gauquelin=`G`, Horizon=`H`, Sunshine=`I`, SunshineAlt=`i`, SavardA=`J`,
Koch=`K`, PullenSD=`L`, Morinus=`M`, EqualAries=`N`, Porphyry=`O`, Placidus=`P`,
PullenSR=`Q`, Regiomontanus=`R`, Sripati=`S`, PolichPage=`T`,
KrusinskiPisaGoelzer=`U`, Vehlow=`V`, WholeSign=`W`, Meridian=`X`, APC=`Y`.

### `CalendarType`

```rust
#[repr(i32)]
pub enum CalendarType { Julian = 0, Gregorian = 1 }
impl TryFrom<i32> for CalendarType { type Error = crate::Error; fn try_from(v: i32) -> Result<Self, Self::Error>; }
```

### `SiderealMode` (47 variants, `SE_SIDM_*`)

```rust
#[repr(i32)]
pub enum SiderealMode {
    FaganBradley = 0, Lahiri = 1, DeLuce = 2, Raman = 3, Ushashashi = 4,
    Krishnamurti = 5, DjwhalKhul = 6, Yukteshwar = 7, JnBhasin = 8,
    BabylKugler1 = 9, BabylKugler2 = 10, BabylKugler3 = 11, BabylHuber = 12,
    BabylEtpsc = 13, Aldebaran15Tau = 14, Hipparchos = 15, Sassanian = 16,
    GalCent0Sag = 17, J2000 = 18, J1900 = 19, B1950 = 20, Suryasiddhanta = 21,
    SuryasiddhantaMsun = 22, Aryabhata = 23, AryabhataMsun = 24, SsRevati = 25,
    SsCitra = 26, TrueCitra = 27, TrueRevati = 28, TruePushya = 29,
    GalCentRgilbrand = 30, GalEquIau1958 = 31, GalEquTrue = 32, GalEquMula = 33,
    GalAlignMardyks = 34, TrueMula = 35, GalCentMulaWilhelm = 36,
    Aryabhata522 = 37, BabylBritton = 38, TrueSheoran = 39, GalCentCochrane = 40,
    GalEquFiorenza = 41, ValensMoon = 42, Lahiri1940 = 43, LahiriVp285 = 44,
    KrishnamurtiVp291 = 45, LahiriIcrc = 46,
    User = 255,
}
impl SiderealMode {
    pub fn name(self) -> Option<&'static str>; // None only for User
}
impl TryFrom<i32> for SiderealMode { type Error = crate::Error; fn try_from(v: i32) -> Result<Self, Self::Error>; }
```
(See source for the full human-readable name string per variant — every
variant except `User` has one, e.g. `Lahiri` → `"Lahiri"`,
`Aldebaran15Tau` → `"Babylonian/Aldebaran = 15 Tau"`.)

### `EphemerisSource`

```rust
pub enum EphemerisSource { Jpl, Swiss, Moshier }
```

### `FileDataKind` / `FileData`

```rust
#[repr(i32)]
pub enum FileDataKind {
    Planet = 0, Moon = 1, MainAsteroid = 2,
    Asteroid = 3,   // Ephemeris::file_data always returns None for this kind (stateless)
    PlanetMoon = 4, // same
}
impl TryFrom<i32> for FileDataKind { type Error = crate::Error; fn try_from(v: i32) -> Result<Self, Self::Error>; }

pub struct FileData {
    pub path: std::path::PathBuf,
    pub start_jd: f64,
    pub end_jd: f64,
    pub denum: i32,
}
```

### Astronomical model enums (`swe_set_astro_models` replacement)

```rust
#[repr(i32)]
pub enum PrecessionModel {
    IAU1976 = 1, Laskar1986 = 2, WillEpsLask = 3, Williams1994 = 4, Simon1994 = 5,
    IAU2000 = 6, Bretagnon2003 = 7, IAU2006 = 8, Vondrak2011 = 9, Owen1990 = 10,
    Newcomb = 11,
}

#[repr(i32)]
pub enum NutationModel {
    IAU1980 = 1, IAUCorr1987 = 2, IAU2000A = 3, IAU2000B = 4, Woolard = 5,
}
// IAU2000B is the crate default.

#[repr(i32)]
pub enum DeltaTModel {
    StephensonMorrison1984 = 1, Stephenson1997 = 2, StephensonMorrison2004 = 3,
    EspenakMeeus2006 = 4, StephensonEtc2016 = 5,
}
// StephensonEtc2016 is the crate default.

#[repr(i32)]
pub enum SiderealTimeModel {
    IAU1976 = 1, IAU2006 = 2, IersConv2010 = 3, Longterm = 4,
}
// Longterm is the crate default.

#[repr(i32)]
pub enum BiasModel { None = 1, IAU2000 = 2, IAU2006 = 3 }
// IAU2006 is the crate default.

#[repr(i32)]
pub enum JplHorMode { LongAgreement = 1 }

#[repr(i32)]
pub enum JplHoraMode { V1 = 1, V2 = 2, V3 = 3 }
// V3 is the crate default.

pub struct AstroModels {
    pub delta_t: DeltaTModel,
    pub prec_longterm: PrecessionModel,
    pub prec_shortterm: PrecessionModel,
    pub nutation: NutationModel,
    pub bias: BiasModel,
    pub jplhor_mode: JplHorMode,
    pub jplhora_mode: JplHoraMode,
    pub sidereal_time: SiderealTimeModel,
}
impl Default for AstroModels {
    // delta_t: StephensonEtc2016, prec_longterm/prec_shortterm: Vondrak2011,
    // nutation: IAU2000B, bias: IAU2006, jplhor_mode: LongAgreement,
    // jplhora_mode: V3, sidereal_time: Longterm
    fn default() -> Self;
}
```

### Frame/precession direction enums (no C constant — pure Rust ergonomics)

```rust
pub enum FrameTransform { J2000ToGcrs, GcrsToJ2000 }
pub enum PrecessionDirection { J2000ToDate, DateToJ2000 }
```

### `Epsilon` / `Nutation` (small value structs)

```rust
pub struct Epsilon { pub eps: f64, pub sin_eps: f64, pub cos_eps: f64 }
impl Epsilon { pub fn new(eps_rad: f64) -> Self; } // precomputes sin/cos

pub struct Nutation { pub dpsi: f64, pub deps: f64 } // radians
```

### Julian Day newtypes

```rust
pub struct JdTt(pub f64);   // TT (Terrestrial Time) Julian Day
pub struct JdUt1(pub f64);  // UT1 Julian Day
// impl Add<f64>, Sub<f64> (Output = Self), and Sub<Self> (Output = f64) for both,
// via the impl_jd_ops! macro.
```

### UTC types

```rust
pub struct UtcComponents {
    pub year: i32, pub month: i32, pub day: i32,
    pub hour: i32, pub minute: i32, pub second: f64, // second allows up to 60.999... for leap seconds
}

pub struct UtcToJd { pub tt: JdTt, pub ut1: JdUt1 }
```

### `DeltaT` trait

```rust
pub trait DeltaT {
    fn delta_t(&self, jd_ut: JdUt1) -> f64; // days
}
// impl DeltaT for Ephemeris (in context.rs): delegates to crate::deltat::calc_deltat(jd_ut.0, &self.config)
```

### `DegreeParts` (`swe_split_deg` output)

```rust
pub struct DegreeParts {
    pub degrees: i32,          // whole degrees, or zodiac sign index if ZODIACAL flag set
    pub minutes: i32,          // 0-59
    pub seconds: i32,          // 0-59
    pub second_fraction: f64,  // fractional arc-second remainder
    pub sign: i32,             // 0=positive,1=negative, or zodiac sign number
}
```

---

## Flags (→ lib/src/types/flags.dart, task /23)

All in `src/flags.rs`, built with the `bitflags!` macro (`u32` storage,
`Debug, Clone, Copy, PartialEq, Eq, Hash` + serde behind feature).

```rust
pub struct CalcFlags: u32 {
    const JPLEPH        = 1;
    const SWIEPH        = 2;
    const MOSEPH        = 4;
    const HELCTR        = 8;        // forces NOABERR | NOGDEFL
    const TRUEPOS       = 16;
    const J2000         = 32;
    const NONUT         = 64;
    const SPEED3        = 128;      // auto-set when SPEED+TOPOCTR+!NOABERR
    const SPEED         = 256;
    const NOGDEFL       = 512;
    const NOABERR       = 1024;
    const EQUATORIAL    = 2048;
    const XYZ           = 4096;
    const RADIANS       = 8192;
    const BARYCTR       = 16384;    // forces NOABERR | NOGDEFL; Swiss/JPL only
    const TOPOCTR       = 32768;    // bit-aliased as SEFLG_ORBEL_AA in orbital-element context
    const SIDEREAL      = 65536;
    const ICRS          = 131072;
    const DPSIDEPS_1980 = 262144;   // C: SEFLG_JPLHOR
    const JPLHOR_APPROX = 524288;
    const CENTER_BODY   = 1048576;
    // combos:
    const ASTROMETRIC   = Self::NOABERR.bits() | Self::NOGDEFL.bits();
    const DEFAULTEPH    = Self::SWIEPH.bits();
}

pub struct SiderealBits: u32 {
    const ECL_T0         = 256;
    const SSY_PLANE      = 512;
    const USER_UT        = 1024;
    const ECL_DATE       = 2048;
    const NO_PREC_OFFSET = 4096;
    const PREC_ORIG      = 8192;
}

/// NOTE: appears unused/dead in the crate — the actually-exported
/// method-selector type for Ephemeris::nod_aps is `nodaps::NodApsMethod`
/// (an independently-declared bitflags struct with an identical bit layout:
/// MEAN=1, OSCU=2, OSCU_BAR=4, FOPOINT=256). NodeBits is `pub` inside `pub mod
/// flags` but is never re-exported from lib.rs and never referenced anywhere
/// else in the crate. Prefer `NodApsMethod` for the Dart transliteration.
pub struct NodeBits: u32 {
    const MEAN     = 1;
    const OSCU     = 2;
    const OSCU_BAR = 4;
    const FOPOINT  = 256;
}

pub struct EclipseFlags: u32 {
    const CENTRAL           = 1;
    const NONCENTRAL        = 2;
    const TOTAL             = 4;
    const ANNULAR           = 8;
    const PARTIAL           = 16;
    const HYBRID            = 32;    // C: SE_ECL_ANNULAR_TOTAL
    const PENUMBRAL         = 64;
    const VISIBLE           = 128;
    const MAX_VISIBLE       = 256;
    const PARTBEG_VISIBLE   = 512;
    const TOTBEG_VISIBLE    = 1024;
    const TOTEND_VISIBLE    = 2048;
    const PARTEND_VISIBLE   = 4096;
    const PENUMBBEG_VISIBLE = 8192;
    const PENUMBEND_VISIBLE = 16384;
    // Same bits, different meaning by call-site context (lunar-eclipse vs. occultation):
    const OCC_BEG_DAYLIGHT  = 8192;   // == PENUMBBEG_VISIBLE
    const OCC_END_DAYLIGHT  = 16384;  // == PENUMBEND_VISIBLE
    const ONE_TRY           = 32768;
    // masks:
    const ALLTYPES_SOLAR = CENTRAL|NONCENTRAL|TOTAL|ANNULAR|PARTIAL|HYBRID;
    const ALLTYPES_LUNAR = TOTAL|PARTIAL|PENUMBRAL;
}

pub struct RiseSetFlags: u32 {
    const RISE              = 1;
    const SET               = 2;
    const MTRANSIT          = 4;
    const ITRANSIT          = 8;
    const GEOCTR_NO_ECL_LAT = 128;
    const DISC_CENTER       = 256;
    const NO_REFRACTION     = 512;
    const CIVIL_TWILIGHT    = 1024;
    const NAUTIC_TWILIGHT   = 2048;
    const ASTRO_TWILIGHT    = 4096;
    const DISC_BOTTOM       = 8192;
    const FIXED_DISC_SIZE   = 16384;
    const FORCE_SLOW        = 32768;
    // combo:
    const HINDU_RISING = DISC_CENTER | NO_REFRACTION | GEOCTR_NO_ECL_LAT;
}

pub struct SplitDegFlags: u32 {
    const ROUND_SEC  = 1;
    const ROUND_MIN  = 2;
    const ROUND_DEG  = 4;
    const ZODIACAL   = 8;
    const KEEP_SIGN  = 16;
    const KEEP_DEG   = 32;
    const NAKSHATRA  = 1024;
}

pub struct HeliacalFlags: u32 {
    const LONG_SEARCH     = 128;
    const HIGH_PRECISION  = 256;
    const OPTICAL_PARAMS  = 512;
    const NO_DETAILS      = 1024;
    const SEARCH_1_PERIOD = 2048;
    const VISLIM_DARK     = 4096;
    const VISLIM_NOMOON   = 8192;
    const VISLIM_PHOTOPIC = 16384;
    const VISLIM_SCOTOPIC = 32768;
    const AV              = 65536;    // also == AVKIND_VR
    const AVKIND_VR       = 65536;
    const AVKIND_PTO      = 131072;
    const AVKIND_MIN7     = 262144;
    const AVKIND_MIN9     = 524288;
    // mask:
    const AVKIND = AVKIND_VR | AVKIND_PTO | AVKIND_MIN7 | AVKIND_MIN9;
}

pub struct VisLimFlags: u32 {
    const SCOTOPIC = 1;
    const MIXED    = 2;
}
```

`NodApsMethod` (declared in `src/nodaps.rs`, re-exported from crate root) is
the true method-selector for `nod_aps`/`nod_aps_ut` — see the Ephemeris
phenomena/orbital section below.

---

## Config (→ lib/src/types/config.dart, task /23)

`src/config.rs`.

```rust
pub struct TopoPosition {
    pub longitude: f64, // degrees, east-positive
    pub latitude: f64,  // degrees, north-positive
    pub altitude: f64,  // meters above sea level
}
// Derives: Debug, Clone, Copy (+ serde behind feature).

pub struct EphemerisConfig {
    pub ephemeris_source: EphemerisSource,      // default: Moshier
    pub ephe_path: Option<PathBuf>,             // required for Swiss/Jpl
    pub jpl_filename: Option<String>,           // default "de441.eph" when None
    pub sidereal_mode: Option<SiderealMode>,
    pub sidereal_t0: f64,                       // reference epoch (JD, TT unless sidereal_t0_is_ut)
    pub sidereal_ayan_t0: f64,                  // initial ayanamsa at sidereal_t0, degrees
    pub sidereal_bits: SiderealBits,
    pub sidereal_t0_is_ut: bool,
    pub topographic: Option<TopoPosition>,
    pub astro_models: AstroModels,
    pub tidal_acceleration: Option<f64>,        // None = auto-derive from ephemeris DE number
    pub delta_t_userdef: Option<f64>,           // days; bypasses all Delta T models when Some
    pub extra_leap_seconds: Vec<i32>,
    pub leap_seconds_file: Option<PathBuf>,
    pub asteroid_numbers: Vec<i32>,             // MPC numbers whose .se1 files to open
    pub planet_moon_numbers: Vec<i32>,          // raw ids 9401-9999 (or 9n99 COB) to open
}
// Derives: Debug, Clone (+ serde behind feature).
impl Default for EphemerisConfig { fn default() -> Self; } // see field defaults above

// impl block in ayanamsa.rs:
impl EphemerisConfig {
    pub fn set_sidereal_mode(&mut self, sid_mode: i32, t0: f64, ayan_t0: f64);
    // sid_mode bits 0-7 select a built-in ayanamsa index; remaining bits are SiderealBits
    // modifiers. sid_mode & 0xFF == 255 selects a caller-supplied (t0, ayan_t0) zero point.
    // Port of swe_set_sid_mode.
}
```

---

## Error (→ lib/src/types/exception.dart, task /23)

`src/error.rs`. `pub enum Error`, `#[derive(Debug)]`, implements `std::fmt::Display` +
`std::error::Error`.

```rust
pub enum Error {
    InvalidBody(i32),
    UnsupportedFlags(CalcFlags),
    InvalidHouseSystem(u8),
    InvalidSiderealMode(i32),
    InvalidCalendarType(i32),
    InvalidDate { year: i32, month: i32, day: f64 },
    EphemerisNotAvailable { body: Body, source: EphemerisSource },
    BeyondEphemerisLimits { jd_tt: f64, start: f64, end: f64 },
    FileNotFound(PathBuf),
    FileFormat(String),
    CircumpolarBody,
    InvalidTime { hour: i32, minute: i32, second: f64 }, // second may be up to 61 (leap sec)
    InvalidLeapSecond { year: i32, month: i32, day: i32 },
    UnsupportedEphemeris(EphemerisSource),
    SiderealModeRequiresFixedStars(SiderealMode),
    NoConvergence, // iterative search (e.g. a crossing refinement) did not converge
    CError(String), // catch-all, ported from C's string-buffer error reporting
}
```

Crate-root alias: `pub type Result<T> = std::result::Result<T, Error>;` (in `lib.rs`).

---

## Ephemeris — lifecycle (→ lib/src/ephemeris.dart, task /22)

All in `src/context.rs`, `impl Ephemeris`. `Ephemeris` holds read-only config
+ opened files; every method takes `&self` (no `&mut self` anywhere);
`Send + Sync` by construction (no mutable state, no caching).

```rust
pub struct Ephemeris { /* private fields: config, user_tidal_acceleration, leap_seconds,
                          planet/moon/asteroid/planet_moon files (feature-gated),
                          jpl_file (feature-gated), stars, fictitious_catalog */ }

impl Ephemeris {
    #[doc(alias = "swe_set_ephe_path")] // + swe_set_topo, swe_set_sid_mode, etc. (constructor consolidates all swe_set_* calls)
    pub fn new(config: EphemerisConfig) -> crate::Result<Self>;
    // Opens configured .se1/JPL files, loads star + fictitious-planet catalogs,
    // resolves tidal_acceleration from the opened file's DE number if unset.

    pub fn config(&self) -> &EphemerisConfig;

    pub fn effective_config<'a>(
        &self, flags: CalcFlags, config: &'a EphemerisConfig,
    ) -> std::borrow::Cow<'a, EphemerisConfig>;
    // Resolves per-call effective config when flags request a different ephemeris
    // source than configured; clamps to what's actually loaded (Jpl→Swiss→Moshier
    // fallback cascade) and adjusts tidal_acceleration accordingly.

    pub fn leap_seconds(&self) -> &[i32];
}

impl DeltaT for Ephemeris {
    fn delta_t(&self, jd_ut: JdUt1) -> f64; // delegates to crate::deltat::calc_deltat
}
```

### `CalcResult`

```rust
#[derive(Clone, Copy)]
pub struct CalcResult {
    pub data: [f64; 6],       // position [0..3] + speed [3..6] (layout depends on flags)
    pub flags_used: CalcFlags, // flags actually applied (detect fallbacks by comparing to requested)
}
```

---

## Ephemeris — positions (→ task /27)

```rust
#[doc(alias = "swe_calc")]
pub fn calc(&self, jd_tt: f64, body: Body, flags: CalcFlags) -> Result<CalcResult, Error>;

pub fn calc_with_config(
    &self, jd_tt: f64, body: Body, flags: CalcFlags, config: &EphemerisConfig,
) -> Result<CalcResult, Error>;
// calc() with a per-call config override (e.g. different topographic position)
// without constructing a new Ephemeris.

#[doc(alias = "swe_calc_ut")]
pub fn calc_ut(&self, jd_ut: f64, body: Body, flags: CalcFlags) -> Result<CalcResult, Error>;

pub fn calc_ut_with_config(
    &self, jd_ut: f64, body: Body, flags: CalcFlags, config: &EphemerisConfig,
) -> Result<CalcResult, Error>;

#[doc(alias = "swe_calc_pctr")]
pub fn calc_pctr(
    &self, jd_tt: f64, body: Body, center: Body, flags: CalcFlags,
) -> Result<CalcResult, Error>;
// Planetocentric position of `body` as seen from `center`. Swiss/JPL only
// (Moshier and body==center both error). Strips HELCTR/BARYCTR from flags internally.

#[doc(alias = "swe_fixstar2")]
pub fn fixstar2(&self, star: &str, jd_tt: f64, flags: CalcFlags) -> Result<(String, CalcResult), Error>;
// star searched case-insensitively; returns (canonical_name = "traditional,bayer", result).

pub fn fixstar2_with_config(
    &self, star: &str, jd_tt: f64, flags: CalcFlags, config: &EphemerisConfig,
) -> Result<(String, CalcResult), Error>;

#[doc(alias = "swe_fixstar2_ut")]
pub fn fixstar2_ut(&self, star: &str, jd_ut: f64, flags: CalcFlags) -> Result<(String, CalcResult), Error>;

#[doc(alias = "swe_fixstar2_mag")]
pub fn fixstar2_mag(&self, star: &str) -> Result<(String, f64), Error>;
// Catalog-file lookup only (built-in reference stars unavailable via this fn).
```

---

## Ephemeris — houses (→ task /28)

```rust
#[doc(alias = "swe_houses")]
pub fn houses(
    &self, tjd_ut: f64, geolat: f64, geolon: f64, hsys: HouseSystem,
) -> Result<HouseResult, Error>;
// == houses_ex2(tjd_ut, CalcFlags::empty(), geolat, geolon, hsys)

#[doc(alias = "swe_houses_ex")]
pub fn houses_ex(
    &self, tjd_ut: f64, flags: CalcFlags, geolat: f64, geolon: f64, hsys: HouseSystem,
) -> Result<HouseResult, Error>;
// == houses_ex2(...) (speeds always included)

#[doc(alias = "swe_houses_ex2")]
pub fn houses_ex2(
    &self, tjd_ut: f64, flags: CalcFlags, geolat: f64, geolon: f64, hsys: HouseSystem,
) -> Result<HouseResult, Error>;
// Supports SIDEREAL, NONUT, RADIANS flags.

pub fn get_orbital_elements(&self, tjd_et: f64, body: Body, flags: CalcFlags) -> Result<OrbitalElements, Error>;
// (listed here for cross-reference; see Ephemeris — phenomena & orbital below)
```

### `HouseResult` / `AscMc` (`src/houses.rs`)

```rust
pub struct AscMc {
    pub ascendant: f64,
    pub mc: f64,
    pub armc: f64,
    pub vertex: f64,
    pub equatorial_ascendant: f64,
    pub coascendant_koch: f64,
    pub coascendant_munkasey: f64,
    pub polar_ascendant: f64,
}
impl AscMc {
    pub fn as_array(&self) -> [f64; 8]; // same order as C's ascmc[]
}

pub struct HouseResult {
    pub cusps: [f64; 37],       // index 0 unused, 1..=36 populated per house system
    pub cusp_speeds: [f64; 37], // degrees/day, same indexing
    pub ascmc: AscMc,
    pub ascmc_speeds: AscMc,    // degrees/day
}
```
Both derive `Debug, Clone[, Copy for AscMc]` (+ serde behind feature).

### Free functions in `src/houses.rs` (not `Ephemeris` methods)

```rust
pub fn houses_armc(
    armc: f64, geolat: f64, eps: f64, hsys: HouseSystem, sundec: Option<f64>,
) -> Result<HouseResult, Error>;
// Port of swe_houses_armc_ex2: cusps + angular points + their ARMC-finite-difference speeds.

pub fn sidereal_houses_trad(
    armc: f64, geolat: f64, eps: f64, hsys: HouseSystem, sundec: Option<f64>, ayanamsa: f64,
) -> Result<HouseResult, Error>;
// Tropical houses via houses_armc, then every cusp/ascmc entry (except armc) shifted by ayanamsa.

pub fn sidereal_houses_ecl_t0(
    tjde: f64, armc: f64, eps: f64, nutlo: [f64; 2], lat: f64, hsys: HouseSystem,
    sundec: Option<f64>, t0: f64, ayan_t0: f64, models: &AstroModels,
) -> Result<HouseResult, Error>;
// Sidereal houses projected onto the ecliptic of the ayanamsa epoch t0. Port of swehouse.c:318-403.

pub fn sidereal_houses_ssypl(
    tjde: f64, armc: f64, eps: f64, nutlo: [f64; 2], lat: f64, hsys: HouseSystem,
    sundec: Option<f64>, t0: f64, ayan_t0: f64, models: &AstroModels,
) -> Result<HouseResult, Error>;
// Sidereal houses projected onto the solar-system invariable plane. Port of swehouse.c:425-532.

pub fn house_pos(
    armc: f64, geolat: f64, eps: f64, hsys: HouseSystem, xpin: [f64; 2], sundec: Option<f64>,
) -> Result<f64, Error>;
// Inverse problem: (armc, geolat, eps, hsys, xpin=[ecl.lon, ecl.lat]) -> continuous house
// position 1.0..13.0. Port of swe_house_pos (swehouse.c:2216-2876).
```

---

## Ephemeris — ayanamsa (→ task /29)

```rust
#[doc(alias = "swe_get_ayanamsa_ex")]
pub fn get_ayanamsa_ex(&self, jd_tt: f64, flags: CalcFlags) -> Result<f64, Error>;
// Nutation added unless NONUT set.

pub fn get_ayanamsa_ex_with_config(
    &self, jd_tt: f64, flags: CalcFlags, config: &EphemerisConfig,
) -> Result<f64, Error>;

#[doc(alias = "swe_get_ayanamsa_ex_ut")]
pub fn get_ayanamsa_ut(&self, jd_ut: f64, flags: CalcFlags) -> Result<f64, Error>;

#[doc(alias = "swe_get_ayanamsa")]
pub fn get_ayanamsa(&self, jd_tt: f64) -> Result<f64, Error>;
// Legacy accessor (no nutation), no flags param (internally CalcFlags::empty()).
```

Ayanamsa name is `SiderealMode::name(self) -> Option<&'static str>` (in
types.rs, above) — there is no separate free `get_ayanamsa_name` function in
this crate.

### Free functions in `src/ayanamsa.rs` (module-level, not `Ephemeris` methods)

```rust
pub fn get_ayanamsa_ex(
    config: &EphemerisConfig, jd_tt: f64, flags: CalcFlags, models: &AstroModels,
) -> Result<f64, Error>;
// Core computation, no nutation. Matches swi_get_ayanamsa_ex. (Ephemeris::get_ayanamsa
// calls this variant directly with CalcFlags::empty().)

pub fn get_aya_correction(config: &EphemerisConfig, flags: CalcFlags, models: &AstroModels) -> f64;
// Precession-model correction; 0 when not applicable.

pub fn get_ayanamsa_ex_nut(
    config: &EphemerisConfig, jd_tt: f64, flags: CalcFlags, models: &AstroModels,
) -> Result<f64, Error>;
// Public ayanamsa with nutation added (unless NONUT). Matches swe_get_ayanamsa_ex.

pub fn get_ayanamsa_with_speed(
    config: &EphemerisConfig, jd_tt: f64, flags: CalcFlags, models: &AstroModels,
) -> Result<[f64; 2], Error>;
// [ayanamsa_deg, speed_deg_per_day]. Matches swi_get_ayanamsa_with_speed.
```
(`AyaInit`, the `AYANAMSA` table, and `FIXED_STAR_INDICES` are `pub(crate)`,
not part of the public surface.)

---

## Ephemeris — eclipses & occultations (→ task /30)

All in `src/context.rs` `impl Ephemeris`, delegating to `pub(crate)` functions
in `src/eclipse.rs` (eclipse.rs itself has **no publicly-reachable free
functions or struct impls** — every entry point is an `Ephemeris` method).

```rust
#[doc(alias = "swe_sol_eclipse_where")]
pub fn sol_eclipse_where(&self, tjd_ut: f64, ifl: CalcFlags) -> Result<EclipseWhere, Error>;

pub fn eclipse_how_at(
    &self, tjd_ut: f64, ipl: Body, starname: Option<&str>, ifl: CalcFlags, geopos: [f64; 3],
) -> Result<EclipseHow, Error>;
// Raw local eclipse/occultation circumstances: no CENTRAL/NONCENTRAL merge, no
// redundant az/alt recompute, no horizon-visibility gate (bare internal eclipse_how).

#[doc(alias = "swe_sol_eclipse_how")]
pub fn sol_eclipse_how(&self, tjd_ut: f64, ifl: CalcFlags, geopos: [f64; 3]) -> Result<EclipseHow, Error>;

#[doc(alias = "swe_sol_eclipse_when_glob")]
pub fn sol_eclipse_when_glob(
    &self, tjd_start: f64, ifl: CalcFlags, ifltype: EclipseFlags, backward: bool,
) -> Result<SolarEclipseGlobal, Error>;

#[doc(alias = "swe_sol_eclipse_when_loc")]
pub fn sol_eclipse_when_loc(
    &self, tjd_start: f64, ifl: CalcFlags, geopos: [f64; 3], backward: bool,
) -> Result<SolarEclipseLocal, Error>;

#[doc(alias = "swe_lun_eclipse_how")]
pub fn lun_eclipse_how(&self, tjd_ut: f64, ifl: CalcFlags, geopos: [f64; 3]) -> Result<LunarEclipseHow, Error>;

#[doc(alias = "swe_lun_eclipse_when")]
pub fn lun_eclipse_when(
    &self, tjd_start: f64, ifl: CalcFlags, ifltype: EclipseFlags, backward: bool,
) -> Result<LunarEclipseGlobal, Error>;

#[doc(alias = "swe_lun_eclipse_when_loc")]
pub fn lun_eclipse_when_loc(
    &self, tjd_start: f64, ifl: CalcFlags, geopos: [f64; 3], backward: bool,
) -> Result<LunarEclipseLocal, Error>;

#[doc(alias = "swe_lun_occult_where")]
pub fn lun_occult_where(
    &self, tjd_ut: f64, body: Body, starname: Option<&str>, ifl: CalcFlags,
) -> Result<EclipseWhere, Error>;
// starname (non-empty) takes precedence over body.

#[doc(alias = "swe_lun_occult_when_glob")]
pub fn lun_occult_when_glob(
    &self, tjd_start: f64, body: Body, starname: Option<&str>, ifl: CalcFlags,
    ifltype: EclipseFlags, backward: bool,
) -> Result<OccultGlobal, Error>;

#[doc(alias = "swe_lun_occult_when_loc")]
pub fn lun_occult_when_loc(
    &self, tjd_start: f64, body: Body, starname: Option<&str>, ifl: CalcFlags,
    geopos: [f64; 3], backward: bool,
) -> Result<OccultLocal, Error>;

#[doc(alias = "swe_gauquelin_sector")]
pub fn gauquelin_sector_geometric(
    &self, t_ut: f64, body: Body, starname: Option<&str>, imeth: i32, flags: CalcFlags,
    geolon: f64, geolat: f64,
) -> Result<f64, Error>;
// imeth 0 = with ecliptic latitude, 1 = without. Sector 1.0-36.0.

#[doc(alias = "swe_gauquelin_sector")]
pub fn gauquelin_sector(
    &self, t_ut: f64, body: Body, starname: Option<&str>, flags: CalcFlags, imeth: i32,
    geopos: [f64; 3], atpress: f64, attemp: f64,
) -> Result<f64, Error>;
// Full dispatcher: imeth 0/1 -> geometric; imeth 2-5 -> rise/set-based method.
```

### Result types (`src/eclipse.rs`, all `#[derive(Debug, Clone, Copy)]` + serde behind feature; no impl blocks)

```rust
pub struct EclipseWhere {
    pub central_longitude: f64,
    pub central_latitude: f64,
    pub core_diameter_km: f64,             // signed: + annular, - or 0 total
    pub penumbra_diameter_km: f64,
    pub shadow_axis_distance_km: f64,
    pub umbra_diameter_fundamental_km: f64,
    pub penumbra_diameter_fundamental_km: f64,
    pub cos_umbra_half_angle: f64,
    pub cos_penumbra_half_angle: f64,
    pub flags: EclipseFlags,               // empty = no eclipse anywhere on Earth
}

pub struct EclipseHow {
    pub magnitude: f64,           // IMCCE convention
    pub diameter_ratio: f64,
    pub obscuration: f64,
    pub core_diameter_km: f64,    // 0.0 unless caller fills from EclipseWhere
    pub azimuth: f64,             // from south, clockwise via west
    pub true_altitude: f64,
    pub apparent_altitude: f64,
    pub elongation: f64,
    pub nasa_magnitude: f64,
    pub saros_series: f64,       // -99999999.0 if none found (Sun eclipses only)
    pub saros_member: f64,       // 1-based
    pub flags: EclipseFlags,
}

pub struct SolarEclipseGlobal {
    pub time_maximum: f64,
    pub time_ra_conjunction: f64,     // or 0.0
    pub time_begin: f64,
    pub time_end: f64,
    pub time_totality_begin: f64,     // 0.0 if partial
    pub time_totality_end: f64,
    pub time_centerline_begin: f64,   // 0.0 if noncentral
    pub time_centerline_end: f64,
    pub flags: EclipseFlags,          // never empty
}

pub struct SolarEclipseLocal {
    pub time_maximum: f64,
    pub time_first_contact: f64,
    pub time_second_contact: f64,  // 0.0 if only partial
    pub time_third_contact: f64,   // 0.0 if only partial
    pub time_fourth_contact: f64,
    pub time_sunrise: f64,         // 0.0 if none
    pub time_sunset: f64,          // 0.0 if none
    pub attr: EclipseHow,
    pub flags: EclipseFlags,       // never empty
}

pub struct LunarEclipseHow {
    pub umbral_magnitude: f64,
    pub penumbral_magnitude: f64,
    pub azimuth: f64,
    pub true_altitude: f64,
    pub apparent_altitude: f64,
    pub distance_from_opposition: f64,
    pub saros_series: f64,      // -99999999.0 if none found
    pub saros_member: f64,      // 1-based
    pub flags: EclipseFlags,    // empty, or exactly one of TOTAL/PARTIAL/PENUMBRAL
}

pub struct LunarEclipseGlobal {
    pub time_maximum: f64,
    pub time_partial_begin: f64,    // 0.0 if only penumbral
    pub time_partial_end: f64,
    pub time_totality_begin: f64,   // 0.0 unless total
    pub time_totality_end: f64,
    pub time_penumbral_begin: f64,  // always set
    pub time_penumbral_end: f64,    // always set
    pub flags: EclipseFlags,        // exactly one of TOTAL/PARTIAL/PENUMBRAL
}

pub struct LunarEclipseLocal {
    pub time_maximum: f64,
    pub time_partial_begin: f64,
    pub time_partial_end: f64,
    pub time_totality_begin: f64,
    pub time_totality_end: f64,
    pub time_penumbral_begin: f64,
    pub time_penumbral_end: f64,
    pub time_moonrise: f64,   // 0.0 if none
    pub time_moonset: f64,    // 0.0 if none
    pub attr: LunarEclipseHow,
    pub flags: EclipseFlags,
}

pub struct OccultGlobal {
    pub time_maximum: f64,
    pub time_ra_conjunction: f64,   // transit instant of the occulted body
    pub time_begin: f64,
    pub time_end: f64,
    pub time_totality_begin: f64,
    pub time_totality_end: f64,
    pub time_centerline_begin: f64,
    pub time_centerline_end: f64,
    pub flags: EclipseFlags,        // ANNULAR/HYBRID only possible when ipl == Body::Sun
}

pub struct OccultLocal {
    pub time_maximum: f64,
    pub time_first_contact: f64,    // aliased from time_second_contact for a star
    pub time_second_contact: f64,
    pub time_third_contact: f64,
    pub time_fourth_contact: f64,   // aliased from time_third_contact for a star
    pub time_rise: f64,             // 0.0 unless occulted body rises within [1st,4th] window
    pub time_set: f64,              // 0.0 unless it sets within that window
    pub attr: EclipseHow,
    pub flags: EclipseFlags,        // + OCC_BEG_DAYLIGHT / OCC_END_DAYLIGHT
}
```

---

## Ephemeris — rise/set/transit (→ task /31)

```rust
#[doc(alias = "swe_rise_trans_true_hor")]
pub fn rise_trans_true_hor(
    &self, tjd_ut: f64, body: Body, starname: Option<&str>, epheflag: CalcFlags,
    rsmi: RiseSetFlags, geopos: [f64; 3], atpress: f64, attemp: f64, horhgt: f64,
) -> Result<RiseSetResult, Error>;
// starname selects a fixed star (ignoring body); horhgt = local horizon height, deg
// (-100 = auto-dip from geopos[2]). Full-precision algorithm. Err(CircumpolarBody) possible.

#[doc(alias = "swe_rise_trans")]
pub fn rise_trans(
    &self, tjd_ut: f64, body: Body, starname: Option<&str>, epheflag: CalcFlags,
    rsmi: RiseSetFlags, geopos: [f64; 3], atpress: f64, attemp: f64,
) -> Result<RiseSetResult, Error>;
// Dispatches to a fast algorithm when eligible (not fixed star; RISE/SET only; no
// FORCE_SLOW/twilight; body in Sun..TrueNode; |lat|<=60, or <=65 for Sun); otherwise
// falls back to rise_trans_true_hor(horhgt=0.0).
```

### `RiseSetResult` (`src/riseset.rs`)

```rust
pub struct RiseSetResult {
    pub time: f64, // Julian Day (UT) of the rise/set/transit event
}
```
Plain data struct — no `impl` block with public methods; no free public functions
in `riseset.rs` (`rise_trans_true_hor`/`rise_set_fast` are `pub(crate)`).

---

## Ephemeris — crossings (→ task /32)

```rust
#[doc(alias = "swe_solcross")]
pub fn solcross(&self, x2cross: f64, jd_et: f64, flags: CalcFlags) -> Result<f64, Error>;
#[doc(alias = "swe_solcross_ut")]
pub fn solcross_ut(&self, x2cross: f64, jd_ut: f64, flags: CalcFlags) -> Result<f64, Error>;
#[doc(alias = "swe_mooncross")]
pub fn mooncross(&self, x2cross: f64, jd_et: f64, flags: CalcFlags) -> Result<f64, Error>;
#[doc(alias = "swe_mooncross_ut")]
pub fn mooncross_ut(&self, x2cross: f64, jd_ut: f64, flags: CalcFlags) -> Result<f64, Error>;
#[doc(alias = "swe_mooncross_node")]
pub fn mooncross_node(&self, jd_et: f64, flags: CalcFlags) -> Result<MoonCrossing, Error>;
#[doc(alias = "swe_mooncross_node_ut")]
pub fn mooncross_node_ut(&self, jd_ut: f64, flags: CalcFlags) -> Result<MoonCrossing, Error>;
#[doc(alias = "swe_helio_cross")]
pub fn helio_cross(&self, body: Body, x2cross: f64, jd_et: f64, flags: CalcFlags, dir: i32) -> Result<f64, Error>;
// dir >= 0 forward, dir < 0 backward.
#[doc(alias = "swe_helio_cross_ut")]
pub fn helio_cross_ut(&self, body: Body, x2cross: f64, jd_ut: f64, flags: CalcFlags, dir: i32) -> Result<f64, Error>;
```

### `MoonCrossing` (`src/crossings.rs`)

```rust
#[derive(Clone, Copy)]
pub struct MoonCrossing {
    pub jd: f64,         // same time scale as the search (TT or UT)
    pub longitude: f64,  // Moon's ecliptic longitude at crossing, degrees
    pub latitude: f64,   // Moon's ecliptic latitude at crossing, degrees (~0 by construction)
}
```

### Free functions in `src/crossings.rs` (module-level; these are what the `Ephemeris` methods above delegate to — listed for completeness, same signatures modulo the leading `eph: &Ephemeris` parameter)

```rust
pub fn solcross(eph: &Ephemeris, x2cross: f64, jd_et: f64, flags: CalcFlags) -> Result<f64, Error>;
pub fn solcross_ut(eph: &Ephemeris, x2cross: f64, jd_ut: f64, flags: CalcFlags) -> Result<f64, Error>;
pub fn mooncross(eph: &Ephemeris, x2cross: f64, jd_et: f64, flags: CalcFlags) -> Result<f64, Error>;
pub fn mooncross_ut(eph: &Ephemeris, x2cross: f64, jd_ut: f64, flags: CalcFlags) -> Result<f64, Error>;
pub fn mooncross_node(eph: &Ephemeris, jd_et: f64, flags: CalcFlags) -> Result<MoonCrossing, Error>;
pub fn mooncross_node_ut(eph: &Ephemeris, jd_ut: f64, flags: CalcFlags) -> Result<MoonCrossing, Error>;
pub fn helio_cross(eph: &Ephemeris, body: Body, x2cross: f64, jd_et: f64, flags: CalcFlags, dir: i32) -> Result<f64, Error>;
pub fn helio_cross_ut(eph: &Ephemeris, body: Body, x2cross: f64, jd_ut: f64, flags: CalcFlags, dir: i32) -> Result<f64, Error>;
```

---

## Ephemeris — phenomena & orbital (→ task /33)

```rust
#[doc(alias = "swe_pheno")]
pub fn pheno(&self, tjd_et: f64, body: Body, flags: CalcFlags) -> Result<(Phenomena, CalcFlags), Error>;

pub fn pheno_with_config(
    &self, tjd_et: f64, body: Body, flags: CalcFlags, config: &EphemerisConfig,
) -> Result<(Phenomena, CalcFlags), Error>;

#[doc(alias = "swe_pheno_ut")]
pub fn pheno_ut(&self, tjd_ut: f64, body: Body, flags: CalcFlags) -> Result<(Phenomena, CalcFlags), Error>;

pub fn pheno_ut_with_config(
    &self, tjd_ut: f64, body: Body, flags: CalcFlags, config: &EphemerisConfig,
) -> Result<(Phenomena, CalcFlags), Error>;

#[doc(alias = "swe_nod_aps")]
pub fn nod_aps(
    &self, tjd_et: f64, body: Body, flags: CalcFlags, method: NodApsMethod,
) -> Result<NodesApsides, Error>;

#[doc(alias = "swe_nod_aps_ut")]
pub fn nod_aps_ut(
    &self, tjd_ut: f64, body: Body, flags: CalcFlags, method: NodApsMethod,
) -> Result<NodesApsides, Error>;

#[doc(alias = "swe_get_orbital_elements")]
pub fn get_orbital_elements(&self, tjd_et: f64, body: Body, flags: CalcFlags) -> Result<OrbitalElements, Error>;
// Rejects Sun, lunar nodes, apsides. Note: TOPOCTR flag is bit-aliased as ORBEL_AA here
// (sum masses inside the orbit), not a topocentric request.

#[doc(alias = "swe_orbit_max_min_true_distance")]
pub fn orbit_max_min_true_distance(
    &self, tjd_et: f64, body: Body, flags: CalcFlags,
) -> Result<(f64, f64, f64), Error>; // (dmax, dmin, dtrue), AU
```

### `Phenomena` (`src/phenomena.rs`)

```rust
#[derive(Debug, Clone, Copy)]
pub struct Phenomena {
    pub phase_angle: f64,           // Sun-planet-Earth angle, degrees
    pub phase: f64,                 // illuminated fraction, 0..1
    pub elongation: f64,            // Sun-Earth-planet angle, degrees
    pub apparent_diameter: f64,     // degrees
    pub apparent_magnitude: f64,
    pub horizontal_parallax: f64,   // Moon only, degrees; 0 for all other bodies
}
```
Free functions (module-level, delegate targets of the Ephemeris methods above):
```rust
pub fn pheno(eph: &Ephemeris, tjd_et: f64, body: Body, flags: CalcFlags) -> Result<(Phenomena, CalcFlags), Error>;
pub fn pheno_ut(eph: &Ephemeris, tjd_ut: f64, body: Body, flags: CalcFlags) -> Result<(Phenomena, CalcFlags), Error>;
```
(`pheno_with_config`/`pheno_ut_with_config` module-level fns are `pub(crate)`.)

### `NodApsMethod` / `NodesApsides` (`src/nodaps.rs`)

```rust
pub struct NodApsMethod: u32 {  // bitflags; mirrors C's SE_NODBIT_*
    const MEAN     = 1;  // mean orbital elements (also the behavior when empty)
    const OSCU     = 2;  // osculating about the Sun (geocentric for the Moon)
    const OSCU_BAR = 4;  // osculating about the barycenter (bodies beyond ~6 AU only)
    const FOPOINT  = 256; // return the ellipse's 2nd focal point instead of aphelion
}

pub struct NodesApsides {
    pub ascending: [f64; 6],
    pub descending: [f64; 6],
    pub perihelion: [f64; 6],
    pub aphelion: [f64; 6], // or the 2nd focal point if FOPOINT requested
}
```
No free public functions or struct impls beyond the bitflags-generated API
(`nod_aps`/`transform_nodaps_output` are `pub(crate)`).

### `OrbitalElements` (`src/orbit.rs`)

```rust
#[derive(Debug, Clone, Copy)]
pub struct OrbitalElements {
    pub semi_major_axis: f64,      // AU
    pub eccentricity: f64,
    pub inclination: f64,          // deg
    pub ascending_node: f64,       // Ω, deg
    pub arg_perihelion: f64,       // ω, deg
    pub perihelion_lon: f64,       // ϖ = Ω+ω, deg
    pub mean_anomaly: f64,         // M₀, deg
    pub true_anomaly: f64,         // deg
    pub eccentric_anomaly: f64,    // deg
    pub mean_longitude: f64,       // deg
    pub sidereal_period: f64,      // tropical years, J2000
    pub mean_daily_motion: f64,    // deg/day
    pub tropical_period: f64,      // years
    pub synodic_period: f64,       // days; negative for inner planets/Moon
    pub perihelion_passage: f64,   // JD, TT
    pub perihelion_distance: f64,  // AU
    pub aphelion_distance: f64,    // AU
}
impl OrbitalElements {
    pub fn as_array(&self) -> [f64; 17]; // dret-ordered flat array
}
```
No free public module-level functions (`get_orbital_elements`,
`orbit_max_min_true_distance` are `pub(crate)`).

---

## Ephemeris — heliacal (→ task /34)

_(See heliacal.rs subsection below the Ephemeris method list.)_

```rust
#[doc(alias = "swe_vis_limit_mag")]
pub fn vis_limit_mag(
    &self, tjd_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6],
    object_name: &str, epheflag: CalcFlags, helflag: HeliacalFlags,
) -> Result<VisLimitResult, Error>;
// dgeo=[lon(east+),lat(north+),altitude(m)]. datm=[pressure hPa,temp °C,humidity 0-1,extinction].
// dobs=[age,Snellen ratio,0=naked/1=binocular/2=telescope,magnification,aperture_mm,0].

#[doc(alias = "swe_topo_arcus_visionis")]
pub fn topo_arcus_visionis(
    &self, tjd_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6],
    helflag: HeliacalFlags, mag: f64, azi_obj: f64, alt_obj: f64, azi_sun: f64,
    azi_moon: f64, alt_moon: f64,
) -> Result<f64, Error>; // degrees

#[doc(alias = "swe_heliacal_angle")]
pub fn heliacal_angle(
    &self, tjd_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6],
    helflag: HeliacalFlags, mag: f64, azi_obj: f64, azi_sun: f64, azi_moon: f64, alt_moon: f64,
) -> Result<HeliacalAngleResult, Error>;

#[doc(alias = "swe_heliacal_pheno_ut")]
pub fn heliacal_pheno_ut(
    &self, tjd_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6],
    object_name: &str, event: HeliacalEventType, epheflag: CalcFlags, helflag: HeliacalFlags,
) -> Result<HeliacalPheno, Error>;

#[doc(alias = "swe_heliacal_ut")]
pub fn heliacal_ut(
    &self, tjd_start_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6],
    object_name: &str, event: HeliacalEventType, epheflag: CalcFlags, helflag: HeliacalFlags,
) -> Result<HeliacalEvent, Error>;
// Finds next heliacal event (morning first, evening last, evening first, morning last,
// acronychal rising/setting) for object_name after tjd_start_ut.
```

---

## Free functions (→ various tasks)

### `src/date.rs`

```rust
pub const LEAP_SECONDS: [i32; 27] = [ /* packed YYYYMMDD dates, built-in IERS table */ ];

pub fn julday(year: i32, month: i32, day: i32, hour: f64, cal: CalendarType) -> f64;
// Port of swe_julday.

pub fn revjul(jd: f64, cal: CalendarType) -> (i32, i32, i32, f64); // (year, month, day, hour-UT)
// Port of swe_revjul.

pub fn date_conversion(year: i32, month: i32, day: i32, hour: f64, cal: CalendarType) -> crate::Result<f64>;
// Validates round-trip through julday/revjul (rejects e.g. Feb 30). Port of swe_date_conversion.

pub fn day_of_week(jd: f64) -> u8; // 0=Monday..6=Sunday. Port of swe_day_of_week.

pub fn utc_time_zone(input: &UtcComponents, tz_offset: f64) -> UtcComponents;
// Shifts UTC date/time by tz_offset (hours, east+), handling day rollover + leap-second flag.
// Port of swe_utc_time_zone.

pub fn utc_to_jd(
    utc: &UtcComponents, cal: CalendarType, leap_secs: &[i32], dt: &impl DeltaT,
) -> crate::Result<UtcToJd>;
// Port of swe_utc_to_jd. Pre-1972 input is treated as UT1 directly.

pub fn jdet_to_utc(
    jd_tt: JdTt, cal: CalendarType, leap_secs: &[i32], dt: &impl DeltaT,
) -> UtcComponents;
// Port of swe_jdet_to_utc.

pub fn jdut1_to_utc(
    jd_ut: JdUt1, cal: CalendarType, leap_secs: &[i32], dt: &impl DeltaT,
) -> UtcComponents;
// Port of swe_jdut1_to_utc.
```

### `Ephemeris` time-of-day / file-introspection / naming methods (`src/context.rs`)

```rust
#[doc(alias = "swe_time_equ")]
pub fn time_equ(&self, tjd_ut: f64) -> crate::Result<f64>;
// Equation of time E = LAT - LMT, in DAYS (positive = Sun ahead of mean).

#[doc(alias = "swe_lmt_to_lat")]
pub fn lmt_to_lat(&self, tjd_lmt: f64, geolon: f64) -> crate::Result<f64>;
// geolon degrees east-positive; both in/out are JD (UT-scale).

#[doc(alias = "swe_lat_to_lmt")]
pub fn lat_to_lmt(&self, tjd_lat: f64, geolon: f64) -> crate::Result<f64>;

#[doc(alias = "swe_get_current_file_data")]
pub fn file_data(&self, kind: FileDataKind, jd: f64) -> Option<FileData>;
// Stateless equivalent of swe_get_current_file_data(ifno): jd selects which file would
// serve that epoch. None for Moshier source, no covering file, or kind Asteroid/PlanetMoon.

pub fn file_data_for_body(&self, body: Body, jd: f64) -> Option<FileData>;
// Unlike file_data, handles individual asteroids/planet-moons by looking up that body's
// own .se1 file.

#[doc(alias = "swe_get_planet_name")]
pub fn get_planet_name(&self, body: Body) -> String;
// Resolves display name (built-in table for named bodies; file-header lookup + seasnam.txt
// override for numbered asteroids; fictitious catalog lookup for Body::Fictitious).
```

### `src/azalt.rs`

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RefracDir { TrueToApp, AppToTrue }       // SE_TRUE_TO_APP / SE_APP_TO_TRUE

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AzAltDir { EclToHor, EquToHor }           // SE_ECL2HOR / SE_EQU2HOR

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HorDir { HorToEcl, HorToEqu }             // SE_HOR2ECL / SE_HOR2EQU

pub fn refrac(inalt: f64, atpress: f64, attemp: f64, dir: RefracDir) -> f64;
// Port of swe_refrac: true<->apparent altitude, sea-level, no dip. atpress hPa, attemp °C.

pub fn refrac_extended(
    inalt: f64, geoalt: f64, atpress: f64, attemp: f64, lapse_rate: f64,
    dir: RefracDir, dret: &mut [f64; 4],
) -> f64;
// Port of swe_refrac_extended. geoalt = height above sea (m). dret out-param =
// [true alt, apparent alt, refraction, horizon dip] deg. Above horizon iff dret[0] != dret[1].

pub fn azalt(
    dir: AzAltDir, armc: f64, eps_true: f64, geopos: [f64; 3], atpress: f64,
    attemp: f64, lapse_rate: f64, xin: [f64; 2],
) -> [f64; 3];
// Pure geometry core of swe_azalt given precomputed armc/eps_true. geopos=[lon(unused),
// lat,height]. xin=[lon/RA,lat/dec] deg. Returns [azimuth(from south,cw via west), true alt,
// apparent alt] deg. (Ephemeris::azalt wraps this with its own armc/eps computation.)

pub fn azalt_rev(dir: HorDir, armc: f64, eps_true: f64, geolat: f64, xin: [f64; 2]) -> [f64; 2];
// Pure geometry core of swe_azalt_rev. Does NOT de-refract. xin=[azimuth,true alt] deg.
// Returns [lon/RA, lat/dec] deg.
```

### `Ephemeris::azalt` / `azalt_rev` (`src/context.rs` — wrap the free functions above with ARMC/obliquity setup)

```rust
#[doc(alias = "swe_azalt")]
pub fn azalt(
    &self, tjd_ut: f64, dir: AzAltDir, geopos: [f64; 3], atpress: f64, attemp: f64,
    lapse_rate: f64, xin: [f64; 2],
) -> [f64; 3];

#[doc(alias = "swe_azalt_rev")]
pub fn azalt_rev(&self, tjd_ut: f64, dir: HorDir, geopos: [f64; 3], xin: [f64; 2]) -> [f64; 2];
```

### `src/math.rs` (pure free-function module; `DegreeParts` return type is in types.rs)

```rust
pub const OWEN_T0S: [f64; 5] = [-3392455.5, -470455.5, 2451544.5, 5373544.5, 8295544.5];
// Owen 1990 Chebyshev-interval reference epochs (JD, TT).

pub fn normalize_degrees(x: f64) -> f64;      // -> [0, 360)
pub fn normalize_radians(x: f64) -> f64;      // -> [0, 2π)
pub fn mod_2pi(x: f64) -> f64;                // reduce into [0, 2π), no near-zero snapping
pub fn mods3600(x: f64) -> f64;               // reduce centisecond angle into [0, 1_296_000)
pub fn diff_degrees_norm(p1: f64, p2: f64) -> f64; // p1-p2, unsigned, [0,360)
pub fn diff_degrees(p1: f64, p2: f64) -> f64;      // p1-p2, signed, [-180,180)
pub fn diff_radians(p1: f64, p2: f64) -> f64;      // p1-p2, signed, [-π,π)
pub fn midpoint_degrees(x1: f64, x0: f64) -> f64;  // shorter-arc midpoint, degrees
pub fn midpoint_radians(x1: f64, x0: f64) -> f64;  // shorter-arc midpoint, radians
pub fn csnorm(p: i32) -> i32;                 // normalize centisecond angle to [0, DEG360)
pub fn difcsn(p1: i32, p2: i32) -> i32;       // p1-p2, unsigned, [0, DEG360) centiseconds
pub fn difcs2n(p1: i32, p2: i32) -> i32;      // p1-p2, signed, [-DEG180, DEG180) centiseconds
pub fn d2l(x: f64) -> i32;                    // round-half-away-from-zero (C d2l)
pub fn chebyshev_eval(x: f64, coeffs: &[f64]) -> f64;   // Broucke/Clenshaw recurrence
pub fn chebyshev_deriv(x: f64, coeffs: &[f64]) -> f64;  // derivative, same recurrence
pub fn cross_prod(a: [f64; 3], b: [f64; 3]) -> [f64; 3];        // swi_cross_prod
pub fn dot_prod_unit(x: [f64; 3], y: [f64; 3]) -> f64;          // swi_dot_prod_unit, clamped [-1,1]
pub fn rotate_x(pos: [f64; 3], eps: f64) -> [f64; 3];           // rotate about X, eps radians
pub fn rotate_x_sincos(pos: [f64; 3], sineps: f64, coseps: f64) -> [f64; 3];
pub fn cartesian_to_polar(x: [f64; 3]) -> [f64; 3];             // -> [lon, lat, dist] radians
pub fn polar_to_cartesian(l: [f64; 3]) -> [f64; 3];
pub fn cartesian_to_polar_with_speed(x: [f64; 6]) -> [f64; 6];  // + speed components
pub fn polar_to_cartesian_with_speed(l: [f64; 6]) -> [f64; 6];
pub fn cotrans(xpo: [f64; 3], eps: f64) -> [f64; 3];
// Rotate polar position [lon,lat,dist] (degrees,degrees,any) about X by obliquity eps (degrees)
// — the ecliptic/equatorial coordinate swap. THIS is the crate's "cotrans".
pub fn cotrans_with_speed(xpo: [f64; 6], eps: f64) -> [f64; 6];
// Like cotrans but also rotates speed components. THIS is the crate's "cotrans_sp"
// equivalent — the crate does not have a function literally named cotrans_sp.
pub fn split_degrees(ddeg: f64, flags: SplitDegFlags) -> DegreeParts;
// Port of swe_split_deg.
pub fn poly_eval(coeffs: &[f64], x: f64) -> f64; // Horner's method, coeffs lowest-degree first
pub fn find_maximum(y00: f64, y11: f64, y2: f64, dx: f64) -> (f64, f64);
// Parabola-fit extremum through 3 equally-spaced samples. Port of find_maximum (swecl.c).
// Returns (dxret, yret): dxret relative to y2 sample.
pub fn find_zero(y00: f64, y11: f64, y2: f64, dx: f64) -> Option<(f64, f64)>;
// Parabola-fit root(s), same sample convention. Port of find_zero (swecl.c). None if the
// parabola never crosses zero.
pub fn armc_to_mc(armc_deg: f64, eps_deg: f64) -> f64; // swi_armc_to_mc
pub fn owen_t0_icof(jd: f64) -> (f64, usize); // selects Owen 1990 Chebyshev interval for jd
pub fn owen_chebyshev_basis(jd: f64) -> (usize, [f64; 10]); // Owen 1990 basis T_0..T_9 at jd
```

### `src/format.rs`

```rust
pub fn csroundsec(x: i32) -> i32;
// Round centisecond angle to nearest arcsecond, with zodiac-boundary guard
// (rounding up to exactly a 30° boundary rounds down instead). Port of swe_csroundsec.

pub fn cs2timestr(t: i32, sep: char, suppress_zero: bool) -> String;
// "HH:MM:SS" (or "HH:MM" if suppress_zero and seconds==0). Port of swe_cs2timestr.

pub fn cs2lonlatstr(t: i32, pchar: char, mchar: char) -> String;
// Longitude/latitude string with direction letter (mchar if negative, pchar if positive);
// seconds suppressed when zero; leading degree zeros suppressed. Port of swe_cs2lonlatstr.

pub fn cs2degstr(t: i32) -> String;
// Degrees-within-sign (" D°MM'SS"). TRUNCATES (no rounding), wraps into [0,30°).
// Port of swe_cs2degstr.
```

### `src/stars.rs`

```rust
#[derive(Clone, Debug)]
pub struct Star {
    pub name: String,    // traditional name (e.g. "Sirius"), or empty for Bayer-only records
    pub bayer: String,   // Bayer/Flamsteed designation (e.g. "alfCMa")
    pub skey: String,    // normalized search key
    pub epoch: f64,      // 0.0 = ICRS, else Julian-year epoch (e.g. 1950.0, 2000.0)
    pub ra: f64,         // radians, at epoch
    pub de: f64,         // radians, at epoch
    pub ramot: f64,      // proper motion RA, radians/century (already / cos(de))
    pub demot: f64,      // proper motion dec, radians/century
    pub radvel: f64,     // AU/century
    pub parall: f64,     // radians
    pub mag: f64,        // visual magnitude
}

pub struct StarCatalog {
    pub bayer_records: Vec<Star>,  // unique-Bayer records, sorted by skey
    pub named_records: Vec<Star>,  // records with a non-empty traditional name
    // private: by_bayer / by_name HashMap indices
}
impl StarCatalog {
    pub fn empty() -> Self;
    pub fn n_real(&self) -> usize;
    pub fn n_named(&self) -> usize;
    pub fn search(&self, input: &str) -> Result<Star, Error>;
    // by sequential number, Bayer designation (","-prefixed, optional trailing "%" wildcard),
    // or traditional name.
}

pub fn builtin_star(input: &str) -> Option<Star>;
// Hardcoded fallback records for the 8 ayanamsa reference stars (port of get_builtin_star);
// checked before catalog search so these resolve without sefstars.txt.

pub fn load_catalog(ephe_path: Option<&Path>) -> StarCatalog;
// Loads from ephe_path/sefstars.txt; empty catalog on any failure.
```

---

## Ephemeris — heliacal detail (`src/heliacal.rs`)

Module: heliacal visibility (first/last sightings of a body near the Sun) —
port of Swiss Ephemeris `swehel.c`. The `Ephemeris` methods
(`vis_limit_mag`, `topo_arcus_visionis`, `heliacal_angle`,
`heliacal_pheno_ut`, `heliacal_ut`) are listed above in the "Ephemeris —
heliacal" section; this subsection covers the result types, enum, and the
large set of module-level free functions this crate exposes as `pub`
(atmospheric/optical model internals — mostly not called directly by
`Ephemeris` methods' callers, but public and available).

### `HeliacalEventType`

```rust
#[repr(i32)]
pub enum HeliacalEventType {
    MorningFirst = 1,       // first visibility in the morning sky before sunrise
    EveningLast = 2,        // last visibility in the evening sky after sunset
    EveningFirst = 3,       // first visibility in the evening sky after sunset
    MorningLast = 4,        // last visibility in the morning sky before sunrise
    AcronymchalRising = 5,  // acronychal (cosmical) rising: body rises as Sun sets
    AcronymchalSetting = 6, // acronychal (cosmical) setting: body sets as Sun rises
}
impl TryFrom<i32> for HeliacalEventType { type Error = crate::Error; fn try_from(v: i32) -> Result<Self, Self::Error>; }
```

### Result structs

```rust
#[derive(Debug, Clone)]
pub struct VisLimitResult {
    pub limiting_magnitude: f64,  // dret[0]; -100.0 sentinel if below_horizon
    pub altitude_object: f64,     // dret[1], true topocentric altitude, degrees
    pub azimuth_object: f64,      // dret[2], degrees
    pub altitude_sun: f64,        // dret[3]; -90 under VISLIM_DARK
    pub azimuth_sun: f64,         // dret[4]; 0 under VISLIM_DARK
    pub altitude_moon: f64,       // dret[5]; -90 if object is Moon or VISLIM_DARK/VISLIM_NOMOON
    pub azimuth_moon: f64,        // dret[6]; same conditions
    pub magnitude_object: f64,    // dret[7], actual apparent visual magnitude
    pub vision: VisLimFlags,      // scotopic/mixed vision-mode flags
    pub below_horizon: bool,
}

#[derive(Debug, Clone, Copy)]
pub struct HeliacalAngleResult {
    pub optimal_altitude: f64,   // object's altitude at the optimum, degrees
    pub arcus_visionis: f64,     // arcus visionis at the optimum, degrees
    pub sun_altitude_diff: f64,  // optimal_altitude - arcus_visionis
}

#[derive(Debug, Clone, Copy)]
pub struct HeliacalPheno {  // port of swe_heliacal_pheno_ut's 28-element dret[]
    pub tc_altitude: f64,            // dret[0], topocentric altitude, degrees
    pub tc_apparent_altitude: f64,   // dret[1], topocentric apparent (refracted) altitude
    pub gc_altitude: f64,            // dret[2], geocentric altitude
    pub azimuth_object: f64,         // dret[3]
    pub tc_sun_altitude: f64,        // dret[4]
    pub sun_azimuth: f64,            // dret[5]
    pub tav_act: f64,                // dret[6], actual topocentric arcus visionis
    pub arcv_act: f64,               // dret[7], actual (parallax-corrected) arcus visionis
    pub daz_act: f64,                // dret[8], actual Sun/object azimuth difference
    pub arcl_act: f64,               // dret[9], actual Sun/object longitude difference (great circle)
    pub kact: f64,                   // dret[10], extinction coefficient at Sun's altitude
    pub min_tav: f64,                // dret[11], smallest topocentric arcus visionis found in search
    pub t_first_vr: f64,             // dret[12], JD UT first possibly visible
    pub t_best_vr: f64,              // dret[13], JD UT best (optimum) visible
    pub t_last_vr: f64,              // dret[14], JD UT last possibly visible
    pub t_best_yallop: f64,          // dret[15], optimum time per Yallop's criterion, Moon only
    pub w_moon: f64,                 // dret[16], crescent width of Moon, Moon only
    pub q_yallop: f64,               // dret[17], Yallop's q-test value, Moon only
    pub q_crit: f64,                 // dret[18], Yallop visibility-grade classification, Moon only
    pub par_o: f64,                  // dret[19], object's parallax, degrees
    pub magn_o: f64,                 // dret[20], object's actual apparent visual magnitude
    pub rise_o: f64,                 // dret[21], object's rise/set time, JD UT
    pub rise_s: f64,                 // dret[22], Sun's rise/set time, JD UT
    pub lag: f64,                    // dret[23], time lag between object's and Sun's rise/set, days
    pub t_vis_vr: f64,               // dret[24], duration of visibility window, days
    pub l_moon: f64,                 // dret[25], crescent length of Moon, Moon only
    pub elongation: f64,             // dret[26], degrees
    pub illumination: f64,           // dret[27], illuminated fraction of disc, percent
}
impl HeliacalPheno {
    pub fn as_array(&self) -> [f64; 28]; // flattens fields in declaration order, matching C's dret[]
}

#[derive(Debug, Clone, Copy)]
pub struct HeliacalEvent {
    pub start_visible: f64,       // beginning of visibility (or the single instant for arc_vis path)
    pub optimum_visibility: f64,  // 0.0 if arc_vis path or NO_DETAILS
    pub end_visible: f64,         // 0.0 if arc_vis path or NO_DETAILS
}
```

### Free functions (module-level `pub fn`, not `Ephemeris` methods)

Naming resolution / defaults:
```rust
pub fn object_to_body(name: &str) -> Option<Body>;
// planet name / "moon" / leading asteroid number -> Body; None for fixed stars.
pub fn tolower_string_star(name: &str) -> String;
// lowercases, preserving case of a comma-separated star-designation suffix.
pub fn default_heliacal_parameters(datm: &mut [f64; 4], dgeo: &[f64; 3], dobs: &mut [f64; 6], helflag: HeliacalFlags);
// fills unset atmospheric/observer parameters with standard-atmosphere/naked-eye defaults.
```

Atmosphere / optics / brightness model (mostly ports of individual `swehel.c` static helpers, exposed `pub` here):
```rust
pub fn tanh_manual(x: f64) -> f64;
pub fn kelvin(temp: f64) -> f64;
pub fn topo_alt_from_app_alt(app_alt: f64, temp_e: f64, pres_e: f64) -> f64;
pub fn app_alt_from_topo_alt(topo_alt: f64, temp_e: f64, pres_e: f64, helflag: HeliacalFlags) -> f64;
pub fn hour_angle(topo_alt: f64, topo_decl: f64, lat: f64) -> f64;
pub fn distance_angle(lat_a: f64, long_a: f64, lat_b: f64, long_b: f64) -> f64;
pub fn temp_e_from_temp_s(temp_s: f64, height_eye: f64, lapse: f64) -> f64;
pub fn pres_e_from_pres_s(temp_s: f64, press: f64, height_eye: f64) -> f64;
pub fn kw(height_eye: f64, temp_s: f64, rh: f64) -> f64;               // water-vapor extinction
pub fn koz(alt_s: f64, sunra: f64, lat: f64) -> f64;                    // ozone extinction
pub fn kr(alt_s: f64, height_eye: f64) -> f64;                          // Rayleigh extinction
pub fn ka(alt_s: f64, sunra: f64, lat: f64, height_eye: f64, temp_s: f64, rh: f64, vr: f64) -> f64; // aerosol extinction
pub fn kt(alt_s: f64, sunra: f64, lat: f64, height_eye: f64, temp_s: f64, rh: f64, vr: f64, ext_type: i32) -> f64;
// total extinction; ext_type: 0=aerosol,1=water,2=Rayleigh,3=ozone,4=all combined
pub fn airmass(app_alt_o: f64, press: f64) -> f64;
pub fn xext(scale_h: f64, zend: f64, press: f64) -> f64;
pub fn xlay(scale_h: f64, zend: f64, press: f64) -> f64;
pub fn deltam(alt_o: f64, alt_s: f64, sunra: f64, lat: f64, height_eye: f64, datm: &[f64; 4], helflag: HeliacalFlags) -> f64;
pub fn cva(b: f64, sn: f64, helflag: HeliacalFlags) -> f64;             // critical visual acuity, degrees
pub fn pupil_dia(age: f64, b: f64) -> f64;                              // mm
pub fn optic_factor(bback: f64, k_x: f64, dobs: &[f64; 6], is_moon: bool, type_factor: i32, helflag: HeliacalFlags) -> f64;
pub fn moons_brightness(dist: f64, phasemoon: f64) -> f64;
pub fn moon_phase(alt_m: f64, azi_m: f64, alt_s: f64, azi_s: f64) -> f64;
pub fn bn(alt_o: f64, jdn_days_ut: f64, alt_s: f64, sunra: f64, lat: f64, height_eye: f64, datm: &[f64; 4], helflag: HeliacalFlags) -> f64;
// natural night-sky background brightness, nL (11-yr solar-cycle modulated)
pub fn bm(alt_o: f64, azi_o: f64, alt_m: f64, azi_m: f64, alt_s: f64, azi_s: f64, sunra: f64, lat: f64, height_eye: f64, datm: &[f64; 4], helflag: HeliacalFlags) -> f64;
// sky background from scattered moonlight, nL
pub fn btwi(alt_o: f64, azi_o: f64, alt_s: f64, azi_s: f64, sunra: f64, lat: f64, height_eye: f64, datm: &[f64; 4], helflag: HeliacalFlags) -> f64;
// twilight sky background, nL
pub fn bday(alt_o: f64, azi_o: f64, alt_s: f64, azi_s: f64, sunra: f64, lat: f64, height_eye: f64, datm: &[f64; 4], helflag: HeliacalFlags) -> f64;
// daytime sky background, nL
pub fn bcity(value: f64) -> f64; // clamps city-light brightness contribution >= 0
pub fn bsky(alt_o: f64, azi_o: f64, alt_m: f64, azi_m: f64, jdn_days_ut: f64, alt_s: f64, azi_s: f64, sunra: f64, lat: f64, height_eye: f64, datm: &[f64; 4], helflag: HeliacalFlags) -> f64;
// total sky background, nL (twilight/day + moonlight + city + night components)
pub fn sun_ra(jdn_days_ut: f64) -> f64; // crude calendar approximation, degrees
```

Ephemeris-dependent geometry / search (take `eph: &Ephemeris`):
```rust
pub fn object_loc(eph: &Ephemeris, jd_ut: f64, dgeo: &[f64; 3], datm: &[f64; 4], object_name: &str, angle: i32, epheflag: CalcFlags, helflag: HeliacalFlags) -> Result<f64, Error>;
// angle: 0=apparent alt,1=azimuth,2=RA,3=ecl.lon,4=apparent-refracted alt,5=dec,6=ecl.lat,7=geocentric alt
pub fn azalt_cart(eph: &Ephemeris, jd_ut: f64, dgeo: &[f64; 3], datm: &[f64; 4], object_name: &str, epheflag: CalcFlags, helflag: HeliacalFlags) -> Result<[f64; 6], Error>;
pub fn magnitude(eph: &Ephemeris, jd_ut: f64, dgeo: &[f64; 3], object_name: &str, epheflag: CalcFlags, helflag: HeliacalFlags) -> Result<f64, Error>;
pub fn calc_rise_and_set(eph: &Ephemeris, tjd_start: f64, ipl: Body, dgeo: &[f64; 3], datm: &[f64; 4], eventflag: RiseSetFlags, epheflag: CalcFlags, helflag: HeliacalFlags) -> Result<f64, Error>;
// fast direct-search algorithm, valid |latitude| < 63°
pub fn my_rise_trans(eph: &Ephemeris, tjd: f64, ipl: Body, starname: Option<&str>, eventtype: RiseSetFlags, epheflag: CalcFlags, helflag: HeliacalFlags, dgeo: &[f64; 3], datm: &[f64; 4]) -> Result<f64, Error>;
pub fn rise_set(eph: &Ephemeris, jdn_days_ut: f64, dgeo: &[f64; 3], datm: &[f64; 4], object_name: &str, rs_event: RiseSetFlags, epheflag: CalcFlags, helflag: HeliacalFlags, rim: i32) -> Result<f64, Error>;
// rim == 0 forces disc-center timing
pub fn vis_lim_magn(dobs: &[f64; 6], alt_o: f64, azi_o: f64, alt_m: f64, azi_m: f64, jdn_days_ut: f64, alt_s: f64, azi_s: f64, sunra: f64, lat: f64, height_eye: f64, datm: &[f64; 4], helflag: HeliacalFlags) -> (f64, VisLimFlags);
// port of VisLimMagn
pub fn vis_limit_mag(eph: &Ephemeris, tjd_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], object_name: &str, epheflag: CalcFlags, helflag: HeliacalFlags) -> Result<VisLimitResult, Error>;
// port of swe_vis_limit_mag (delegate target of Ephemeris::vis_limit_mag)
pub fn topo_arc_visionis(magn: f64, dobs: &[f64; 6], alt_o: f64, azi_o: f64, alt_m: f64, azi_m: f64, jdn_days_ut: f64, azi_s: f64, sunra: f64, lat: f64, height_eye: f64, datm: &[f64; 4], helflag: HeliacalFlags) -> f64;
// bisection search for Sun-depression angle at which object becomes exactly visible; port of TopoArcVisionis
pub fn topo_arcus_visionis(tjd_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], helflag: HeliacalFlags, mag: f64, azi_obj: f64, alt_obj: f64, azi_sun: f64, azi_moon: f64, alt_moon: f64) -> Result<f64, Error>;
// port of swe_topo_arcus_visionis (delegate target of Ephemeris::topo_arcus_visionis)
pub fn heliacal_angle_core(magn: f64, dobs: &[f64; 6], azi_o: f64, alt_m: f64, azi_m: f64, jdn_days_ut: f64, azi_s: f64, dgeo: &[f64; 3], datm: &[f64; 4], helflag: HeliacalFlags) -> HeliacalAngleResult;
// 2-D search for optimal object-altitude/arcus-visionis pair; port of HeliacalAngle
pub fn heliacal_angle(tjd_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], helflag: HeliacalFlags, mag: f64, azi_obj: f64, azi_sun: f64, azi_moon: f64, alt_moon: f64) -> Result<HeliacalAngleResult, Error>;
// port of swe_heliacal_angle (delegate target of Ephemeris::heliacal_angle)
pub fn heliacal_pheno_ut(eph: &Ephemeris, tjd_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], object_name: &str, event: HeliacalEventType, epheflag: CalcFlags, helflag: HeliacalFlags) -> Result<HeliacalPheno, Error>;
// port of swe_heliacal_pheno_ut (delegate target of Ephemeris::heliacal_pheno_ut)
pub fn find_conjunct_sun(eph: &Ephemeris, tjd_start: f64, ipl: Body, epheflag: CalcFlags, type_event: i32) -> Result<f64, Error>;
// JD of conjunction (or opposition for acronychal events) nearest after tjd_start
pub fn get_asc_obl_with_sun(eph: &Ephemeris, tjd_start: f64, ipl: Body, starname: Option<&str>, epheflag: CalcFlags, evtyp: i32, dperiod: f64, dgeo: &[f64; 3]) -> Result<f64, Error>;
// JD where oblique-ascension difference (ipl/starname vs Sun) crosses zero
pub fn get_heliacal_day(eph: &Ephemeris, tjd: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], object_name: &str, epheflag: CalcFlags, helflag: HeliacalFlags, type_event: i32) -> Result<f64, Error>;
// day-by-day then minute-by-minute search for the heliacal event date
pub fn get_acronychal_day(eph: &Ephemeris, tjd: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], object_name: &str, epheflag: CalcFlags, helflag: HeliacalFlags, type_event: i32) -> Result<f64, Error>;
// iterates rise/set + dark/no-moon visibility-limit boundaries to convergence
pub fn time_optimum_visibility(eph: &Ephemeris, tjd: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], object_name: &str, epheflag: CalcFlags, helflag: HeliacalFlags) -> Result<(f64, bool), Error>;
// hill-climb to time of maximum visibility margin; bool = uncertain due to scotopic/photopic transition
pub fn time_limit_invisible(eph: &Ephemeris, tjd: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], object_name: &str, epheflag: CalcFlags, helflag: HeliacalFlags, direct: f64, tret: &mut f64) -> Result<bool, Error>;
// walks from tjd in direction `direct` to the invisibility boundary (written to *tret)
pub fn get_heliacal_details(eph: &Ephemeris, tday: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], object_name: &str, epheflag: CalcFlags, helflag: HeliacalFlags, type_event: i32) -> Result<[f64; 3], Error>;
// given a day known to contain the event, returns [start_visible, optimum, end_visible]
pub fn heliacal_ut(eph: &Ephemeris, tjd_start_ut: f64, dgeo: &[f64; 3], datm: &mut [f64; 4], dobs: &mut [f64; 6], object_name: &str, event: HeliacalEventType, epheflag: CalcFlags, helflag: HeliacalFlags) -> Result<HeliacalEvent, Error>;
// top-level driver; port of swe_heliacal_ut (delegate target of Ephemeris::heliacal_ut)
```

---

## FFI surface (swisseph-ffi)

The Dart FFI bindings talk to this C ABI, not to the Rust API above. Every
function uses a uniform `i32` return-code convention (0 = success or
non-negative status, negative = error) except where noted, and error detail
is written into a caller-supplied `err_buf`/`err_cap`. All out-arrays are
flat `f64`/`i32` buffers — the Rust-side result structs (`CalcResult`,
`HouseResult`, `EclipseHow`, `Phenomena`, `OrbitalElements`, etc.) are never
`#[repr(C)]`; they are marshaled into these flat buffers by private helper
functions on the Rust side of the FFI crate.

### Opaque handle & shared types (`swisseph-ffi/src/lib.rs`)

```rust
pub struct SweEphemeris(Arc<Ephemeris>); // opaque; C/Dart only ever sees *mut/*const SweEphemeris

#[repr(C)]
pub struct SweSidMode {
    pub sid_mode: i32,   // raw swe_set_sid_mode value (bits 0-7 = mode index, upper bits = SiderealBits)
    pub t0: f64,         // reference epoch for user-defined sidereal (mode index 255)
    pub ayan_t0: f64,    // initial ayanamsa at t0
}
```
Lifecycle: create via `swisseph_new` (from `SweConfig`); refcount-clone
(shares the engine) via `swisseph_share`; destroy via `swisseph_free`
(null-safe; last-handle release frees the engine; order-independent).

```rust
pub extern "C" fn swisseph_version() -> *const c_char;

pub unsafe extern "C" fn swisseph_new(
    config: *const SweConfig, out: *mut *mut SweEphemeris,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_free(handle: *mut SweEphemeris);

pub unsafe extern "C" fn swisseph_share(
    handle: *const SweEphemeris, out: *mut *mut SweEphemeris,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_get_tid_acc(handle: *const SweEphemeris) -> f64;

pub unsafe extern "C" fn swisseph_get_astro_models(
    handle: *const SweEphemeris,
    out: *mut i32, // 8 slots: prec_longterm, prec_shortterm, nutation, bias, jplhor, jplhora, sidereal_time, delta_t
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_get_file_data(
    handle: *const SweEphemeris, ifno: i32, jd: f64,
    path_buf: *mut c_char, path_cap: usize,
    tfstart: *mut f64, tfend: *mut f64, denum: *mut i32,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_calc_ut(
    handle: *const SweEphemeris, tjd_ut: f64, ipl: i32, iflag: i32,
    geopos: *const f64,             // NULL, or [lon, lat, alt]
    sid_mode: *const SweSidMode,
    xx: *mut f64,                   // 6 slots: lon, lat, dist, lon_speed, lat_speed, dist_speed
    flags_used: *mut i32,           // nullable
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_calc(
    handle: *const SweEphemeris, tjd_et: f64, ipl: i32, iflag: i32,
    geopos: *const f64, sid_mode: *const SweSidMode,
    xx: *mut f64, flags_used: *mut i32,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_calc_pctr(
    handle: *const SweEphemeris, tjd_et: f64, ipl: i32, iplctr: i32, iflag: i32,
    xx: *mut f64, flags_used: *mut i32,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_fixstar2(
    handle: *const SweEphemeris, star: *const c_char,
    star_out: *mut c_char, star_out_cap: usize,   // star_out nullable
    tjd_et: f64, iflag: i32, geopos: *const f64, sid_mode: *const SweSidMode,
    xx: *mut f64, flags_used: *mut i32,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_fixstar2_ut(
    handle: *const SweEphemeris, star: *const c_char,
    star_out: *mut c_char, star_out_cap: usize,
    tjd_ut: f64, iflag: i32, geopos: *const f64, sid_mode: *const SweSidMode,
    xx: *mut f64, flags_used: *mut i32,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_fixstar2_mag(
    handle: *const SweEphemeris, star: *const c_char,
    star_out: *mut c_char, star_out_cap: usize,   // nullable
    mag: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_get_ayanamsa_ex(
    handle: *const SweEphemeris, tjd_et: f64, iflag: i32, sid_mode: *const SweSidMode,
    daya: *mut f64, flags_used: *mut i32, // flags_used nullable
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_get_ayanamsa_ex_ut(
    handle: *const SweEphemeris, tjd_ut: f64, iflag: i32, sid_mode: *const SweSidMode,
    daya: *mut f64, flags_used: *mut i32,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_get_ayanamsa(
    handle: *const SweEphemeris, tjd_et: f64, sid_mode: *const SweSidMode,
) -> f64; // NAN on error

pub unsafe extern "C" fn swisseph_get_ayanamsa_ut(
    handle: *const SweEphemeris, tjd_ut: f64, sid_mode: *const SweSidMode,
) -> f64; // NAN on error

pub unsafe extern "C" fn swisseph_get_ayanamsa_name( // handle-free
    sid_mode_raw: i32, buf: *mut c_char, cap: usize,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_get_planet_name(
    handle: *const SweEphemeris, ipl: i32, buf: *mut c_char, cap: usize,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;
```

### `swisseph-ffi/src/config.rs`

```rust
#[repr(C)]
pub struct SweConfig {
    pub ephemeris_source: i32,            // 0=Moshier, 1=Swiss, 2=Jpl
    pub ephe_path: *const c_char,         // NULL = none
    pub jpl_filename: *const c_char,      // NULL = default
    pub leap_seconds_file: *const c_char, // NULL = built-in table

    pub has_sidereal: bool,
    pub sid_mode: i32,
    pub sid_t0: f64,
    pub sid_ayan_t0: f64,

    pub has_topo: bool,
    pub geolon: f64,
    pub geolat: f64,
    pub altitude: f64,

    pub tidal_acceleration: f64,  // NAN = unset/auto-derive
    pub delta_t_userdef: f64,     // NAN = unset/use models

    pub asteroid_numbers: *const i32,
    pub asteroid_numbers_len: usize,
    pub planet_moon_numbers: *const i32,
    pub planet_moon_numbers_len: usize,
    pub extra_leap_seconds: *const i32,
    pub extra_leap_seconds_len: usize,

    pub astro_model_prec_longterm: i32,     // 0 = library default
    pub astro_model_prec_shortterm: i32,
    pub astro_model_nutation: i32,
    pub astro_model_bias: i32,
    pub astro_model_jplhor: i32,
    pub astro_model_jplhora: i32,
    pub astro_model_sidereal_time: i32,
    pub astro_model_delta_t: i32,
}
```
Raw values accepted by the `astro_model_*` fields (mirror the Rust enum discriminants in the Types section above):
`prec_longterm`/`_shortterm`: 1=IAU1976..11=Newcomb; `nutation`: 1=IAU1980..5=Woolard;
`bias`: 1=None,2=IAU2000,3=IAU2006; `jplhor`: 1=LongAgreement; `jplhora`: 1=V1,2=V2,3=V3;
`sidereal_time`: 1=IAU1976,2=IAU2006,3=IersConv2010,4=Longterm;
`delta_t`: 1=StephensonMorrison1984..5=StephensonEtc2016.

```rust
pub unsafe extern "C" fn swisseph_config_default(config: *mut SweConfig);
```
(Only exported function in this file.)

### `swisseph-ffi/src/date.rs`

```rust
pub extern "C" fn swisseph_julday(year: i32, month: i32, day: i32, hour: f64, gregflag: i32) -> f64;

pub unsafe extern "C" fn swisseph_revjul(
    jd: f64, gregflag: i32,
    year: *mut i32, month: *mut i32, day: *mut i32, hour: *mut f64,
);

pub unsafe extern "C" fn swisseph_date_conversion(
    year: i32, month: i32, day: i32, hour: f64,
    cal: c_char, // 'g'/'G' Gregorian, 'j'/'J' Julian
    tjd: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub extern "C" fn swisseph_day_of_week(jd: f64) -> i32; // 0=Monday..6=Sunday

pub unsafe extern "C" fn swisseph_utc_time_zone(
    iyear: i32, imonth: i32, iday: i32, ihour: i32, imin: i32, dsec: f64, d_timezone: f64,
    oyear: *mut i32, omonth: *mut i32, oday: *mut i32,
    ohour: *mut i32, omin: *mut i32, osec: *mut f64,
);

pub unsafe extern "C" fn swisseph_utc_to_jd(
    handle: *const SweEphemeris,
    year: i32, month: i32, day: i32, hour: i32, min: i32, sec: f64, gregflag: i32,
    dret: *mut f64, // 2 slots: [0]=JD(TT), [1]=JD(UT1)
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_jdet_to_utc(
    handle: *const SweEphemeris, tjd_et: f64, gregflag: i32,
    year: *mut i32, month: *mut i32, day: *mut i32,
    hour: *mut i32, min: *mut i32, sec: *mut f64,
); // no error return; no-op if handle null

pub unsafe extern "C" fn swisseph_jdut1_to_utc(
    handle: *const SweEphemeris, tjd_ut: f64, gregflag: i32,
    year: *mut i32, month: *mut i32, day: *mut i32,
    hour: *mut i32, min: *mut i32, sec: *mut f64,
);

pub unsafe extern "C" fn swisseph_deltat(handle: *const SweEphemeris, tjd_ut: f64) -> f64; // NAN on error

pub unsafe extern "C" fn swisseph_deltat_ex(
    handle: *const SweEphemeris, tjd_ut: f64,
    iflag: i32, // EPHMASK bits; -1 forces default tidal acceleration
    deltat: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_sidtime(handle: *const SweEphemeris, tjd_ut: f64) -> f64; // hours 0..24, NAN on error

pub unsafe extern "C" fn swisseph_sidtime0(
    handle: *const SweEphemeris, tjd_ut: f64, eps: f64, nut: f64,
) -> f64;

pub unsafe extern "C" fn swisseph_time_equ(
    handle: *const SweEphemeris, tjd_ut: f64, e: *mut f64, // days
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_lmt_to_lat(
    handle: *const SweEphemeris, tjd_lmt: f64, geolon: f64, tjd_lat: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_lat_to_lmt(
    handle: *const SweEphemeris, tjd_lat: f64, geolon: f64, tjd_lmt: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub extern "C" fn swisseph_csroundsec(x: i32) -> i32;

pub unsafe extern "C" fn swisseph_cs2timestr(
    t: i32, sep: c_char, suppress_zero: bool, buf: *mut c_char, cap: usize,
);

pub unsafe extern "C" fn swisseph_cs2lonlatstr(
    t: i32, pchar: c_char, mchar: c_char, buf: *mut c_char, cap: usize,
);

pub unsafe extern "C" fn swisseph_cs2degstr(t: i32, buf: *mut c_char, cap: usize);

pub unsafe extern "C" fn swisseph_split_deg(
    ddeg: f64, roundflag: i32, // SE_SPLIT_DEG_* bits
    deg: *mut i32, min: *mut i32, sec: *mut i32, secfr: *mut f64, sign: *mut i32,
);
```

### `swisseph-ffi/src/eclipse.rs`

Return convention: these functions return **positive** `EclipseFlags` bits on
success (0 = no eclipse); negative = error. `swisseph_rise_trans*` return -2
for a circumpolar body. All "how"/"where" structs are marshaled into flat
`f64` out-arrays by private helpers (`write_eclipse_how_attr`,
`write_lun_eclipse_how_attr`, `write_eclipse_where_geopos`) — not part of the ABI.

```rust
pub unsafe extern "C" fn swisseph_rise_trans(
    handle: *const SweEphemeris, tjd_ut: f64, ipl: i32,
    starname: *const c_char, // NULL for planet
    epheflag: i32, rsmi: i32, geopos: *const f64, // [lon, lat, height]
    atpress: f64, attemp: f64, tret: *mut f64, // 1 slot
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_rise_trans_true_hor(
    handle: *const SweEphemeris, tjd_ut: f64, ipl: i32, starname: *const c_char,
    epheflag: i32, rsmi: i32, geopos: *const f64, atpress: f64, attemp: f64,
    horhgt: f64, // -100 = auto-dip from geopos[2]
    tret: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_sol_eclipse_where(
    handle: *const SweEphemeris, tjd_ut: f64, ifl: i32,
    geopos: *mut f64, // 10 slots
    attr: *mut f64,   // 20 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_sol_eclipse_how(
    handle: *const SweEphemeris, tjd_ut: f64, ifl: i32, geopos: *const f64, // 3 values
    attr: *mut f64, // 20 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_sol_eclipse_when_glob(
    handle: *const SweEphemeris, tjd_start: f64, ifl: i32, ifltype: i32, backward: i32,
    tret: *mut f64, // 10 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_sol_eclipse_when_loc(
    handle: *const SweEphemeris, tjd_start: f64, ifl: i32, geopos: *const f64, backward: i32,
    tret: *mut f64,  // 10 slots
    attr: *mut f64,  // 20 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_lun_eclipse_how(
    handle: *const SweEphemeris, tjd_ut: f64, ifl: i32, geopos: *const f64,
    attr: *mut f64, // 20 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_lun_eclipse_when(
    handle: *const SweEphemeris, tjd_start: f64, ifl: i32, ifltype: i32, backward: i32,
    tret: *mut f64, // 10 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_lun_eclipse_when_loc(
    handle: *const SweEphemeris, tjd_start: f64, ifl: i32, geopos: *const f64, backward: i32,
    tret: *mut f64,  // 10 slots
    attr: *mut f64,  // 20 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_lun_occult_where(
    handle: *const SweEphemeris, tjd_ut: f64, ipl: i32, starname: *const c_char, ifl: i32,
    geopos: *mut f64, // 10 slots
    attr: *mut f64,   // 20 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_lun_occult_when_glob(
    handle: *const SweEphemeris, tjd_start: f64, ipl: i32, starname: *const c_char,
    ifl: i32, ifltype: i32, backward: i32,
    tret: *mut f64, // 10 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_lun_occult_when_loc(
    handle: *const SweEphemeris, tjd_start: f64, ipl: i32, starname: *const c_char,
    ifl: i32, geopos: *const f64, backward: i32,
    tret: *mut f64,  // 10 slots
    attr: *mut f64,  // 20 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;
```

### `swisseph-ffi/src/error.rs`

```rust
#[repr(i32)]
pub enum SweErrorCode {
    Ok = 0,
    InvalidBody = -1,
    UnsupportedFlags = -2,
    InvalidHouseSystem = -3,
    InvalidSiderealMode = -4,
    InvalidCalendarType = -5,
    InvalidDate = -6,
    EphemerisNotAvailable = -7,
    BeyondEphemerisLimits = -8,
    FileNotFound = -9,
    FileFormat = -10,
    CircumpolarBody = -11,
    InvalidTime = -12,
    InvalidLeapSecond = -13,
    UnsupportedEphemeris = -14,
    SiderealModeRequiresFixedStars = -15,
    CError = -16,
    NoConvergence = -17,
    Panic = -90,
    InvalidArg = -91,
    Internal = -99,
}
```
Codes are append-only by convention (never reordered/reassigned). Every
`extern "C" fn` across the crate is wrapped in an internal `ffi_guard!` macro
(catches panics via `catch_unwind`, writes "internal panic" and returns
`Panic` on panic) — not itself an ABI symbol. `error_code(&Error) -> i32` and
`write_err(buf, cap, msg)` are internal Rust helpers (not `extern "C"`) used
throughout the crate to implement this mapping.

### `swisseph-ffi/src/heliacal.rs`

Common array conventions used throughout: `dgeo` = 3 values `[longitude °E+,
latitude °N+, altitude m]`; `datm` = 4 values `[pressure hPa, temperature °C,
rel. humidity %, extinction_coeff]`; `dobs` = 6 values `[age, Snellen_ratio,
optic_type (0=eye/1=bino/2=tele), magnification, aperture_mm, transmission]`;
`helflag` bits 0-2 select ephemeris source (1=JPL,2=Swiss,4=Moshier), bits 7+
are `SE_HELFLAG_*`; `event_type` raw values match `HeliacalEventType`
(1=MorningFirst..6=AcronymchalSetting).

```rust
pub unsafe extern "C" fn swisseph_heliacal_ut(
    handle: *const SweEphemeris, tjd_start: f64,
    dgeo: *const f64, datm: *const f64, dobs: *const f64,
    object_name: *const c_char, event_type: i32, helflag: i32,
    dret: *mut f64, // 50 slots: [0]=start_visible,[1]=optimum_visibility,[2]=end_visible,[3..49]=0
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_heliacal_pheno_ut(
    handle: *const SweEphemeris, tjd_ut: f64,
    dgeo: *const f64, datm: *const f64, dobs: *const f64,
    object_name: *const c_char, event_type: i32, helflag: i32,
    darr: *mut f64, // 50 slots: [0..27]=28 HeliacalPheno fields, [28..49]=0
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_vis_limit_mag(
    handle: *const SweEphemeris, tjd_ut: f64,
    dgeo: *const f64, datm: *const f64, dobs: *const f64,
    object_name: *const c_char, helflag: i32,
    dret: *mut f64, // 8 slots: limiting_magnitude,altitude_object,azimuth_object,altitude_sun,
                    //   azimuth_sun,altitude_moon,azimuth_moon,magnitude_object
    err_buf: *mut c_char, err_cap: usize,
) -> i32; // returns vision-mode flags (0=photopic,1=scotopic,2=mixed) on success, -2 if below horizon

pub unsafe extern "C" fn swisseph_heliacal_angle(
    handle: *const SweEphemeris, tjd_ut: f64, dgeo: *const f64, datm: *const f64, dobs: *const f64,
    helflag: i32, mag: f64, azi_obj: f64, azi_sun: f64, azi_moon: f64, alt_moon: f64,
    dret: *mut f64, // 3 slots: optimal_altitude, arcus_visionis, sun_altitude_diff
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_topo_arcus_visionis(
    handle: *const SweEphemeris, tjd_ut: f64, dgeo: *const f64, datm: *const f64, dobs: *const f64,
    helflag: i32, mag: f64, azi_obj: f64, alt_obj: f64, azi_sun: f64, azi_moon: f64, alt_moon: f64,
    dret: *mut f64, // 1 slot: arcus visionis, degrees
    err_buf: *mut c_char, err_cap: usize,
) -> i32;
```

### `swisseph-ffi/src/houses.rs`

`ascmc`/`ascmc_speed` layout (10 slots): `[0]`=Asc, `[1]`=MC, `[2]`=ARMC,
`[3]`=Vertex, `[4]`=equatorial Asc, `[5]`=co-Asc(Koch), `[6]`=co-Asc(Munkasey),
`[7]`=polar Asc, `[8..9]`=0. `cusps`/`cusp_speed`: 13 slots (indices 1..12)
for normal systems, 37 slots (indices 1..36) for Gauquelin (`hsys == 'G'`).

```rust
pub unsafe extern "C" fn swisseph_houses(
    handle: *const SweEphemeris, tjd_ut: f64, geolat: f64, geolon: f64,
    hsys: i32, // ASCII char code
    cusps: *mut f64, // 13 or 37 slots
    ascmc: *mut f64, // 10 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_houses_ex(
    handle: *const SweEphemeris, tjd_ut: f64, iflag: i32, geolat: f64, geolon: f64, hsys: i32,
    cusps: *mut f64, ascmc: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_houses_ex2(
    handle: *const SweEphemeris, tjd_ut: f64, iflag: i32, geolat: f64, geolon: f64, hsys: i32,
    cusps: *mut f64, ascmc: *mut f64,
    cusp_speed: *mut f64,  // nullable
    ascmc_speed: *mut f64, // nullable
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_houses_armc( // handle-free
    armc: f64, geolat: f64, eps: f64, hsys: i32,
    cusps: *mut f64, ascmc: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_houses_armc_ex2( // handle-free
    armc: f64, geolat: f64, eps: f64, hsys: i32,
    sundec: *const f64, // nullable; required for Sunshine systems 'I'/'i'
    cusps: *mut f64, ascmc: *mut f64,
    cusp_speed: *mut f64, ascmc_speed: *mut f64, // both nullable
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_house_pos( // handle-free
    armc: f64, geolat: f64, eps: f64, hsys: i32,
    xpin: *const f64,    // 2 values: longitude, latitude
    sundec: *const f64,  // nullable
    hpos: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_house_name( // handle-free
    hsys: i32, buf: *mut c_char, cap: usize,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_gauquelin_sector(
    handle: *const SweEphemeris, tjd_ut: f64, ipl: i32, starname: *const c_char, // nullable
    iflag: i32, imeth: i32, geopos: *const f64, atpress: f64, attemp: f64,
    dgsect: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_azalt(
    handle: *const SweEphemeris, tjd_ut: f64,
    calc_flag: i32, // 0=SE_ECL2HOR, else SE_EQU2HOR
    geopos: *const f64, atpress: f64, attemp: f64,
    lapse_rate: f64, // atmospheric lapse rate (K/m); 0.0 = standard atmosphere (0.0065)
    xin: *const f64, // 2 values
    xaz: *mut f64, // 3 values: azimuth, true altitude, apparent altitude
); // void return, no err_buf; no-op on null args

pub unsafe extern "C" fn swisseph_azalt_rev(
    handle: *const SweEphemeris, tjd_ut: f64,
    calc_flag: i32, // 0=SE_HOR2ECL, else SE_HOR2EQU
    geopos: *const f64, xin: *const f64, // 2 values: azimuth, true altitude
    xout: *mut f64, // 2 values: lon/RA, lat/dec
); // void return

pub extern "C" fn swisseph_refrac( // handle-free
    inalt: f64, atpress: f64, attemp: f64,
    calc_flag: i32, // 0=SE_TRUE_TO_APP, else SE_APP_TO_TRUE
) -> f64;

pub unsafe extern "C" fn swisseph_refrac_extended( // handle-free
    inalt: f64, geoalt: f64, atpress: f64, attemp: f64, lapse_rate: f64, calc_flag: i32,
    dret: *mut f64, // 4 values: true alt, apparent alt, refraction, dip
) -> f64;
```

### `swisseph-ffi/src/pheno.rs`

`attr` (pheno) layout, 20 slots: `[0]`=phase_angle, `[1]`=phase,
`[2]`=elongation, `[3]`=apparent_diameter, `[4]`=apparent_magnitude,
`[5]`=horizontal_parallax, `[6..19]`=0. `dret` (orbital elements) layout, 50
slots, `[0..16]` populated in the same field order as `OrbitalElements`
above; `[17..49]`=0. `NodApsMethod` bits used raw: 1=MEAN, 2=OSCU, 4=OSCU_BAR,
256=FOPOINT.

Return-convention divergence from C (documented in-file): C's
`swe_solcross`/etc. return the crossing JD directly as a `double`, signaling
error via `jd < tjd_start`. This FFI instead returns `i32` status (0=OK,
negative=error) with the JD written to an out-param `jx`.

```rust
pub unsafe extern "C" fn swisseph_pheno(
    handle: *const SweEphemeris, tjd_et: f64, ipl: i32, iflag: i32,
    geopos: *const f64,           // nullable, 3 values
    sid_mode: *const SweSidMode,  // nullable
    attr: *mut f64,                // 20 slots
    flags_used: *mut i32,          // nullable
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_pheno_ut(
    handle: *const SweEphemeris, tjd_ut: f64, ipl: i32, iflag: i32,
    geopos: *const f64, sid_mode: *const SweSidMode,
    attr: *mut f64, flags_used: *mut i32,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_nod_aps(
    handle: *const SweEphemeris, tjd_et: f64, ipl: i32, iflag: i32,
    method: i32, // NodApsMethod bits
    xnasc: *mut f64, xndsc: *mut f64, xperi: *mut f64, xaphe: *mut f64, // 6 slots each
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_nod_aps_ut(
    handle: *const SweEphemeris, tjd_ut: f64, ipl: i32, iflag: i32, method: i32,
    xnasc: *mut f64, xndsc: *mut f64, xperi: *mut f64, xaphe: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_get_orbital_elements(
    handle: *const SweEphemeris, tjd_et: f64, ipl: i32, iflag: i32,
    dret: *mut f64, // 50 slots
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_orbit_max_min_true_distance(
    handle: *const SweEphemeris, tjd_et: f64, ipl: i32, iflag: i32,
    dmax: *mut f64, dmin: *mut f64, dtrue: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_solcross(
    handle: *const SweEphemeris, x2cross: f64, tjd_et: f64, iflag: i32, jx: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_solcross_ut(
    handle: *const SweEphemeris, x2cross: f64, tjd_ut: f64, iflag: i32, jx: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_mooncross(
    handle: *const SweEphemeris, x2cross: f64, tjd_et: f64, iflag: i32, jx: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_mooncross_ut(
    handle: *const SweEphemeris, x2cross: f64, tjd_ut: f64, iflag: i32, jx: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_mooncross_node(
    handle: *const SweEphemeris, tjd_et: f64, iflag: i32,
    xlon: *mut f64, xlat: *mut f64, jx: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_mooncross_node_ut(
    handle: *const SweEphemeris, tjd_ut: f64, iflag: i32,
    xlon: *mut f64, xlat: *mut f64, jx: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_helio_cross(
    handle: *const SweEphemeris, ipl: i32, x2cross: f64, tjd_et: f64, iflag: i32,
    dir: i32, // >=0 forward, <0 backward
    jx: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;

pub unsafe extern "C" fn swisseph_helio_cross_ut(
    handle: *const SweEphemeris, ipl: i32, x2cross: f64, tjd_ut: f64, iflag: i32, dir: i32,
    jx: *mut f64,
    err_buf: *mut c_char, err_cap: usize,
) -> i32;
```

### `swisseph-ffi/src/util.rs` (handle-free math utilities)

```rust
pub extern "C" fn swisseph_degnorm(x: f64) -> f64;             // normalize [0, 360)
pub extern "C" fn swisseph_radnorm(x: f64) -> f64;             // normalize [0, 2π)
pub extern "C" fn swisseph_difdegn(p1: f64, p2: f64) -> f64;   // p1-p2 normalized [0, 360)
pub extern "C" fn swisseph_difdeg2n(p1: f64, p2: f64) -> f64;  // p1-p2 normalized [-180, 180)
pub extern "C" fn swisseph_deg_midp(x1: f64, x0: f64) -> f64;  // midpoint on 360° circle
pub extern "C" fn swisseph_rad_midp(x1: f64, x0: f64) -> f64;  // midpoint on 2π circle

pub unsafe extern "C" fn swisseph_cotrans(
    xpo: *const f64, // 3 values
    xpn: *mut f64,   // 3 values
    eps: f64,
);

pub unsafe extern "C" fn swisseph_cotrans_sp(
    xpo: *const f64, // 6 values (pos + speed)
    xpn: *mut f64,   // 6 values
    eps: f64,
);
```

### FFI ABI-type summary

- Opaque handle: `SweEphemeris` (lib.rs, refcounted `Arc<Ephemeris>`; create
  via `swisseph_new`/`swisseph_share`, destroy via `swisseph_free`).
- `#[repr(C)]` structs: `SweSidMode` (lib.rs), `SweConfig` (config.rs).
- `#[repr(i32)]` enum: `SweErrorCode` (error.rs) — the uniform return-code
  contract used by nearly every function in the crate.
- No `pub const` values are exported from any FFI source file.
- `extern "C"` function count by file: lib.rs 18, config.rs 1, date.rs 18,
  eclipse.rs 12, heliacal.rs 5, houses.rs 13, pheno.rs 15, util.rs 8
  (error.rs exports none directly — its helpers are internal, not `extern "C"`).
