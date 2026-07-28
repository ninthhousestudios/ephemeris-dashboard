// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

library;

import 'package:wasm_ffi/ffi.dart';
import 'package:wasm_ffi/ffi_utils.dart';

import '../wasm_state.dart' as wasm;

// ---------------------------------------------------------------------------
// wasm_ffi bindings — resolved from the loaded Emscripten module.
// Struct pointer params use Pointer<Void> — wasm_ffi has no Struct support;
// config packing is handled by the config_pack barrel with byte-offset writes.
// ---------------------------------------------------------------------------

DynamicLibrary get _lib => wasm.wasmLibrary;

late final swissephVersion = _lib
    .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
      'swisseph_version',
    );

late final swissephConfigDefault = _lib
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'swisseph_config_default',
    );

late final swissephNew = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Pointer<Void>>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(Pointer<Void>, Pointer<Pointer<Void>>, Pointer<Utf8>, int)
    >('swisseph_new');

late final swissephFree = _lib
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
      'swisseph_free',
    );

int swissephShare(
  Pointer<Void> handle,
  Pointer<Pointer<Void>> out,
  Pointer<Utf8> errBuf,
  int errCap,
) => throw UnsupportedError('share() is not supported on web');

late final swissephCalcUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_calc_ut');

late final swissephCalc = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_calc');

late final swissephCalcPctr = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        int,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_calc_pctr');

// ---------------------------------------------------------------------------
// Date/time functions (handle-free unless noted)
// ---------------------------------------------------------------------------

late final swissephJulday = _lib
    .lookupFunction<
      Double Function(Int32, Int32, Int32, Double, Int32),
      double Function(int, int, int, double, int)
    >('swisseph_julday');

late final swissephRevjul = _lib
    .lookupFunction<
      Void Function(
        Double,
        Int32,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
      ),
      void Function(
        double,
        int,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
      )
    >('swisseph_revjul');

late final swissephDateConversion = _lib
    .lookupFunction<
      Int32 Function(
        Int32,
        Int32,
        Int32,
        Double,
        Int8,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        int,
        int,
        int,
        double,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_date_conversion');

late final swissephDayOfWeek = _lib
    .lookupFunction<Int32 Function(Double), int Function(double)>(
      'swisseph_day_of_week',
    );

late final swissephUtcTimeZone = _lib
    .lookupFunction<
      Void Function(
        Int32,
        Int32,
        Int32,
        Int32,
        Int32,
        Double,
        Double,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
      ),
      void Function(
        int,
        int,
        int,
        int,
        int,
        double,
        double,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
      )
    >('swisseph_utc_time_zone');

late final swissephUtcToJd = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Int32,
        Int32,
        Int32,
        Int32,
        Int32,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        int,
        int,
        int,
        int,
        int,
        double,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_utc_to_jd');

late final swissephJdetToUtc = _lib
    .lookupFunction<
      Void Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
      ),
      void Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
      )
    >('swisseph_jdet_to_utc');

late final swissephJdut1ToUtc = _lib
    .lookupFunction<
      Void Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
      ),
      void Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
      )
    >('swisseph_jdut1_to_utc');

late final swissephDeltat = _lib
    .lookupFunction<
      Double Function(Pointer<Void>, Double),
      double Function(Pointer<Void>, double)
    >('swisseph_deltat');

late final swissephTimeEqu = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(Pointer<Void>, double, Pointer<Double>, Pointer<Utf8>, int)
    >('swisseph_time_equ');

late final swissephLmtToLat = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Double,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        double,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_lmt_to_lat');

late final swissephLatToLmt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Double,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        double,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_lat_to_lmt');

late final swissephGetPlanetName = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Int32,
        Pointer<Utf8>,
        Size,
        Pointer<Utf8>,
        Size,
      ),
      int Function(Pointer<Void>, int, Pointer<Utf8>, int, Pointer<Utf8>, int)
    >('swisseph_get_planet_name');

late final swissephSplitDeg = _lib
    .lookupFunction<
      Void Function(
        Double,
        Int32,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
        Pointer<Int32>,
      ),
      void Function(
        double,
        int,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Int32>,
        Pointer<Double>,
        Pointer<Int32>,
      )
    >('swisseph_split_deg');

late final swissephSidtime = _lib
    .lookupFunction<
      Double Function(Pointer<Void>, Double),
      double Function(Pointer<Void>, double)
    >('swisseph_sidtime');

