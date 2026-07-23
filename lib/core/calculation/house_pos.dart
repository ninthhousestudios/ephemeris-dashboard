// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../ephemeris/ephemeris.dart';
import '../swe_constants.dart';

/// Per-Moment inputs to `swe_house_pos`, computed once and reused for every
/// body at that Moment: the ARMC from a [Ephemeris.houses] call and the true
/// obliquity from [seEclNut].
///
/// `swe_house_pos` is handle-free and cannot honour a sidereal engine config,
/// so everything feeding it is tropical: [tropicalEclipticFlag] strips the
/// sidereal, XYZ and equatorial bits, and swetest's `-fGgj` (which the seam is
/// pinned against) is tropical.
class HousePosInputs {
  const HousePosInputs({
    required this.armc,
    required this.eps,
    required this.geolat,
    required this.hsys,
  });

  final double armc;
  final double eps;
  final double geolat;
  final int hsys;
}

/// The flag for a calc that must return a plain **tropical ecliptic**
/// longitude/latitude: strips the sidereal, XYZ and equatorial bits.
///
/// Shared by the two consumers with that same input contract — `swe_house_pos`
/// (via [housePosOf]) and the horizontal transform (`swe_azalt` with
/// `SE_ECL2HOR`, swe-dashboard/69). The equatorial bit matters: without
/// stripping it, an Equatorial-mode request feeds RA/Dec where ecliptic
/// lon/lat is expected, silently corrupting both quantities.
int tropicalEclipticFlag(int iflag) =>
    iflag & ~seFlgSidereal & ~seFlgXyz & ~seFlgEquatorial;

/// Computes the per-Moment [HousePosInputs] for [hsys] at ([lat], [lon]).
HousePosInputs housePosInputs(
  Ephemeris eph, {
  required double jdUt,
  required double lat,
  required double lon,
  required int hsys,
  required int iflag,
}) {
  final calcFlag = tropicalEclipticFlag(iflag);
  final houses = eph.houses(jdUt, lat, lon, hsys);
  final eps = eph.calcUt(jdUt, seEclNut, calcFlag).longitude;
  return HousePosInputs(
    armc: houses.ascmc[2],
    eps: eps,
    geolat: lat,
    hsys: hsys,
  );
}

/// Raw `swe_house_pos` value (swetest `j`) for a point at tropical ecliptic
/// ([bodyLon], [bodyLat]): 1.0–12.999999 (1.0–36.99 Gauquelin). The integer
/// part is the house number; the fraction is the position within the house.
double housePosOf(
  Ephemeris eph,
  HousePosInputs inputs,
  double bodyLon,
  double bodyLat,
) => eph.housePos(
  inputs.armc,
  inputs.geolat,
  inputs.eps,
  inputs.hsys,
  bodyLon,
  bodyLat,
);

/// House number a raw [housePos] falls in (swetest `j` floored): 1–12 (1–36
/// Gauquelin). NaN in, 0 out.
int houseNumberOf(double housePos) => housePos.isNaN ? 0 : housePos.floor();

/// Position in degrees within the house (swetest `g`/`G`), houses treated as
/// 30° each.
double housePositionDegrees(double housePos) => (housePos - 1) * 30;
