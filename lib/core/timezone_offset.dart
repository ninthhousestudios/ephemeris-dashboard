// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Resolve an IANA time-zone id + a civil date into a UTC offset, honestly.
///
/// The offset a birth chart needs is `(zone, date) -> hours`, and it is only as
/// trustworthy as tzdata — which is explicitly non-authoritative before 1970,
/// returns Local Mean Time (odd fractional offsets) before a zone's first
/// standard-time transition, and is ambiguous at DST boundaries (a fall-back
/// wall time occurs twice; a spring-forward wall time never occurs). Astrology
/// charts land in these danger zones constantly, so this module never just
/// returns a number: it returns a [TzOffset] carrying the offset *and* the
/// [TzWarning]s that say when to distrust it (swe-dashboard/112).
///
/// Pure and Flutter-free — [tz] resolution is deterministic against the bundled
/// tzdata, so every case is unit-testable without a widget or an engine.
library;

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'jd_utils.dart' show Civil;

/// Reasons a derived offset should not be presented as authoritative.
enum TzWarning {
  /// Date is before 1970 — tzdata is explicitly non-authoritative there.
  preModern,

  /// The zone was on Local Mean Time (before its first standard-time
  /// transition): a longitude-derived fractional offset, not a legal zone.
  lmt,

  /// The local wall time falls in a DST spring-forward gap — it never occurred.
  gap,

  /// The local wall time falls in a DST fall-back fold — it occurred twice, so
  /// which offset applies is ambiguous.
  ambiguous,
}

/// A zone→offset resolution with its confidence.
class TzOffset {
  const TzOffset({
    required this.offsetHours,
    required this.resolved,
    required this.warnings,
    required this.abbreviation,
  });

  /// The zone id was not found in tzdata. [offsetHours] is meaningless; callers
  /// must keep whatever offset they had.
  const TzOffset.unresolved()
    : offsetHours = 0.0,
      resolved = false,
      warnings = const {},
      abbreviation = null;

  /// Hours east of UTC (can be fractional — a :45 zone, or an LMT value).
  final double offsetHours;

  /// Whether the zone id resolved against tzdata at all.
  final bool resolved;

  /// Empty means high confidence; any entry means the value is approximate.
  final Set<TzWarning> warnings;

  /// The zone abbreviation in effect (e.g. `EDT`, `CET`, `LMT`), for display.
  final String? abbreviation;

  /// True when this offset must be flagged rather than shown as fact.
  bool get lowConfidence => !resolved || warnings.isNotEmpty;
}

/// Idempotent, cheap after the first call — safe to call from any entry point
/// (tests included) rather than relying on a startup ordering.
void ensureTimeZonesInitialized() {
  if (tz.timeZoneDatabase.isInitialized) return;
  tzdata.initializeTimeZones();
}

// To enumerate a wall time's candidate offsets we sample the zone this far
// either side of it. The window must EXCEED the largest offset in play: a fold's
// earlier occurrence sits one whole offset before the naive (read-as-UTC) wall
// time, so a 12h window can't reach it for zones east of UTC+12 — Pacific/Auckland
// (+13) and Pacific/Chatham (+13:45) folds would then read as unambiguous. 15h
// clears +13:45 (and the +14:00 max) while staying far below the gap between two
// DST transitions, so the sample pair {before, after} still straddles exactly one.
const int _windowMs = 15 * 3600 * 1000;

