// The typed Horizons query. Structure is modelled (target / center / time /
// per-type options) so illegal combinations are unrepresentable; leaf values
// with a large lenient grammar (times, step, site coords) stay as validated
// strings. `rawOverrides` guarantees every API parameter is reachable.
//
// TYPES-FIRST SKELETON — data model + signatures only. Bodies land after review.

import 'horizons_types.dart';

/// COMMAND — the target body. Freeform because Horizons' target grammar is
/// large and we expose all of it: a name ('Ceres'), an ID ('499'), a
/// designation ('DES=1;'), or a disambiguation record number ('90000034;').
class HorizonsTarget {
  const HorizonsTarget(this.command);
  final String command;
}

/// CENTER (± COORD_TYPE, SITE_COORD) — the observing origin.
sealed class ObserverCenter {
  const ObserverCenter();
}

/// A coordinate-centre code with no site: '500@399' (geocentric), '500@10'
/// (heliocentric), '@0' (Solar System Barycentre), 'geo', an IAU site code.
class CoordinateCenter extends ObserverCenter {
  const CoordinateCenter(this.center);
  final String center;
}

/// Topocentric: `CENTER='coord@<bodyId>'` with COORD_TYPE and a SITE_COORD triple
/// ('E-longitude,latitude,altitude-km'). [bodyId] is the Horizons body number,
/// e.g. '399' for Earth.
class TopocentricCenter extends ObserverCenter {
  const TopocentricCenter({
    required this.bodyId,
    required this.coordType,
    required this.siteCoord,
  });

  final String bodyId;
  final CoordType coordType;
  final String siteCoord;
}

/// The time domain: a uniform range or an explicit list.
sealed class HorizonsTimeSpec {
  const HorizonsTimeSpec();
}

/// START_TIME / STOP_TIME / STEP_SIZE. Endpoints are raw Horizons time strings
/// (calendar 'YYYY-MMM-DD HH:MM:SS', 'JD 2451545.0', or BC dates); [step] is
/// the raw step grammar ('1 d', '10 m', '30' for a fixed count, '1 mo', 'VAR').
class TimeRange extends HorizonsTimeSpec {
  const TimeRange({
    required this.start,
    required this.stop,
    required this.step,
  });

  final String start;
  final String stop;
  final String step;
}

/// TLIST — a set of discrete epochs, each a raw Horizons time string. [type]
/// is emitted as TLIST_TYPE (required when the epochs are Julian Days — the
/// values then carry no `JD` prefix).
class TimeList extends HorizonsTimeSpec {
  const TimeList(this.times, {this.type});
  final List<String> times;
  final TimeListType? type;
}

/// EPHEM_TYPE-specific parameters. The variant *is* the ephemeris type, so an
/// observer-only field (e.g. QUANTITIES) can never coexist with a vectors query.
sealed class EphemOptions {
  const EphemOptions();
  EphemType get ephemType;
}

/// OBSERVER observables. [quantities] are QUANTITIES codes (1–48); kept as a raw
/// int set so a code we haven't catalogued is still selectable.
class ObserverOptions extends EphemOptions {
  const ObserverOptions({
    this.quantities = const {},
    this.angleFormat = AngleFormat.hoursMinutesSeconds,
    this.apparent = ApparentType.airless,
    this.rangeUnits = RangeUnits.au,
    this.suppressRangeRate = false,
    this.skipDaylight = false,
    this.elevationCutDegrees,
  });

  final Set<int> quantities;
  final AngleFormat angleFormat;
  final ApparentType apparent;
  final RangeUnits rangeUnits;
  final bool suppressRangeRate;
  final bool skipDaylight;

  /// ELEV_CUT — minimum target elevation; null leaves it unset.
  final double? elevationCutDegrees;

  @override
  EphemType get ephemType => EphemType.observer;
}

/// VECTORS state-vector output.
class VectorOptions extends EphemOptions {
  const VectorOptions({
    this.table = VectorTable.table3,
    this.correction = VectorCorrection.none,
    this.outUnits = OutUnits.kmSeconds,
    this.refPlane = RefPlane.ecliptic,
  });

  final VectorTable table;
  final VectorCorrection correction;
  final OutUnits outUnits;
  final RefPlane refPlane;

  @override
  EphemType get ephemType => EphemType.vectors;
}

/// ELEMENTS osculating-element output.
class ElementOptions extends EphemOptions {
  const ElementOptions({
    this.outUnits = OutUnits.auDays,
    this.refPlane = RefPlane.ecliptic,
  });

  final OutUnits outUnits;
  final RefPlane refPlane;

  @override
  EphemType get ephemType => EphemType.elements;
}

/// SPK binary generation (small bodies). No table-shaping parameters apply;
/// only the target and time span matter.
class SpkOptions extends EphemOptions {
  const SpkOptions();

  @override
  EphemType get ephemType => EphemType.spk;
}

/// APPROACH close-approach table. Driven by target and time span.
class ApproachOptions extends EphemOptions {
  const ApproachOptions();

  @override
  EphemType get ephemType => EphemType.approach;
}

/// Output toggles that apply across ephemeris types.
class CommonOutput {
  const CommonOutput({
    this.csvFormat = true,
    this.objData = true,
    this.extraPrecision = false,
  });

  final bool csvFormat; // CSV_FORMAT
  final bool objData; // OBJ_DATA — include the object header block
  final bool extraPrecision; // EXTRA_PREC
}

