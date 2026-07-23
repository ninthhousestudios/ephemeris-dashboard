// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

export 'package:swisseph_rs/swisseph_rs.dart'
    show SweException, InvalidArgException;

export 'ephemeris/result_types.dart';

// Special body IDs
const seEclNut = -1;

// Body IDs
const seSun = 0;
const seMoon = 1;
const seMercury = 2;
const seVenus = 3;
const seMars = 4;
const seJupiter = 5;
const seSaturn = 6;
const seUranus = 7;
const seNeptune = 8;
const sePluto = 9;
const seMeanNode = 10;
const seTrueNode = 11;
const seMeanApog = 12;
const seOscuApog = 13;
const seEarth = 14;
const seChiron = 15;
const sePholus = 16;
const seCeres = 17;
const sePallas = 18;
const seJuno = 19;
const seVesta = 20;
const seIntpApog = 21;
const seIntpPerg = 22;
const seCupido = 40;
const seHades = 41;
const seZeus = 42;
const seKronos = 43;
const seApollon = 44;
const seAdmetos = 45;
const seVulkanus = 46;
const sePoseidon = 47;
const sePlmoonOffset = 9000;
const seAstOffset = 10000;

// Ephemeris selection
const seFlgJplEph = 1;
const seFlgSwiEph = 2;
const seFlgMosEph = 4;

// Calculation flags
const seFlgHelCtr = 8;
const seFlgTruePos = 16;
const seFlgJ2000 = 32;
const seFlgNoNut = 64;
const seFlgSpeed3 = 128;
const seFlgSpeed = 256;
const seFlgNoGdefl = 512;
const seFlgNoAberr = 1024;
const seFlgEquatorial = 2048;
const seFlgXyz = 4096;
const seFlgRadians = 8192;
const seFlgBaryCtr = 16384;
const seFlgTopoCtr = 32768;
const seFlgSidereal = 65536;
const seFlgIcrs = 131072;
const seFlgJplHor = 262144;
const seFlgJplHorApprox = 524288;
const seFlgCenterBody = 1048576;

// Coordinate transformations
const seEcl2hor = 0;
const seEqu2hor = 1;
const seHor2ecl = 0;
const seHor2equ = 1;
const seTrueToApp = 0;
const seAppToTrue = 1;

// Eclipse types
const seEclCentral = 1;
const seEclNonCentral = 2;
const seEclTotal = 4;
const seEclAnnular = 8;
const seEclPartial = 16;
const seEclHybrid = 32;
const seEclPenumbral = 64;

// Eclipse/occultation visibility bits (returned in the flag word)
const seEclVisible = 128;
const seEclMaxVisible = 256;
const seEclOccBegDaylight = 8192;
const seEclOccEndDaylight = 16384;
const seEclOneTry = 32768;

// Ayanamsa modes
const seSidmFaganBradley = 0;
const seSidmLahiri = 1;
const seSidmDeluce = 2;
const seSidmRaman = 3;
const seSidmUshashashi = 4;
const seSidmKrishnamurti = 5;
const seSidmDjwhalKhul = 6;
const seSidmYukteshwar = 7;
const seSidmJnBhasin = 8;
const seSidmBabylKugler1 = 9;
const seSidmBabylKugler2 = 10;
const seSidmBabylKugler3 = 11;
const seSidmBabylHuber = 12;
const seSidmBabylEtpsc = 13;
const seSidmAldebaran15tau = 14;
const seSidmHipparchos = 15;
const seSidmSassanian = 16;
const seSidmGalcent0sag = 17;
const seSidmJ2000 = 18;
const seSidmJ1900 = 19;
const seSidmB1950 = 20;
const seSidmSuryasiddhanta = 21;
const seSidmSuryasiddhantaMsun = 22;
const seSidmAryabhata = 23;
const seSidmAryabhataMsun = 24;
const seSidmSsRevati = 25;
const seSidmSsCitra = 26;
const seSidmTrueCitra = 27;
const seSidmTrueRevati = 28;
const seSidmTruePushya = 29;
const seSidmGalcentRgilbrand = 30;
const seSidmGalequIau1958 = 31;
const seSidmGalequTrue = 32;
const seSidmGalequMula = 33;
const seSidmGalalignMardyks = 34;
const seSidmTrueMula = 35;
const seSidmGalcentMulaWilhelm = 36;
const seSidmAryabhata522 = 37;
const seSidmBabylBritton = 38;
const seSidmTrueSheoran = 39;
const seSidmGalcentCochrane = 40;
const seSidmGalequFiorenza = 41;
const seSidmValensMoon = 42;
const seSidmLahiri1940 = 43;
const seSidmLahiriVp285 = 44;
const seSidmKrishnamurtiVp291 = 45;
const seSidmLahiriIcrc = 46;
const seSidmUser = 255;

// Heliacal phenomena
const seHeliacalRising = 1;
const seHeliacalSetting = 2;
const seMorningFirst = 1;
const seEveningLast = 2;
const seEveningFirst = 3;
const seMorningLast = 4;

// Rise/set flags
const seCalcRise = 1;
const seCalcSet = 2;
const seCalcMTransit = 4;
const seCalcITransit = 8;

// Rise/set modifier bits (rsmi), OR'd onto the event-type bits above. Values are
// the canonical Swiss Ephemeris bits (swephexp.h / swisseph_rs RiseSetFlags) and
// are passed through the Ephemeris seam untranslated, so they MUST match exactly.
// They do not double contiguously — GEOCTR sits at 128 and DISC_BOTTOM jumps to
// 8192 — so do not "extrapolate" new ones.
const seBitGeoctrNoEclLat = 128;
const seBitDiscCenter = 256;
const seBitNoRefraction = 512;
const seBitCivilTwilight = 1024;
const seBitNauticTwilight = 2048;
const seBitAstroTwilight = 4096;
const seBitDiscBottom = 8192;
const seBitFixedDiscSize = 16384;
const seBitForceSlow = 32768;
// HINDU_RISING is a composite: DISC_CENTER | NO_REFRACTION | GEOCTR_NO_ECL_LAT.
const seBitHinduRising =
    seBitDiscCenter | seBitNoRefraction | seBitGeoctrNoEclLat;

// Split degree flags
const seSplitDegRoundSec = 1;
const seSplitDegZodiacal = 8;
const seSplitDegKeepSign = 16;

// House system codes (ASCII values)
const hsysPlacidus = 0x50;
const hsysKoch = 0x4B;
const hsysPorphyry = 0x4F;
const hsysRegiomontanus = 0x52;
const hsysCampanus = 0x43;
const hsysEqual = 0x45;
const hsysWholeSign = 0x57;
const hsysAlcabitius = 0x42;
const hsysTopocentric = 0x54;
const hsysMeridian = 0x58;
const hsysMorinus = 0x4D;
const hsysKrusinski = 0x55;
const hsysVehlow = 0x56;
const hsysGauquelin = 0x47;

// Node/apsides method flags
const seNodBitMean = 1;
const seNodBitOscu = 2;
const seNodBitOscuBar = 4;
const seNodBitFoPoint = 256;
