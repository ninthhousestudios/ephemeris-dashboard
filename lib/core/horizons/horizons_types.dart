// Fixed-vocabulary enumerations for the JPL Horizons API. Each carries its
// exact `wire` token as sent in the request. Tokens verified against
// https://ssd-api.jpl.nasa.gov/doc/horizons.html.
//
/// The Horizons API endpoint. Single source of truth for the base URL, shared
/// by request-URL construction and the client.
const horizonsApiEndpoint = 'https://ssd.jpl.nasa.gov/api/horizons.api';

/// EPHEM_TYPE — the top-level query mode. Selecting one governs which
/// [EphemOptions] variant (and therefore which parameters) apply.
enum EphemType {
  observer('OBSERVER'),
  vectors('VECTORS'),
  elements('ELEMENTS'),
  spk('SPK'),
  approach('APPROACH');

  const EphemType(this.wire);
  final String wire;
}

/// TIME_TYPE — the time scale start/stop/list values are expressed in.
enum TimeScale {
  ut('UT'),
  tt('TT'),
  tdb('TDB');

  const TimeScale(this.wire);
  final String wire;
}

/// CAL_FORMAT — how output epochs are printed.
enum CalendarFormat {
  calendar('CAL'),
  julianDay('JD'),
  both('BOTH');

  const CalendarFormat(this.wire);
  final String wire;
}

/// TLIST_TYPE — how the epochs in a discrete [TimeList] are interpreted.
/// Required when the epochs are Julian Days: Horizons rejects a `JD` prefix
/// inside TLIST and wants the type as a separate parameter (the BATVAR error).
enum TimeListType {
  calendar('CAL'),
  jd('JD'),
  mjd('MJD');

  const TimeListType(this.wire);
  final String wire;
}

/// COORD_TYPE — interpretation of a topocentric SITE_COORD triple.
enum CoordType {
  geodetic('GEODETIC'),
  cylindrical('CYLINDRICAL');

  const CoordType(this.wire);
  final String wire;
}

/// REF_SYSTEM — inertial reference frame.
enum RefSystem {
  icrf('ICRF'),
  b1950('B1950');

  const RefSystem(this.wire);
  final String wire;
}

/// REF_PLANE — reference plane for VECTORS and ELEMENTS output.
enum RefPlane {
  ecliptic('ECLIPTIC'),
  frame('FRAME'),
  bodyEquator('BODY EQUATOR');

  const RefPlane(this.wire);
  final String wire;
}

/// OUT_UNITS — distance/time units for VECTORS and ELEMENTS.
enum OutUnits {
  kmSeconds('KM-S'),
  auDays('AU-D'),
  kmDays('KM-D');

  const OutUnits(this.wire);
  final String wire;
}

/// VEC_TABLE — which component set a VECTORS table prints (1–6). The optional
/// `x`/`a`/`r`/`p` modifiers are reached via [HorizonsRequest.rawOverrides]
/// rather than multiplied into the enum. Human labels come from the manual at
/// UI-build time; identifiers stay numeric to avoid baking in possibly-wrong
/// semantics.
enum VectorTable {
  table1('1'),
  table2('2'),
  table3('3'),
  table4('4'),
  table5('5'),
  table6('6');

  const VectorTable(this.wire);
  final String wire;
}

/// VEC_CORR — aberration correction applied to vectors.
enum VectorCorrection {
  none('NONE'),
  lightTime('LT'),
  lightTimeStellar('LT+S');

  const VectorCorrection(this.wire);
  final String wire;
}

/// ANG_FORMAT — angle rendering for OBSERVER output.
enum AngleFormat {
  hoursMinutesSeconds('HMS'),
  degrees('DEG');

  const AngleFormat(this.wire);
  final String wire;
}

/// APPARENT — whether OBSERVER apparent coordinates include refraction.
enum ApparentType {
  airless('AIRLESS'),
  refracted('REFRACTED');

  const ApparentType(this.wire);
  final String wire;
}

/// RANGE_UNITS — distance units for OBSERVER range quantities.
enum RangeUnits {
  au('AU'),
  km('KM');

  const RangeUnits(this.wire);
  final String wire;
}

/// TP_TYPE — how a returned ELEMENTS periapsis time (Tp) is expressed.
enum PeriapsisTimeType {
  absolute('ABSOLUTE'),
  relative('RELATIVE');

  const PeriapsisTimeType(this.wire);
  final String wire;
}

/// CA_TABLE_TYPE — APPROACH close-approach table detail. EXTENDED adds Julian
/// Day numbers and, when a covariance exists, B-plane data.
enum ApproachTableType {
  standard('STANDARD'),
  extended('EXTENDED');

  const ApproachTableType(this.wire);
  final String wire;
}
