// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../swe_constants.dart';

/// The ephemeris-source bits of an iflag, and nothing else (SEFLG_EPHMASK).
///
/// The engine functions that take a bare "ephemeris flag" argument — riseTrans,
/// the eclipse searches, heliacalUt — want these three bits only. The obvious
/// spelling `iflag & 0xF` is wrong by one bit: 8 is SEFLG_HELCTR, so a
/// heliocentric Context would smuggle "heliocentric" into a rise/set search.
const int epheMask = seFlgJplEph | seFlgSwiEph | seFlgMosEph;

/// The ephemeris source selected by [iflag], as a flag on its own.
int epheSourceFlag(int iflag) => iflag & epheMask;

/// The flag for a calc that must return a plain **tropical ecliptic**
/// longitude/latitude: strips the sidereal, XYZ and equatorial bits.
///
/// The equatorial bit matters most: without stripping it, an Equatorial-mode
/// request feeds RA/Dec where ecliptic lon/lat is expected, silently corrupting
/// both quantities.
int tropicalEclipticFlag(int iflag) =>
    iflag & ~seFlgSidereal & ~seFlgXyz & ~seFlgEquatorial;

/// [tropicalEclipticFlag] plus the equinox of date: also strips SEFLG_J2000 and
/// SEFLG_NONUT.
///
/// This is the input contract of everything that combines a body position with
/// an Earth-orientation quantity of the Moment — `swe_azalt` with `SE_ECL2HOR`,
/// `swe_house_pos` (fed an ARMC and obliquity of date), and the meridian
/// distance (differenced against GMST of date). Handing any of them a J2000 or
/// nutation-free position mixes two frames: the body is expressed against one
/// equinox and the Earth against another, so the result is off by precession
/// (~0.4° at J2000) or nutation (~6") while claiming to be a physical az/alt.
///
/// Keep [tropicalEclipticFlag] for consumers that want a Context-frame ecliptic
/// position and only need the *representation* normalised.
int frameOfDateFlag(int iflag) =>
    tropicalEclipticFlag(iflag) & ~seFlgJ2000 & ~seFlgNoNut;

/// True when [iflag] already asks for a frame-of-date result, so a dedicated
/// [frameOfDateFlag] calc would only repeat the one the caller has in hand.
bool isFrameOfDate(int iflag) => frameOfDateFlag(iflag) == iflag;

/// The bits that anchor the coordinate grid to something other than the true
/// equinox of date. Unlike the XYZ and equatorial bits — which only change how
/// the same position is *written down* — these change the frame itself, so a
/// quantity differenced against GMST or an ARMC of date must not carry them.
const int equinoxShiftMask = seFlgSidereal | seFlgJ2000 | seFlgNoNut;

/// True when [iflag]'s equatorial output is already referred to the true
/// equinox of date, whatever else it asks for.
bool isEquinoxOfDate(int iflag) => (iflag & equinoxShiftMask) == 0;
