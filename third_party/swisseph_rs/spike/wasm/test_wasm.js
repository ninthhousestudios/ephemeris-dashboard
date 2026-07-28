// wasm spike: validate swisseph-ffi over Emscripten MEMFS
// Tests: (1) Moshier path (no files), (2) Swiss file path with .se1 staged in MEMFS

const path = require('path');
const fs = require('fs');

async function main() {
  const Module = require('./swisseph_ffi.js');
  const m = await Module();

  // --- helpers ---
  function allocStr(s) {
    const enc = new TextEncoder().encode(s + '\0');
    const ptr = m._malloc(enc.length);
    m.HEAPU8.set(enc, ptr);
    return ptr;
  }

  function readStr(ptr) {
    if (!ptr) return '';
    let end = ptr;
    while (m.HEAPU8[end] !== 0) end++;
    return new TextDecoder().decode(m.HEAPU8.subarray(ptr, end));
  }

  // --- version ---
  const verPtr = m._swisseph_version();
  console.log('swisseph_version:', readStr(verPtr));

  // --- SweConfig layout (from api-surface.md) ---
  // We need to match the C struct layout. Let's use swisseph_config_default.
  const CONFIG_SIZE = 256; // generous upper bound
  const cfgPtr = m._malloc(CONFIG_SIZE);
  m._swisseph_config_default(cfgPtr);

  // --- Test 1: Moshier path (ephemeris_source=0, no files) ---
  console.log('\n=== Test 1: Moshier path (no files) ===');
  {
    // config is already default (Moshier, source=0)
    const outPtr = m._malloc(4); // pointer to SweEphemeris*
    const errBuf = m._malloc(256);
    m.HEAPU8.fill(0, errBuf, errBuf + 256);

    const rc = m._swisseph_new(cfgPtr, outPtr, errBuf, 256);
    const errMsg = readStr(errBuf);
    console.log('  swisseph_new rc:', rc, errMsg ? `err: ${errMsg}` : '(ok)');

    if (rc === 0) {
      const handle = m.HEAPU32[outPtr >> 2];
      console.log('  handle:', handle);

      // calc_ut: Sun at J2000 (JD 2451545.0)
      const xxPtr = m._malloc(6 * 8); // 6 doubles
      const flagsUsedPtr = m._malloc(4);
      const errBuf2 = m._malloc(256);
      m.HEAPU8.fill(0, errBuf2, errBuf2 + 256);

      // swisseph_calc_ut(handle, tjd_ut, ipl, iflag, geopos, sid_mode, xx, flags_used, err_buf, err_cap)
      const tjd_ut = 2451545.0; // J2000
      const ipl = 0; // Sun
      const iflag = 2 | 256; // SEFLG_SPEED | SEFLG_MOSEPH (speed + Moshier)

      const rc2 = m._swisseph_calc_ut(handle, tjd_ut, ipl, iflag, 0, 0, xxPtr, flagsUsedPtr, errBuf2, 256);
      const errMsg2 = readStr(errBuf2);
      console.log('  swisseph_calc_ut rc:', rc2, errMsg2 ? `err: ${errMsg2}` : '(ok)');

      if (rc2 >= 0) {
        const xx = new Float64Array(m.HEAPF64.buffer, xxPtr, 6);
        console.log('  Sun @ J2000:');
        console.log('    lon:', xx[0].toFixed(9));
        console.log('    lat:', xx[1].toFixed(9));
        console.log('    dist:', xx[2].toFixed(9));
        console.log('    lon_speed:', xx[3].toFixed(9));
        console.log('    lat_speed:', xx[4].toFixed(9));
        console.log('    dist_speed:', xx[5].toFixed(9));
      }

      m._swisseph_free(handle);
      m._free(xxPtr);
      m._free(flagsUsedPtr);
      m._free(errBuf2);
    }

    m._free(outPtr);
    m._free(errBuf);
  }

  // --- Test 2: Swiss file path (ephemeris_source=1, .se1 in MEMFS) ---
  console.log('\n=== Test 2: Swiss file path (.se1 in MEMFS) ===');
  {
    const epheDir = path.resolve(__dirname, '../../../swisseph-rs/ephe');
    // J2000 (year 2000) is covered by sepl_18.se1 (planets) and semo_18.se1 (moon)
    const filesToStage = ['sepl_18.se1', 'semo_18.se1'];

    try { m.FS.mkdir('/ephe'); } catch (e) { /* exists */ }

    for (const f of filesToStage) {
      const hostPath = path.join(epheDir, f);
      if (!fs.existsSync(hostPath)) {
        console.log('  SKIP: missing', f);
        m._free(cfgPtr);
        return;
      }
      const data = fs.readFileSync(hostPath);
      m.FS.writeFile('/ephe/' + f, data);
      console.log('  Staged:', f, `(${data.length} bytes)`);
    }

    // Build config with Swiss source and ephe_path
    const cfgPtr2 = m._malloc(CONFIG_SIZE);
    m._swisseph_config_default(cfgPtr2);

    // Set ephemeris_source = 1 (Swiss)
    // SweConfig layout: ephemeris_source is the first i32 field
    m.HEAP32[cfgPtr2 >> 2] = 1; // Swiss

    // Set ephe_path (second field, pointer)
    const pathStr = allocStr('/ephe');
    // ephe_path is at offset 4 (after i32 ephemeris_source), but it's a pointer
    // On wasm32, pointers are 4 bytes. So offset 4.
    m.HEAP32[(cfgPtr2 + 4) >> 2] = pathStr;

    const outPtr2 = m._malloc(4);
    const errBuf3 = m._malloc(256);
    m.HEAPU8.fill(0, errBuf3, errBuf3 + 256);

    const rc3 = m._swisseph_new(cfgPtr2, outPtr2, errBuf3, 256);
    const errMsg3 = readStr(errBuf3);
    console.log('  swisseph_new rc:', rc3, errMsg3 ? `err: ${errMsg3}` : '(ok)');

    if (rc3 === 0) {
      const handle2 = m.HEAPU32[outPtr2 >> 2];

      const xxPtr2 = m._malloc(6 * 8);
      const flagsUsedPtr2 = m._malloc(4);
      const errBuf4 = m._malloc(256);
      m.HEAPU8.fill(0, errBuf4, errBuf4 + 256);

      const tjd_ut = 2451545.0; // J2000
      const ipl = 0; // Sun
      const iflag = 2 | 256; // SEFLG_SWIEPH | SEFLG_SPEED

      const rc4 = m._swisseph_calc_ut(handle2, tjd_ut, ipl, iflag, 0, 0, xxPtr2, flagsUsedPtr2, errBuf4, 256);
      const errMsg4 = readStr(errBuf4);
      console.log('  swisseph_calc_ut rc:', rc4, errMsg4 ? `err: ${errMsg4}` : '(ok)');

      if (rc4 >= 0) {
        const xx2 = new Float64Array(m.HEAPF64.buffer, xxPtr2, 6);
        console.log('  Sun @ J2000 (Swiss files):');
        console.log('    lon:', xx2[0].toFixed(9));
        console.log('    lat:', xx2[1].toFixed(9));
        console.log('    dist:', xx2[2].toFixed(9));
        console.log('    lon_speed:', xx2[3].toFixed(9));
        console.log('    lat_speed:', xx2[4].toFixed(9));
        console.log('    dist_speed:', xx2[5].toFixed(9));
      }

      m._swisseph_free(handle2);
      m._free(xxPtr2);
      m._free(flagsUsedPtr2);
      m._free(errBuf4);
    }

    m._free(outPtr2);
    m._free(errBuf3);
    m._free(cfgPtr2);
    m._free(pathStr);
  }

  m._free(cfgPtr);
  console.log('\n=== Done ===');
}

main().catch(e => { console.error(e); process.exit(1); });
