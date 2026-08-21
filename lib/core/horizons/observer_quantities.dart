// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

// Authoritative catalogue of JPL Horizons OBSERVER table quantity codes.
//
// Codes and labels are transcribed verbatim from the Horizons manual,
// "Definition of Observer Table Quantities"
// (https://ssd.jpl.nasa.gov/horizons/manual.html#obsquan). Do NOT guess,
// reorder, or abbreviate: a wrong or shifted code silently changes which
// columns Horizons returns, with no error. The manual currently defines
// codes 1–49 (49 was appended after the historical "1–48" range; the list
// grows tail-only, so appending future codes is safe).

/// One selectable OBSERVER quantity: its wire code and manual label.
class ObserverQuantity {
  const ObserverQuantity(this.code, this.label);

  /// The QUANTITIES wire code (e.g. `1`).
  final int code;

  /// The label as printed in the Horizons manual.
  final String label;
}

/// The full OBSERVER quantity table in code order.
const List<ObserverQuantity> observerQuantities = [
  ObserverQuantity(1, 'Astrometric RA & DEC'),
  ObserverQuantity(2, 'Apparent RA & DEC'),
  ObserverQuantity(3, 'Rates: RA & DEC'),
  ObserverQuantity(4, 'Apparent azimuth & elevation (AZ-EL)'),
  ObserverQuantity(5, 'Rates: azimuth and elevation (AZ-EL)'),
  ObserverQuantity(6, 'X & Y satellite offset & position angle'),
  ObserverQuantity(7, 'Local Apparent Sidereal Time'),
  ObserverQuantity(8, 'Airmass & visual magnitude extinction'),
  ObserverQuantity(9, 'Visual magnitude & surface brightness'),
  ObserverQuantity(10, 'Illuminated fraction'),
  ObserverQuantity(11, 'Defect of illumination'),
  ObserverQuantity(12, 'Angular separation/visibility'),
  ObserverQuantity(13, 'Target angular diameter'),
  ObserverQuantity(14, 'Observer sub-longitude & sub-latitude'),
  ObserverQuantity(15, 'Solar sub-longitude & sub-latitude'),
  ObserverQuantity(16, 'Sub-solar position angle & distance from disc center'),
  ObserverQuantity(17, 'North pole position angle & distance from disc center'),
  ObserverQuantity(18, 'Heliocentric ecliptic longitude & latitude'),
  ObserverQuantity(19, 'Solar range & range-rate (relative to target)'),
  ObserverQuantity(20, 'Target range & range rate (relative to observer)'),
  ObserverQuantity(21, 'Down-leg light-time'),
  ObserverQuantity(22, 'Speed with respect to Sun & observer'),
  ObserverQuantity(23, 'Sun-Observer-Target (apparent solar elongation) angle'),
  ObserverQuantity(24, 'Sun-Target-Observer angle'),
  ObserverQuantity(25, 'Target-Observer-Moon angle and illuminated fraction'),
  ObserverQuantity(26, 'Observer-Primary-Target angle'),
  ObserverQuantity(
    27,
    'Position angles of heliocentric radius & -velocity vector',
  ),
  ObserverQuantity(28, 'Orbit plane angle'),
  ObserverQuantity(29, 'Constellation ID'),
  ObserverQuantity(30, 'TDB-UT'),
  ObserverQuantity(31, 'Observer ecliptic longitude & latitude'),
  ObserverQuantity(32, 'Target north-pole RA & DEC'),
  ObserverQuantity(33, 'Galactic longitude & latitude'),
  ObserverQuantity(34, 'Local Apparent Solar Time'),
  ObserverQuantity(35, 'Earth to site light-time'),
  ObserverQuantity(36, 'Plane-of-sky RA and DEC pointing uncertainty'),
  ObserverQuantity(37, 'Plane-of-sky error ellipse'),
  ObserverQuantity(38, 'Plane-of-sky ellipse RSS pointing uncertainty'),
  ObserverQuantity(39, 'Uncertainties in plane-of-sky radial direction'),
  ObserverQuantity(40, 'Radar uncertainties (plane-of-sky radial direction)'),
  ObserverQuantity(41, 'True anomaly angle'),
  ObserverQuantity(42, 'Local apparent hour angle'),
  ObserverQuantity(43, 'Phase angle and bisector'),
  ObserverQuantity(
    44,
    'Apparent target-centered longitude of the Sun (apparent L_s)',
  ),
  ObserverQuantity(45, 'Inertial apparent RA & Dec'),
  ObserverQuantity(46, 'Rate: Inertial RA & DEC'),
  ObserverQuantity(
    47,
    'Sky motion: angular rate, direction position angle, and path angle',
  ),
  ObserverQuantity(
    48,
    'Sky brightness and target visual signal-to-noise ratio (SNR)',
  ),
  ObserverQuantity(49, 'Time difference UT1 - UTC'),
];

/// Codes present in [observerQuantities], for separating catalogued codes
/// (driven by the checkbox grid) from uncatalogued ones (the free-text
/// escape hatch).
final Set<int> catalogedQuantityCodes = {
  for (final q in observerQuantities) q.code,
};