/// A complete Horizons request. Immutable; the tab rebuilds it on Run.
class HorizonsRequest {
  const HorizonsRequest({
    required this.target,
    required this.center,
    required this.time,
    required this.options,
    this.timeScale = TimeScale.ut,
    this.calendarFormat = CalendarFormat.calendar,
    this.refSystem = RefSystem.icrf,
    this.output = const CommonOutput(),
    this.rawOverrides = const {},
  });

  final HorizonsTarget target;
  final ObserverCenter center;
  final HorizonsTimeSpec time;
  final EphemOptions options;
  final TimeScale timeScale;
  final CalendarFormat calendarFormat;
  final RefSystem refSystem;
  final CommonOutput output;

  /// Escape hatch: raw CAPS parameters merged over the built map (these win),
  /// so any Horizons parameter is reachable even without a dedicated widget.
  final Map<String, String> rawOverrides;

  EphemType get ephemType => options.ephemType;

  /// The full parameter map sent to the API — `format=json`, `MAKE_EPHEM=YES`,
  /// `COMMAND`, `EPHEM_TYPE`, `CENTER`, the time and type-specific parameters —
  /// with [rawOverrides] applied last (so a raw entry wins). Every value except
  /// `format` is single-quoted as Horizons requires; `rawOverrides` values are
  /// inserted verbatim so the caller controls their own quoting.
  Map<String, String> toQueryParameters() {
    final p = <String, String>{
      'format': 'json',
      'COMMAND': _quote(target.command),
      'MAKE_EPHEM': _quote('YES'),
      'EPHEM_TYPE': _quote(ephemType.wire),
      'OBJ_DATA': _quote(_yesNo(output.objData)),
      'CSV_FORMAT': _quote(_yesNo(output.csvFormat)),
      'EXTRA_PREC': _quote(_yesNo(output.extraPrecision)),
      'REF_SYSTEM': _quote(refSystem.wire),
      'TIME_TYPE': _quote(timeScale.wire),
      'CAL_FORMAT': _quote(calendarFormat.wire),
    };
    _addCenter(p);
    _addTime(p);
    _addOptions(p);
    p.addAll(rawOverrides);
    return p;
  }

  /// The constructed GET URL, surfaced in the UI for transparency and copy.
  /// Values are percent-encoded (space as `%20`, not `+`) so Horizons reads them
  /// literally.
  String requestUrl() {
    final query = toQueryParameters().entries
        // encodeComponent leaves the single quote literal; Horizons is fed
        // %27 (as astrolog does), so encode it explicitly.
        .map((e) => '${e.key}=${_encode(e.value)}')
        .join('&');
    return '$horizonsApiEndpoint?$query';
  }

  void _addCenter(Map<String, String> p) {
    switch (center) {
      case CoordinateCenter(center: final code):
        p['CENTER'] = _quote(code);
      case TopocentricCenter(:final bodyId, :final coordType, :final siteCoord):
        p['CENTER'] = _quote('coord@$bodyId');
        p['COORD_TYPE'] = _quote(coordType.wire);
        p['SITE_COORD'] = _quote(siteCoord);
    }
  }

  void _addTime(Map<String, String> p) {
    switch (time) {
      case TimeRange(:final start, :final stop, :final step):
        p['START_TIME'] = _quote(start);
        p['STOP_TIME'] = _quote(stop);
        p['STEP_SIZE'] = _quote(step);
      case TimeList(:final times, :final type):
        // TLIST is one parameter whose value is each epoch individually quoted,
        // space-separated (up to 10,000 entries). TLIST_TYPE, when set, tells
        // Horizons how to read them (required for JD epochs — a `JD` prefix
        // inside TLIST is rejected).
        p['TLIST'] = times.map(_quote).join(' ');
        if (type != null) p['TLIST_TYPE'] = _quote(type.wire);
    }
  }

  void _addOptions(Map<String, String> p) {
    switch (options) {
      case final ObserverOptions o:
        if (o.quantities.isNotEmpty) {
          final codes = o.quantities.toList()..sort();
          p['QUANTITIES'] = _quote(codes.join(','));
        }
        p['ANG_FORMAT'] = _quote(o.angleFormat.wire);
        p['APPARENT'] = _quote(o.apparent.wire);
        p['RANGE_UNITS'] = _quote(o.rangeUnits.wire);
        p['SUPPRESS_RANGE_RATE'] = _quote(_yesNo(o.suppressRangeRate));
        p['SKIP_DAYLT'] = _quote(_yesNo(o.skipDaylight));
        if (o.elevationCutDegrees case final cut?) {
          p['ELEV_CUT'] = _quote('$cut');
        }
      case final VectorOptions o:
        p['VEC_TABLE'] = _quote(o.table.wire);
        p['VEC_CORR'] = _quote(o.correction.wire);
        p['OUT_UNITS'] = _quote(o.outUnits.wire);
        p['REF_PLANE'] = _quote(o.refPlane.wire);
      case final ElementOptions o:
        p['OUT_UNITS'] = _quote(o.outUnits.wire);
        p['REF_PLANE'] = _quote(o.refPlane.wire);
      case SpkOptions():
        break;
      case ApproachOptions():
        break;
    }
  }
}

String _quote(String value) => "'$value'";

String _encode(String value) =>
    Uri.encodeComponent(value).replaceAll("'", '%27');

String _yesNo(bool value) => value ? 'YES' : 'NO';