/// Offset for a *local wall-clock* civil time in [zoneId] — the direction where
/// DST gaps and folds live, so [local] is treated as the anchor and the
/// ambiguity is detected and flagged (never silently resolved to a guess).
///
/// [local] MUST be proleptic-Gregorian civil fields: tzdata's transition table
/// is Gregorian-indexed, so a caller on the Julian (or auto-pre-reform) calendar
/// must reinterpret the wall date first (`JdUtils.toGregorianCivil`) — otherwise
/// the ~13-day reform delta lands the query on the wrong side of a transition.
/// `y/m/d/h/m/s` precision is enough for zone-era selection; do not pass a
/// [DateTime] built from a Julian-only historical date (see lesson 019f9135).
TzOffset resolveTzOffsetForLocal(String zoneId, Civil local) {
  ensureTimeZonesInitialized();
  final tz.Location loc;
  try {
    loc = tz.getLocation(zoneId);
  } on Exception {
    return const TzOffset.unresolved();
  }

  // The wall time read as if it were UTC — the reference point the true offset
  // is measured back from.
  final naiveUtcMs = DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
    local.second,
  ).millisecondsSinceEpoch;

  int offsetAt(int ms) => loc.timeZone(ms).offset.inMilliseconds;

  final offBefore = offsetAt(naiveUtcMs - _windowMs);
  final offAfter = offsetAt(naiveUtcMs + _windowMs);

  // An offset o is valid for this wall time iff applying it lands on an instant
  // where o is actually in effect. 0 valid ⇒ gap, 2 valid ⇒ fold.
  bool valid(int o) => offsetAt(naiveUtcMs - o) == o;
  final beforeValid = valid(offBefore);
  final afterValid = offAfter != offBefore && valid(offAfter);

  int chosen;
  final warnings = <TzWarning>{};
  if (!beforeValid && !afterValid) {
    // Spring-forward gap: the wall time never occurred. Interpret it as
    // post-transition (matching the common clocks-jumped-forward reading).
    chosen = offAfter;
    warnings.add(TzWarning.gap);
  } else if (beforeValid && afterValid) {
    // Fall-back fold: the wall time occurred twice. Take the earlier occurrence.
    chosen = offBefore;
    warnings.add(TzWarning.ambiguous);
  } else {
    chosen = beforeValid ? offBefore : offAfter;
  }

  final chosenZone = loc.timeZone(naiveUtcMs - chosen);
  if (_isMeanTime(chosenZone.abbreviation, chosen)) warnings.add(TzWarning.lmt);
  if (local.year < 1970) warnings.add(TzWarning.preModern);

  return TzOffset(
    offsetHours: chosen / 3600000.0,
    resolved: true,
    warnings: warnings,
    abbreviation: chosenZone.abbreviation,
  );
}

/// Offset for a *UTC instant* (given as [utc] civil fields ≈ the canonical UT1
/// Moment) in [zoneId]. UTC→local is unambiguous, so this cannot gap or fold —
/// only [TzWarning.preModern] / [TzWarning.lmt] apply. Used when the entry is an
/// instant (a raw JD, "now") rather than a wall time.
///
/// [utc] MUST be proleptic-Gregorian civil fields (tzdata's calendar). The
/// instant→offset map is calendar-independent, so derive them with
/// `civilFieldsOn(jd, Calendar.gregorian)`, never the Context's display calendar.
TzOffset resolveTzOffsetForInstant(String zoneId, Civil utc) {
  ensureTimeZonesInitialized();
  final tz.Location loc;
  try {
    loc = tz.getLocation(zoneId);
  } on Exception {
    return const TzOffset.unresolved();
  }

  final ms = DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
  ).millisecondsSinceEpoch;
  final zone = loc.timeZone(ms);
  final offMs = zone.offset.inMilliseconds;

  final warnings = <TzWarning>{};
  if (_isMeanTime(zone.abbreviation, offMs)) warnings.add(TzWarning.lmt);
  if (utc.year < 1970) warnings.add(TzWarning.preModern);

  return TzOffset(
    offsetHours: offMs / 3600000.0,
    resolved: true,
    warnings: warnings,
    abbreviation: zone.abbreviation,
  );
}

// Pre-standard-time mean time: tzdata labels the first entry `LMT`, but named
// local mean times exist too (`PMT` Paris, `BMT` Bangkok, …). Their defining
// trait is a longitude-derived offset carried to the second — a legal
// whole/half/:45 zone is always a whole number of minutes, so a sub-minute
// remainder is the version-independent signal.
bool _isMeanTime(String abbreviation, int offsetMs) =>
    abbreviation == 'LMT' || offsetMs % 60000 != 0;

/// A one-line, human summary of [warnings] for a tooltip — empty string when
/// there is nothing to flag.
String describeTzWarnings(Set<TzWarning> warnings) {
  final parts = <String>[
    for (final w in warnings)
      switch (w) {
        TzWarning.preModern =>
          'before 1970, where time-zone data is not authoritative',
        TzWarning.lmt => 'Local Mean Time, before standard time existed here',
        TzWarning.gap =>
          'a daylight-saving spring-forward gap — this local time never occurred',
        TzWarning.ambiguous =>
          'a daylight-saving fall-back — this local time occurred twice',
      },
  ];
  return parts.join('; ');
}