late final swissephSidtime0 = _lib
    .lookupFunction<
      Double Function(Pointer<Void>, Double, Double, Double),
      double Function(Pointer<Void>, double, double, double)
    >('swisseph_sidtime0');

// ---------------------------------------------------------------------------
// Houses & Gauquelin
// ---------------------------------------------------------------------------

late final swissephHousesEx2 = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Double,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        double,
        double,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_houses_ex2');

late final swissephHousesArmcEx2 = _lib
    .lookupFunction<
      Int32 Function(
        Double,
        Double,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        double,
        double,
        double,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_houses_armc_ex2');

late final swissephHousePos = _lib
    .lookupFunction<
      Int32 Function(
        Double,
        Double,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        double,
        double,
        double,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_house_pos');

late final swissephHouseName = _lib
    .lookupFunction<
      Int32 Function(Int32, Pointer<Utf8>, Size, Pointer<Utf8>, Size),
      int Function(int, Pointer<Utf8>, int, Pointer<Utf8>, int)
    >('swisseph_house_name');

late final swissephGauquelinSector = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Utf8>,
        Int32,
        Int32,
        Pointer<Double>,
        Double,
        Double,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Utf8>,
        int,
        int,
        Pointer<Double>,
        double,
        double,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_gauquelin_sector');

// ---------------------------------------------------------------------------
// Ayanamsa
// ---------------------------------------------------------------------------

late final swissephGetAyanamsaEx = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_get_ayanamsa_ex');

late final swissephGetAyanamsaExUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_get_ayanamsa_ex_ut');

late final swissephGetAyanamsa = _lib
    .lookupFunction<
      Double Function(Pointer<Void>, Double, Pointer<Void>),
      double Function(Pointer<Void>, double, Pointer<Void>)
    >('swisseph_get_ayanamsa');

late final swissephGetAyanamsaUt = _lib
    .lookupFunction<
      Double Function(Pointer<Void>, Double, Pointer<Void>),
      double Function(Pointer<Void>, double, Pointer<Void>)
    >('swisseph_get_ayanamsa_ut');

late final swissephGetAyanamsaName = _lib
    .lookupFunction<
      Int32 Function(Int32, Pointer<Utf8>, Size, Pointer<Utf8>, Size),
      int Function(int, Pointer<Utf8>, int, Pointer<Utf8>, int)
    >('swisseph_get_ayanamsa_name');

// ---------------------------------------------------------------------------
// Eclipses & occultations
// ---------------------------------------------------------------------------

late final swissephSolEclipseWhere = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_sol_eclipse_where');

late final swissephSolEclipseHow = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_sol_eclipse_how');

late final swissephSolEclipseWhenGlob = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_sol_eclipse_when_glob');

late final swissephSolEclipseWhenLoc = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Double>,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Double>,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_sol_eclipse_when_loc');

late final swissephLunEclipseHow = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_lun_eclipse_how');

late final swissephLunEclipseWhen = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_lun_eclipse_when');

late final swissephLunEclipseWhenLoc = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Double>,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Double>,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_lun_eclipse_when_loc');

late final swissephLunOccultWhere = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Utf8>,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Utf8>,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_lun_occult_where');

late final swissephLunOccultWhenGlob = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Utf8>,
        Int32,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Utf8>,
        int,
        int,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_lun_occult_when_glob');

late final swissephLunOccultWhenLoc = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Utf8>,
        Int32,
        Pointer<Double>,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Utf8>,
        int,
        Pointer<Double>,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_lun_occult_when_loc');

// ---------------------------------------------------------------------------
// Rise/set & crossings (task /32)
// ---------------------------------------------------------------------------

late final swissephRiseTrans = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Utf8>,
        Int32,
        Int32,
        Pointer<Double>,
        Double,
        Double,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Utf8>,
        int,
        int,
        Pointer<Double>,
        double,
        double,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_rise_trans');

late final swissephRiseTransTrueHor = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Utf8>,
        Int32,
        Int32,
        Pointer<Double>,
        Double,
        Double,
        Double,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Utf8>,
        int,
        int,
        Pointer<Double>,
        double,
        double,
        double,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_rise_trans_true_hor');

late final swissephSolcross = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        double,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_solcross');

late final swissephSolcrossUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        double,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_solcross_ut');

late final swissephMooncross = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        double,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_mooncross');

late final swissephMooncrossUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        double,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_mooncross_ut');

late final swissephMooncrossNode = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_mooncross_node');

late final swissephMooncrossNodeUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_mooncross_node_ut');

late final swissephHelioCross = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Int32,
        Double,
        Double,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        int,
        double,
        double,
        int,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_helio_cross');

late final swissephHelioCrossUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Int32,
        Double,
        Double,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        int,
        double,
        double,
        int,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_helio_cross_ut');

// ---------------------------------------------------------------------------
// Phenomena, orbital, nodes/apsides (task /33)
// ---------------------------------------------------------------------------

late final swissephPheno = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_pheno');

late final swissephPhenoUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_pheno_ut');

late final swissephNodAps = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_nod_aps');

late final swissephNodApsUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_nod_aps_ut');

late final swissephGetOrbitalElements = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_get_orbital_elements');

late final swissephOrbitMaxMinTrueDistance = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        int,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_orbit_max_min_true_distance');

// ---------------------------------------------------------------------------
// Horizon & refraction (task /34)
// ---------------------------------------------------------------------------

late final swissephAzalt = _lib
    .lookupFunction<
      Void Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Double>,
        Double,
        Double,
        Double,
        Pointer<Double>,
        Pointer<Double>,
      ),
      void Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Double>,
        double,
        double,
        double,
        Pointer<Double>,
        Pointer<Double>,
      )
    >('swisseph_azalt');

