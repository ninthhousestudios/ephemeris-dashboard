#!/usr/bin/env bash
set -euo pipefail

# Build swisseph-ffi as an Emscripten wasm module via the rust/ shim crate.
#
# Requirements:
#   - Rust toolchain with wasm32-unknown-emscripten target
#   - Emscripten SDK (emcc on PATH)
#
# Output: swisseph_ffi.js + swisseph_ffi.wasm in this directory.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RUST_DIR="$PROJECT_DIR/rust"

if [ ! -f "$RUST_DIR/Cargo.toml" ]; then
  echo "ERROR: rust/Cargo.toml not found at $RUST_DIR" >&2
  exit 1
fi

echo "Building swisseph-rs-dart for wasm32-unknown-emscripten..."
RUSTFLAGS="-C panic=abort" cargo build \
  --target wasm32-unknown-emscripten \
  --manifest-path "$RUST_DIR/Cargo.toml" \
  --release

DEPS_DIR="$RUST_DIR/target/wasm32-unknown-emscripten/release/deps"
LIB=$(find "$DEPS_DIR" -name 'libswisseph_ffi-*.a' -print -quit)
if [ -z "$LIB" ]; then
  echo "ERROR: libswisseph_ffi-*.a not found in $DEPS_DIR" >&2
  exit 1
fi
echo "Using: $LIB"

EXPORTS='[
  "_swisseph_version","_swisseph_config_default",
  "_swisseph_new","_swisseph_free","_swisseph_share",
  "_swisseph_calc_ut","_swisseph_calc","_swisseph_calc_pctr",
  "_swisseph_julday","_swisseph_revjul","_swisseph_date_conversion",
  "_swisseph_day_of_week","_swisseph_utc_time_zone",
  "_swisseph_utc_to_jd","_swisseph_jdet_to_utc","_swisseph_jdut1_to_utc",
  "_swisseph_deltat","_swisseph_sidtime","_swisseph_sidtime0",
  "_swisseph_time_equ",
  "_swisseph_lmt_to_lat","_swisseph_lat_to_lmt",
  "_swisseph_get_planet_name","_swisseph_split_deg",
  "_swisseph_houses_ex2","_swisseph_houses_armc_ex2",
  "_swisseph_house_pos","_swisseph_house_name",
  "_swisseph_gauquelin_sector",
  "_swisseph_get_ayanamsa_ex","_swisseph_get_ayanamsa_ex_ut",
  "_swisseph_get_ayanamsa","_swisseph_get_ayanamsa_ut",
  "_swisseph_get_ayanamsa_name",
  "_swisseph_sol_eclipse_where","_swisseph_sol_eclipse_how",
  "_swisseph_sol_eclipse_when_glob","_swisseph_sol_eclipse_when_loc",
  "_swisseph_lun_eclipse_how","_swisseph_lun_eclipse_when",
  "_swisseph_lun_eclipse_when_loc",
  "_swisseph_lun_occult_where","_swisseph_lun_occult_when_glob",
  "_swisseph_lun_occult_when_loc",
  "_swisseph_rise_trans","_swisseph_rise_trans_true_hor",
  "_swisseph_solcross","_swisseph_solcross_ut",
  "_swisseph_mooncross","_swisseph_mooncross_ut",
  "_swisseph_mooncross_node","_swisseph_mooncross_node_ut",
  "_swisseph_helio_cross","_swisseph_helio_cross_ut",
  "_swisseph_pheno","_swisseph_pheno_ut",
  "_swisseph_nod_aps","_swisseph_nod_aps_ut",
  "_swisseph_get_orbital_elements","_swisseph_orbit_max_min_true_distance",
  "_swisseph_azalt","_swisseph_azalt_rev",
  "_swisseph_cotrans","_swisseph_cotrans_sp",
  "_swisseph_refrac","_swisseph_refrac_extended",
  "_swisseph_fixstar2","_swisseph_fixstar2_ut","_swisseph_fixstar2_mag",
  "_swisseph_heliacal_ut","_swisseph_heliacal_pheno_ut",
  "_swisseph_vis_limit_mag","_swisseph_heliacal_angle",
  "_swisseph_topo_arcus_visionis",
  "_malloc","_free"
]'

echo "Linking with emcc..."
emcc "$LIB" -o "$SCRIPT_DIR/swisseph_ffi.js" \
  --js-library "$SCRIPT_DIR/lib-random-fill.js" \
  -s MODULARIZE=1 \
  -s EXPORT_NAME=SwissEphRs \
  -s ALLOW_MEMORY_GROWTH=1 \
  -s FORCE_FILESYSTEM=1 \
  -s EXPORTED_FUNCTIONS="$EXPORTS" \
  -s "EXPORTED_RUNTIME_METHODS=['FS','HEAPU8','HEAPF64']" \
  -O2

# Post-process: make UTF8ArrayToString survive a resizable heap.
#
# ALLOW_MEMORY_GROWTH makes the WebAssembly.Memory growable, and Chrome now
# exposes a growable memory's .buffer as a *resizable* ArrayBuffer. TextDecoder
# refuses to decode a view backed by one ("The provided ArrayBuffer value must
# not be resizable"), so every UTF8ToString of more than 16 bytes throws. The
# 16-byte threshold is why this stayed hidden: short strings take the manual
# char-by-char path, and only the Swiss-file code path returns strings long
# enough to reach the decoder (swisseph-rs-dart/57).
#
# .slice() copies into a fresh, non-resizable buffer; .subarray() aliases the
# resizable one. Newer Emscripten does this upstream — drop this step once the
# toolchain here is new enough that the pattern below no longer matches.
echo "Patching glue for resizable-heap TextDecoder..."
GLUE="$SCRIPT_DIR/swisseph_ffi.js"
OLD='UTF8Decoder.decode(heapOrArray.subarray(idx,endPtr))'
NEW='UTF8Decoder.decode(heapOrArray.buffer.resizable?heapOrArray.slice(idx,endPtr):heapOrArray.subarray(idx,endPtr))'
if grep -qF "$NEW" "$GLUE"; then
  echo "  already patched (emcc emitted the resizable-safe form)"
elif grep -qF "$OLD" "$GLUE"; then
  python3 - "$GLUE" "$OLD" "$NEW" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path).read()
if src.count(old) != 1:
    sys.exit(f'ERROR: expected exactly 1 occurrence of the decode call, found {src.count(old)}')
open(path, 'w').write(src.replace(old, new))
PY
  echo "  patched"
else
  echo "ERROR: neither the patched nor the unpatched decode call was found in" >&2
  echo "       $GLUE — the Emscripten glue changed shape. Re-derive this" >&2
  echo "       patch before shipping; do not skip it silently." >&2
  exit 1
fi

echo "Built: $SCRIPT_DIR/swisseph_ffi.js + swisseph_ffi.wasm"
ls -lh "$SCRIPT_DIR/swisseph_ffi.js" "$SCRIPT_DIR/swisseph_ffi.wasm"