late final swissephAzaltRev = _lib
    .lookupFunction<
      Void Function(
        Pointer<Void>,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
      ),
      void Function(
        Pointer<Void>,
        double,
        int,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
      )
    >('swisseph_azalt_rev');

late final swissephRefrac = _lib
    .lookupFunction<
      Double Function(Double, Double, Double, Int32),
      double Function(double, double, double, int)
    >('swisseph_refrac');

late final swissephRefracExtended = _lib
    .lookupFunction<
      Double Function(
        Double,
        Double,
        Double,
        Double,
        Double,
        Int32,
        Pointer<Double>,
      ),
      double Function(
        double,
        double,
        double,
        double,
        double,
        int,
        Pointer<Double>,
      )
    >('swisseph_refrac_extended');

// ---------------------------------------------------------------------------
// Fixed stars (task /33)
// ---------------------------------------------------------------------------

late final swissephFixstar2 = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Utf8>,
        Pointer<Utf8>,
        Size,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Utf8>,
        Pointer<Utf8>,
        int,
        double,
        int,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_fixstar2');

late final swissephFixstar2Ut = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Utf8>,
        Pointer<Utf8>,
        Size,
        Double,
        Int32,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Utf8>,
        Pointer<Utf8>,
        int,
        double,
        int,
        Pointer<Double>,
        Pointer<Void>,
        Pointer<Double>,
        Pointer<Int32>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_fixstar2_ut');

late final swissephFixstar2Mag = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Pointer<Utf8>,
        Pointer<Utf8>,
        Size,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        Pointer<Utf8>,
        Pointer<Utf8>,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_fixstar2_mag');

// ---------------------------------------------------------------------------
// Heliacal (task /33)
// ---------------------------------------------------------------------------

late final swissephHeliacalUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_heliacal_ut');

late final swissephHeliacalPhenoUt = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Int32,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_heliacal_pheno_ut');

late final swissephVisLimitMag = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        Int32,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_vis_limit_mag');

late final swissephHeliacalAngle = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Int32,
        Double,
        Double,
        Double,
        Double,
        Double,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        int,
        double,
        double,
        double,
        double,
        double,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_heliacal_angle');

late final swissephTopoArcusVisionis = _lib
    .lookupFunction<
      Int32 Function(
        Pointer<Void>,
        Double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        Int32,
        Double,
        Double,
        Double,
        Double,
        Double,
        Double,
        Pointer<Double>,
        Pointer<Utf8>,
        Size,
      ),
      int Function(
        Pointer<Void>,
        double,
        Pointer<Double>,
        Pointer<Double>,
        Pointer<Double>,
        int,
        double,
        double,
        double,
        double,
        double,
        double,
        Pointer<Double>,
        Pointer<Utf8>,
        int,
      )
    >('swisseph_topo_arcus_visionis');

// ---------------------------------------------------------------------------
// Math
// ---------------------------------------------------------------------------

late final swissephCotrans = _lib
    .lookupFunction<
      Void Function(Pointer<Double>, Pointer<Double>, Double),
      void Function(Pointer<Double>, Pointer<Double>, double)
    >('swisseph_cotrans');

late final swissephCotransSp = _lib
    .lookupFunction<
      Void Function(Pointer<Double>, Pointer<Double>, Double),
      void Function(Pointer<Double>, Pointer<Double>, double)
    >('swisseph_cotrans_sp');
