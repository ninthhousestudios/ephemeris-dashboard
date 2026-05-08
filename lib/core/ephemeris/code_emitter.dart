import 'trace_model.dart';
import 'swe_symbol_catalog.dart';

abstract class CodeEmitter {
  String get languageId;
  String get displayName;
  String get fileExtension;

  String emitSnippet(CallEntry entry);
  String emitSection(List<CallEntry> entries,
      {Map<String, Object?> metadata = const {}});
  String emitProgram(List<CallEntry> entries,
      {Map<String, Object?> metadata = const {}});
}

class CEmitter implements CodeEmitter {
  const CEmitter();

  @override
  String get languageId => 'c';

  @override
  String get displayName => 'C';

  @override
  String get fileExtension => '.c';

  @override
  String emitSnippet(CallEntry entry) {
    switch (entry.functionName) {
      case 'swe_calc_ut':
        return _emitCalcUt(entry);
      case 'swe_set_sid_mode':
        return _emitSetSidMode(entry);
      case 'swe_set_topo':
        return _emitSetTopo(entry);
      case 'swe_set_ephe_path':
        return _emitSetEphePath(entry);
      case 'swe_set_jpl_file':
        return _emitSetJplFile(entry);
      case 'swe_houses':
        return _emitHouses(entry);
      case 'swe_fixstar2_ut':
        return _emitFixstar2Ut(entry);
      case 'swe_nod_aps_ut':
        return _emitNodApsUt(entry);
      case 'swe_pheno_ut':
        return _emitPhenoUt(entry);
      case 'swe_calc_pctr':
        return _emitCalcPctr(entry);
      case 'swe_get_ayanamsa_ex_ut':
        return _emitGetAyanamsaExUt(entry);
      case 'swe_gauquelin_sector':
        return _emitGauquelinSector(entry);
      case 'swe_solcross_ut':
        return _emitSolcrossUt(entry);
      case 'swe_mooncross_ut':
        return _emitMooncrossUt(entry);
      case 'swe_mooncross_node_ut':
        return _emitMooncrossNodeUt(entry);
      case 'swe_heliocross_ut':
        return _emitHeliocrossUt(entry);
      case 'swe_rise_trans_true_hor':
        return _emitRiseTransTrueHor(entry);
      case 'swe_heliacal_ut':
        return _emitHeliacalUt(entry);
      case 'swe_sol_eclipse_when_loc':
        return _emitSolEclipseWhenLoc(entry);
      case 'swe_sol_eclipse_how':
        return _emitSolEclipseHow(entry);
      case 'swe_lun_eclipse_when':
        return _emitLunEclipseWhen(entry);
      case 'swe_lun_eclipse_how':
        return _emitLunEclipseHow(entry);
      case 'swe_rise_trans':
        return _emitRiseTrans(entry);
      case 'swe_sol_eclipse_when_glob':
        return _emitSolEclipseWhenGlob(entry);
      case 'swe_sol_eclipse_where':
        return _emitSolEclipseWhere(entry);
      case 'swe_lun_eclipse_when_loc':
        return _emitLunEclipseWhenLoc(entry);
      case 'swe_deltat':
        return _emitDeltat(entry);
      case 'swe_time_equ':
        return _emitTimeEqu(entry);
      case 'swe_lmt_to_lat':
        return _emitLmtToLat(entry);
      case 'swe_lat_to_lmt':
        return _emitLatToLmt(entry);
      case 'swe_azalt':
        return _emitAzalt(entry);
      case 'swe_azalt_rev':
        return _emitAzaltRev(entry);
      case 'swe_cotrans':
        return _emitCotrans(entry);
      case 'swe_refrac':
        return _emitRefrac(entry);
      case 'swe_get_ayanamsa_ut':
        return _emitGetAyanamsaUt(entry);
      case 'swe_get_orbital_elements':
        return _emitGetOrbitalElements(entry);
      case 'swe_orbit_max_min_true_distance':
        return _emitOrbitMaxMinTrueDistance(entry);
      default:
        return '// ${entry.functionName}(...)';
    }
  }

  @override
  String emitSection(List<CallEntry> entries,
      {Map<String, Object?> metadata = const {}}) {
    final buf = StringBuffer();
    if (metadata.isNotEmpty) {
      buf.writeln('/*');
      for (final e in metadata.entries) {
        buf.writeln(' * ${e.key}: ${e.value}');
      }
      buf.writeln(' */');
    }
    for (final entry in entries) {
      buf.writeln(emitSnippet(entry));
    }
    return buf.toString();
  }

  @override
  String emitProgram(List<CallEntry> entries,
      {Map<String, Object?> metadata = const {}}) {
    final buf = StringBuffer();
    buf.writeln('#include "swephexp.h"');
    buf.writeln('#include <stdio.h>');
    buf.writeln();
    buf.writeln('int main(void) {');
    if (metadata.isNotEmpty) {
      buf.writeln('    /*');
      for (final e in metadata.entries) {
        buf.writeln('     * ${e.key}: ${e.value}');
      }
      buf.writeln('     */');
    }
    for (final entry in entries) {
      final snippet = emitSnippet(entry);
      buf.writeln('    {');
      for (final line in snippet.split('\n')) {
        if (line.isNotEmpty) buf.writeln('        $line');
      }
      buf.writeln('    }');
    }
    buf.writeln();
    buf.writeln('    swe_close();');
    buf.writeln('    return 0;');
    buf.writeln('}');
    return buf.toString();
  }

  String _emitCalcUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final flagStr = _formatFlags(iflag);

    final buf = StringBuffer();
    buf.writeln('double xx[6];');
    buf.writeln('char serr[256];');
    buf.write('int ret = swe_calc_ut($jdUt, $bodyStr, $flagStr, xx, serr);');

    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      final r = entry.result!;
      buf.writeln();
      buf.write('// returns: xx = {');
      try {
        final lon = (r as dynamic).longitude;
        final lat = (r as dynamic).latitude;
        final dist = (r as dynamic).distance;
        final slon = (r as dynamic).longitudeSpeed;
        final slat = (r as dynamic).latitudeSpeed;
        final sdist = (r as dynamic).distanceSpeed;
        buf.write('$lon, $lat, $dist, $slon, $slat, $sdist');
      } catch (_) {
        buf.write('...');
      }
      buf.write('}');
      if (entry.returnFlag != null) {
        buf.write(', ret = ${_formatFlags(entry.returnFlag!)}');
      }
    }

    return buf.toString();
  }

  String _emitSetSidMode(CallEntry entry) {
    final sidMode = entry.args['sidMode'] as int;
    final t0 = entry.args['t0'] ?? 0;
    final ayanT0 = entry.args['ayanT0'] ?? 0;

    final modeStr = SweSymbolCatalog.sidModeName(sidMode);
    if (t0 == 0 && ayanT0 == 0) {
      return 'swe_set_sid_mode($modeStr, 0, 0);';
    }
    return 'swe_set_sid_mode($modeStr, $t0, $ayanT0);';
  }

  String _emitSetTopo(CallEntry entry) {
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    return 'swe_set_topo($geolon, $geolat, $geoalt);';
  }

  String _emitSetEphePath(CallEntry entry) {
    final path = entry.args['path'];
    return 'swe_set_ephe_path("$path");';
  }

  String _emitSetJplFile(CallEntry entry) {
    final filename = entry.args['filename'];
    return 'swe_set_jpl_file("$filename");';
  }

  String _emitHouses(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final geolat = entry.args['geolat'];
    final geolon = entry.args['geolon'];
    final hsys = entry.args['hsys'] as int;

    final hsysChar = String.fromCharCode(hsys);
    final buf = StringBuffer();
    buf.writeln('double cusps[13];');
    buf.writeln('double ascmc[10];');
    buf.write(
        "int ret = swe_houses($jdUt, $geolat, $geolon, '$hsysChar', cusps, ascmc);");
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitFixstar2Ut(CallEntry entry) {
    final star = entry.args['star'];
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double xx[6];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_fixstar2_ut("$star", $jdUt, $flagStr, xx, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitNodApsUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;
    final method = entry.args['method'] as int;

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double xnasc[6], xndsc[6], xperi[6], xaphe[6];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_nod_aps_ut($jdUt, $bodyStr, $flagStr, $method, xnasc, xndsc, xperi, xaphe, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitPhenoUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double attr[20];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_pheno_ut($jdUt, $bodyStr, $flagStr, attr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitCalcPctr(CallEntry entry) {
    final jdEt = entry.args['jdEt'];
    final body = entry.args['body'] as int;
    final centerBody = entry.args['centerBody'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final centerStr = SweSymbolCatalog.bodyName(centerBody);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double xxeret[6];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_calc_pctr($jdEt, $bodyStr, $centerStr, $flagStr, xxeret, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitGetAyanamsaExUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double daya;');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_get_ayanamsa_ex_ut($jdUt, $flagStr, &daya, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: daya = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitGauquelinSector(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;
    final method = entry.args['method'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double geopos[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double dgsect;');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_gauquelin_sector($jdUt, $bodyStr, NULL, $flagStr, $method, geopos, $atpress, $attemp, &dgsect, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: dgsect = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolcrossUt(CallEntry entry) {
    final longitude = entry.args['longitude'];
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('char serr[256];');
    buf.write(
        'double jd_cross = swe_solcross_ut($longitude, $jdUt, $flagStr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jd_cross = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitMooncrossUt(CallEntry entry) {
    final longitude = entry.args['longitude'];
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('char serr[256];');
    buf.write(
        'double jd_cross = swe_mooncross_ut($longitude, $jdUt, $flagStr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jd_cross = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitMooncrossNodeUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double xlon, xlat;');
    buf.writeln('char serr[256];');
    buf.write(
        'double jd_cross = swe_mooncross_node_ut($jdUt, $flagStr, &xlon, &xlat, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jd_cross = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitHeliocrossUt(CallEntry entry) {
    final body = entry.args['body'] as int;
    final longitude = entry.args['longitude'];
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;
    final dir = entry.args['dir'];

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double jd_cross;');
    buf.writeln('char serr[256];');
    buf.write(
        'double ret = swe_heliocross_ut($bodyStr, $longitude, $jdUt, $flagStr, $dir, &jd_cross, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jd_cross = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitRiseTransTrueHor(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final epheflag = entry.args['epheflag'] as int;
    final rsmi = entry.args['rsmi'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];
    final horizonHeight = entry.args['horizonHeight'];

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final flagStr = _formatFlags(epheflag);
    final buf = StringBuffer();
    buf.writeln('double geopos[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double tret;');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_rise_trans_true_hor($jdUt, $bodyStr, NULL, $flagStr, $rsmi, geopos, $atpress, $attemp, $horizonHeight, &tret, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: tret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitHeliacalUt(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final objectName = entry.args['objectName'];
    final typeEvent = entry.args['typeEvent'];
    final flags = entry.args['flags'] as int;

    final flagStr = _formatFlags(flags);
    final buf = StringBuffer();
    buf.writeln('double dgeo[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double datm[4] = {0};');
    buf.writeln('double dobs[6] = {0};');
    buf.writeln('double dret[50];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_heliacal_ut($jdStart, dgeo, datm, dobs, "$objectName", $typeEvent, $flagStr, dret, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolEclipseWhenLoc(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final iflag = entry.args['iflag'] as int;
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final backward = entry.args['backward'];

    final flagStr = _formatFlags(iflag);
    final backwardStr = (backward == true || backward == 1) ? 'TRUE' : 'FALSE';
    final buf = StringBuffer();
    buf.writeln('double geopos[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double tret[10];');
    buf.writeln('double attr[20];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_sol_eclipse_when_loc($jdStart, $flagStr, geopos, tret, attr, $backwardStr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolEclipseHow(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double geopos[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double attr[20];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_sol_eclipse_how($jdUt, $flagStr, geopos, attr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLunEclipseWhen(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final iflag = entry.args['iflag'] as int;
    final eclType = entry.args['eclType'];
    final backward = entry.args['backward'];

    final flagStr = _formatFlags(iflag);
    final backwardStr = (backward == true || backward == 1) ? 'TRUE' : 'FALSE';
    final buf = StringBuffer();
    buf.writeln('double tret[10];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_lun_eclipse_when($jdStart, $flagStr, $eclType, tret, $backwardStr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLunEclipseHow(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double geopos[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double attr[20];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_lun_eclipse_how($jdUt, $flagStr, geopos, attr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitRiseTrans(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final epheflag = entry.args['epheflag'] as int;
    final rsmi = entry.args['rsmi'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final flagStr = _formatFlags(epheflag);
    final buf = StringBuffer();
    buf.writeln('double geopos[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double tret;');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_rise_trans($jdUt, $bodyStr, NULL, $flagStr, $rsmi, geopos, $atpress, $attemp, &tret, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: tret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolEclipseWhenGlob(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final iflag = entry.args['iflag'] as int;
    final eclType = entry.args['eclType'];
    final backward = entry.args['backward'];

    final flagStr = _formatFlags(iflag);
    final backwardStr = (backward == true || backward == 1) ? 'TRUE' : 'FALSE';
    final buf = StringBuffer();
    buf.writeln('double tret[10];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_sol_eclipse_when_glob($jdStart, $flagStr, $eclType, tret, $backwardStr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolEclipseWhere(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double geopos[10];');
    buf.writeln('double attr[20];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_sol_eclipse_where($jdUt, $flagStr, geopos, attr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLunEclipseWhenLoc(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final iflag = entry.args['iflag'] as int;
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final backward = entry.args['backward'];

    final flagStr = _formatFlags(iflag);
    final backwardStr = (backward == true || backward == 1) ? 'TRUE' : 'FALSE';
    final buf = StringBuffer();
    buf.writeln('double geopos[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double tret[10];');
    buf.writeln('double attr[20];');
    buf.writeln('char serr[256];');
    buf.write(
        'int32 ret = swe_lun_eclipse_when_loc($jdStart, $flagStr, geopos, tret, attr, $backwardStr, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ret = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitDeltat(CallEntry entry) {
    final jd = entry.args['jd'];
    final buf = StringBuffer();
    buf.write('double dt = swe_deltat($jd);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: dt = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitTimeEqu(CallEntry entry) {
    final jd = entry.args['jd'];
    final buf = StringBuffer();
    buf.writeln('double e;');
    buf.writeln('char serr[256];');
    buf.write('int ret = swe_time_equ($jd, &e, serr);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: e = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLmtToLat(CallEntry entry) {
    final jdLmt = entry.args['jdLmt'];
    final geolon = entry.args['geolon'];
    final buf = StringBuffer();
    buf.writeln('double jd_lat;');
    buf.writeln('char serr[256];');
    buf.write('int ret = swe_lmt_to_lat($jdLmt, $geolon, &jd_lat, serr);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jd_lat = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLatToLmt(CallEntry entry) {
    final jdLat = entry.args['jdLat'];
    final geolon = entry.args['geolon'];
    final buf = StringBuffer();
    buf.writeln('double jd_lmt;');
    buf.writeln('char serr[256];');
    buf.write('int ret = swe_lat_to_lmt($jdLat, $geolon, &jd_lmt, serr);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jd_lmt = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitAzalt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final calcFlag = entry.args['calcFlag'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];
    final bodyLon = entry.args['bodyLon'];
    final bodyLat = entry.args['bodyLat'];
    final bodyDist = entry.args['bodyDist'];

    final buf = StringBuffer();
    buf.writeln('double geopos[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double xin[3] = {$bodyLon, $bodyLat, $bodyDist};');
    buf.writeln('double xaz[3];');
    buf.write(
        'swe_azalt($jdUt, $calcFlag, geopos, $atpress, $attemp, xin, xaz);');
    if (entry.result != null) {
      buf.writeln();
      try {
        final r = entry.result as dynamic;
        buf.write('// returns: xaz = {${r.azimuth}, ${r.trueAltitude}, ${r.apparentAltitude}}');
      } catch (_) {
        buf.write('// returns: ${entry.result}');
      }
    }
    return buf.toString();
  }

  String _emitAzaltRev(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final calcFlag = entry.args['calcFlag'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final azimuth = entry.args['azimuth'];
    final altitude = entry.args['altitude'];

    final buf = StringBuffer();
    buf.writeln('double geopos[3] = {$geolon, $geolat, $geoalt};');
    buf.writeln('double xin[2] = {$azimuth, $altitude};');
    buf.writeln('double xout[2];');
    buf.write(
        'swe_azalt_rev($jdUt, $calcFlag, geopos, xin, xout);');
    if (entry.result != null) {
      buf.writeln();
      try {
        final r = entry.result as dynamic;
        buf.write('// returns: xout = {${r.lon}, ${r.lat}}');
      } catch (_) {
        buf.write('// returns: ${entry.result}');
      }
    }
    return buf.toString();
  }

  String _emitCotrans(CallEntry entry) {
    final lon = entry.args['lon'];
    final lat = entry.args['lat'];
    final dist = entry.args['dist'];
    final eps = entry.args['eps'];

    final buf = StringBuffer();
    buf.writeln('double xin[3] = {$lon, $lat, $dist};');
    buf.writeln('double xout[3];');
    buf.write('swe_cotrans(xin, xout, $eps);');
    if (entry.result != null) {
      buf.writeln();
      try {
        final r = entry.result as dynamic;
        buf.write('// returns: xout = {${r.lon}, ${r.lat}, ${r.dist}}');
      } catch (_) {
        buf.write('// returns: ${entry.result}');
      }
    }
    return buf.toString();
  }

  String _emitRefrac(CallEntry entry) {
    final altitude = entry.args['altitude'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];
    final calcFlag = entry.args['calcFlag'];

    final buf = StringBuffer();
    buf.write('double alt_out = swe_refrac($altitude, $atpress, $attemp, $calcFlag);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: alt_out = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitGetAyanamsaUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final buf = StringBuffer();
    buf.write('double ayanamsa = swe_get_ayanamsa_ut($jdUt);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ayanamsa = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitGetOrbitalElements(CallEntry entry) {
    final jdEt = entry.args['jdEt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double elem[50];');
    buf.writeln('char serr[256];');
    buf.write('int32 ret = swe_get_orbital_elements($jdEt, $bodyStr, $flagStr, elem, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    }
    return buf.toString();
  }

  String _emitOrbitMaxMinTrueDistance(CallEntry entry) {
    final jdEt = entry.args['jdEt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyName(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.writeln('double dmax, dmin, dtrue;');
    buf.writeln('char serr[256];');
    buf.write('int32 ret = swe_orbit_max_min_true_distance($jdEt, $bodyStr, $flagStr, &dmax, &dmin, &dtrue, serr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _formatFlags(int flags) {
    final parts = SweSymbolCatalog.flagDecompose(flags);
    if (parts.isEmpty) return '0';
    return parts.join(' | ');
  }
}

class DartEmitter implements CodeEmitter {
  const DartEmitter();

  @override
  String get languageId => 'dart';

  @override
  String get displayName => 'Dart';

  @override
  String get fileExtension => '.dart';

  @override
  String emitSnippet(CallEntry entry) {
    switch (entry.functionName) {
      case 'swe_calc_ut':
        return _emitCalcUt(entry);
      case 'swe_set_sid_mode':
        return _emitSetSidMode(entry);
      case 'swe_set_topo':
        return _emitSetTopo(entry);
      case 'swe_set_ephe_path':
        return _emitSetEphePath(entry);
      case 'swe_set_jpl_file':
        return _emitSetJplFile(entry);
      case 'swe_houses':
        return _emitHouses(entry);
      case 'swe_fixstar2_ut':
        return _emitFixstar2Ut(entry);
      case 'swe_nod_aps_ut':
        return _emitNodApsUt(entry);
      case 'swe_pheno_ut':
        return _emitPhenoUt(entry);
      case 'swe_calc_pctr':
        return _emitCalcPctr(entry);
      case 'swe_get_ayanamsa_ex_ut':
        return _emitGetAyanamsaExUt(entry);
      case 'swe_gauquelin_sector':
        return _emitGauquelinSector(entry);
      case 'swe_solcross_ut':
        return _emitSolcrossUt(entry);
      case 'swe_mooncross_ut':
        return _emitMooncrossUt(entry);
      case 'swe_mooncross_node_ut':
        return _emitMooncrossNodeUt(entry);
      case 'swe_heliocross_ut':
        return _emitHeliocrossUt(entry);
      case 'swe_rise_trans_true_hor':
        return _emitRiseTransTrueHor(entry);
      case 'swe_rise_trans':
        return _emitRiseTrans(entry);
      case 'swe_heliacal_ut':
        return _emitHeliacalUt(entry);
      case 'swe_sol_eclipse_when_loc':
        return _emitSolEclipseWhenLoc(entry);
      case 'swe_sol_eclipse_how':
        return _emitSolEclipseHow(entry);
      case 'swe_lun_eclipse_when':
        return _emitLunEclipseWhen(entry);
      case 'swe_lun_eclipse_how':
        return _emitLunEclipseHow(entry);
      case 'swe_sol_eclipse_when_glob':
        return _emitSolEclipseWhenGlob(entry);
      case 'swe_sol_eclipse_where':
        return _emitSolEclipseWhere(entry);
      case 'swe_lun_eclipse_when_loc':
        return _emitLunEclipseWhenLoc(entry);
      case 'swe_deltat':
        return _emitDeltat(entry);
      case 'swe_time_equ':
        return _emitTimeEqu(entry);
      case 'swe_lmt_to_lat':
        return _emitLmtToLat(entry);
      case 'swe_lat_to_lmt':
        return _emitLatToLmt(entry);
      case 'swe_azalt':
        return _emitAzalt(entry);
      case 'swe_azalt_rev':
        return _emitAzaltRev(entry);
      case 'swe_cotrans':
        return _emitCotrans(entry);
      case 'swe_refrac':
        return _emitRefrac(entry);
      case 'swe_get_ayanamsa_ut':
        return _emitGetAyanamsaUt(entry);
      case 'swe_get_orbital_elements':
        return _emitGetOrbitalElements(entry);
      case 'swe_orbit_max_min_true_distance':
        return _emitOrbitMaxMinTrueDistance(entry);
      default:
        return '// ${entry.functionName}(...)';
    }
  }

  @override
  String emitSection(List<CallEntry> entries,
      {Map<String, Object?> metadata = const {}}) {
    final buf = StringBuffer();
    if (metadata.isNotEmpty) {
      buf.writeln('//');
      for (final e in metadata.entries) {
        buf.writeln('// ${e.key}: ${e.value}');
      }
      buf.writeln('//');
    }
    for (final entry in entries) {
      buf.writeln(emitSnippet(entry));
    }
    return buf.toString();
  }

  @override
  String emitProgram(List<CallEntry> entries,
      {Map<String, Object?> metadata = const {}}) {
    final buf = StringBuffer();
    buf.writeln("import 'package:swisseph/swisseph.dart';");
    buf.writeln();
    buf.writeln('void main() {');
    buf.writeln('  final swe = SwissEph();');
    if (metadata.isNotEmpty) {
      for (final e in metadata.entries) {
        buf.writeln('  // ${e.key}: ${e.value}');
      }
    }
    for (final entry in entries) {
      final snippet = emitSnippet(entry);
      buf.writeln('  {');
      for (final line in snippet.split('\n')) {
        if (line.isNotEmpty) buf.writeln('    $line');
      }
      buf.writeln('  }');
    }
    buf.writeln();
    buf.writeln('  swe.close();');
    buf.writeln('}');
    return buf.toString();
  }

  String _emitCalcUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final flagStr = _formatFlags(iflag);

    final buf = StringBuffer();
    buf.write('final result = swe.calcUt($jdUt, $bodyStr, $flagStr);');

    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ');
      try {
        final r = entry.result! as dynamic;
        buf.write(
            'lon=${r.longitude}, lat=${r.latitude}, dist=${r.distance}, '
            'slon=${r.longitudeSpeed}, slat=${r.latitudeSpeed}, sdist=${r.distanceSpeed}');
      } catch (_) {
        buf.write('...');
      }
      if (entry.returnFlag != null) {
        buf.write(', retflag=${_formatFlags(entry.returnFlag!)}');
      }
    }

    return buf.toString();
  }

  String _emitSetSidMode(CallEntry entry) {
    final sidMode = entry.args['sidMode'] as int;
    final t0 = entry.args['t0'] ?? 0;
    final ayanT0 = entry.args['ayanT0'] ?? 0;

    final modeStr = SweSymbolCatalog.sidModeNameDart(sidMode);
    if (t0 == 0 && ayanT0 == 0) {
      return 'swe.setSidMode($modeStr);';
    }
    return 'swe.setSidMode($modeStr, t0: $t0, ayanT0: $ayanT0);';
  }

  String _emitSetTopo(CallEntry entry) {
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    return 'swe.setTopo($geolon, $geolat, $geoalt);';
  }

  String _emitSetEphePath(CallEntry entry) {
    final path = entry.args['path'];
    return "swe.setEphePath('$path');";
  }

  String _emitSetJplFile(CallEntry entry) {
    final filename = entry.args['filename'];
    return "swe.setJplFile('$filename');";
  }

  String _emitHouses(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final geolat = entry.args['geolat'];
    final geolon = entry.args['geolon'];
    final hsys = entry.args['hsys'] as int;

    final hsysChar = String.fromCharCode(hsys);
    final buf = StringBuffer();
    buf.write(
        "final result = swe.houses($jdUt, $geolat, $geolon, '$hsysChar'.codeUnitAt(0));");
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitFixstar2Ut(CallEntry entry) {
    final star = entry.args['star'];
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write("final result = swe.fixstar2Ut('$star', $jdUt, $flagStr);");
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitNodApsUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;
    final method = entry.args['method'];

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write(
        'final result = swe.nodApsUt($jdUt, $bodyStr, $flagStr, $method);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitPhenoUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write('final result = swe.phenoUt($jdUt, $bodyStr, $flagStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitCalcPctr(CallEntry entry) {
    final jdEt = entry.args['jdEt'];
    final body = entry.args['body'] as int;
    final centerBody = entry.args['centerBody'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final centerStr = SweSymbolCatalog.bodyNameDart(centerBody);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write(
        'final result = swe.calcPctr($jdEt, $bodyStr, $centerStr, $flagStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitGetAyanamsaExUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write('final result = swe.getAyanamsaExUt($jdUt, $flagStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitGauquelinSector(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;
    final method = entry.args['method'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write(
        'final sector = swe.gauquelinSector($jdUt, $bodyStr, $flagStr, $method, '
        'geolon: $geolon, geolat: $geolat, geoalt: $geoalt, '
        'atpress: $atpress, attemp: $attemp);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: sector = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolcrossUt(CallEntry entry) {
    final longitude = entry.args['longitude'];
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write('final jdCross = swe.solCrossUt($longitude, $jdUt, $flagStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jdCross = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitMooncrossUt(CallEntry entry) {
    final longitude = entry.args['longitude'];
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write(
        'final jdCross = swe.moonCrossUt($longitude, $jdUt, $flagStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jdCross = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitMooncrossNodeUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write('final result = swe.moonCrossNodeUt($jdUt, $flagStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitHeliocrossUt(CallEntry entry) {
    final body = entry.args['body'] as int;
    final longitude = entry.args['longitude'];
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;
    final dir = entry.args['dir'];

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write(
        'final jdCross = swe.helioCrossUt($bodyStr, $longitude, $jdUt, $flagStr, $dir);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jdCross = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitRiseTransTrueHor(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final epheflag = entry.args['epheflag'] as int;
    final rsmi = entry.args['rsmi'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];
    final horizonHeight = entry.args['horizonHeight'];

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final flagStr = _formatFlags(epheflag);
    final buf = StringBuffer();
    buf.write(
        'final result = swe.riseTransTrueHor($jdUt, $bodyStr, '
        'epheflag: $flagStr, rsmi: $rsmi, '
        'geolon: $geolon, geolat: $geolat, geoalt: $geoalt, '
        'atpress: $atpress, attemp: $attemp, horizonHeight: $horizonHeight);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitRiseTrans(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final body = entry.args['body'] as int;
    final epheflag = entry.args['epheflag'] as int;
    final rsmi = entry.args['rsmi'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final flagStr = _formatFlags(epheflag);
    final buf = StringBuffer();
    buf.write(
        'final result = swe.riseTrans($jdUt, $bodyStr, '
        'epheflag: $flagStr, rsmi: $rsmi, '
        'geolon: $geolon, geolat: $geolat, geoalt: $geoalt, '
        'atpress: $atpress, attemp: $attemp);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitHeliacalUt(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final objectName = entry.args['objectName'];
    final typeEvent = entry.args['typeEvent'];
    final flags = entry.args['flags'] as int;

    final flagStr = _formatFlags(flags);
    final buf = StringBuffer();
    buf.write(
        "final result = swe.heliacalUt($jdStart, "
        "geolon: $geolon, geolat: $geolat, geoalt: $geoalt, "
        "objectName: '$objectName', typeEvent: $typeEvent, flags: $flagStr);");
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolEclipseWhenLoc(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final iflag = entry.args['iflag'] as int;
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final backward = entry.args['backward'];

    final flagStr = _formatFlags(iflag);
    final backwardStr = (backward == true || backward == 1) ? 'true' : 'false';
    final buf = StringBuffer();
    buf.write(
        'final result = swe.solEclipseWhenLoc($jdStart, $flagStr, '
        'geolon: $geolon, geolat: $geolat, geoalt: $geoalt, '
        'backward: $backwardStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolEclipseHow(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write(
        'final result = swe.solEclipseHow($jdUt, $flagStr, '
        'geolon: $geolon, geolat: $geolat, geoalt: $geoalt);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLunEclipseWhen(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final iflag = entry.args['iflag'] as int;
    final eclType = entry.args['eclType'];
    final backward = entry.args['backward'];

    final flagStr = _formatFlags(iflag);
    final backwardStr = (backward == true || backward == 1) ? 'true' : 'false';
    final buf = StringBuffer();
    buf.write(
        'final result = swe.lunEclipseWhen($jdStart, $flagStr, '
        'eclType: $eclType, backward: $backwardStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLunEclipseHow(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write(
        'final result = swe.lunEclipseHow($jdUt, $flagStr, '
        'geolon: $geolon, geolat: $geolat, geoalt: $geoalt);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolEclipseWhenGlob(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final iflag = entry.args['iflag'] as int;
    final eclType = entry.args['eclType'];
    final backward = entry.args['backward'];

    final flagStr = _formatFlags(iflag);
    final backwardStr = (backward == true || backward == 1) ? 'true' : 'false';
    final buf = StringBuffer();
    buf.write(
        'final result = swe.solEclipseWhenGlob($jdStart, $flagStr, '
        'eclType: $eclType, backward: $backwardStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitSolEclipseWhere(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final iflag = entry.args['iflag'] as int;

    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write('final result = swe.solEclipseWhere($jdUt, $flagStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLunEclipseWhenLoc(CallEntry entry) {
    final jdStart = entry.args['jdStart'];
    final iflag = entry.args['iflag'] as int;
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final backward = entry.args['backward'];

    final flagStr = _formatFlags(iflag);
    final backwardStr = (backward == true || backward == 1) ? 'true' : 'false';
    final buf = StringBuffer();
    buf.write(
        'final result = swe.lunEclipseWhenLoc($jdStart, $flagStr, '
        'geolon: $geolon, geolat: $geolat, geoalt: $geoalt, '
        'backward: $backwardStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitDeltat(CallEntry entry) {
    final jd = entry.args['jd'];
    final buf = StringBuffer();
    buf.write('final dt = swe.deltat($jd);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: dt = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitTimeEqu(CallEntry entry) {
    final jd = entry.args['jd'];
    final buf = StringBuffer();
    buf.write('final e = swe.timeEqu($jd);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: e = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLmtToLat(CallEntry entry) {
    final jdLmt = entry.args['jdLmt'];
    final geolon = entry.args['geolon'];
    final buf = StringBuffer();
    buf.write('final jdLat = swe.lmtToLat($jdLmt, $geolon);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jdLat = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitLatToLmt(CallEntry entry) {
    final jdLat = entry.args['jdLat'];
    final geolon = entry.args['geolon'];
    final buf = StringBuffer();
    buf.write('final jdLmt = swe.latToLmt($jdLat, $geolon);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: jdLmt = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitAzalt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final calcFlag = entry.args['calcFlag'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];
    final bodyLon = entry.args['bodyLon'];
    final bodyLat = entry.args['bodyLat'];
    final bodyDist = entry.args['bodyDist'];

    final buf = StringBuffer();
    buf.write(
        'final result = swe.azAlt($jdUt, $calcFlag, '
        'geolon: $geolon, geolat: $geolat, geoalt: $geoalt, '
        'atpress: $atpress, attemp: $attemp, '
        'bodyLon: $bodyLon, bodyLat: $bodyLat, bodyDist: $bodyDist);');
    if (entry.result != null) {
      buf.writeln();
      try {
        final r = entry.result as dynamic;
        buf.write(
            '// returns: azimuth=${r.azimuth}, trueAlt=${r.trueAltitude}, apparentAlt=${r.apparentAltitude}');
      } catch (_) {
        buf.write('// returns: ${entry.result}');
      }
    }
    return buf.toString();
  }

  String _emitAzaltRev(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final calcFlag = entry.args['calcFlag'];
    final geolon = entry.args['geolon'];
    final geolat = entry.args['geolat'];
    final geoalt = entry.args['geoalt'];
    final azimuth = entry.args['azimuth'];
    final altitude = entry.args['altitude'];

    final buf = StringBuffer();
    buf.write(
        'final result = swe.azAltRev($jdUt, $calcFlag, '
        'geolon: $geolon, geolat: $geolat, geoalt: $geoalt, '
        'azimuth: $azimuth, altitude: $altitude);');
    if (entry.result != null) {
      buf.writeln();
      try {
        final r = entry.result as dynamic;
        buf.write('// returns: lon=${r.lon}, lat=${r.lat}');
      } catch (_) {
        buf.write('// returns: ${entry.result}');
      }
    }
    return buf.toString();
  }

  String _emitCotrans(CallEntry entry) {
    final lon = entry.args['lon'];
    final lat = entry.args['lat'];
    final dist = entry.args['dist'];
    final eps = entry.args['eps'];

    final buf = StringBuffer();
    buf.write('final result = swe.cotrans($lon, $lat, $dist, $eps);');
    if (entry.result != null) {
      buf.writeln();
      try {
        final r = entry.result as dynamic;
        buf.write(
            '// returns: lon=${r.lon}, lat=${r.lat}, dist=${r.dist}');
      } catch (_) {
        buf.write('// returns: ${entry.result}');
      }
    }
    return buf.toString();
  }

  String _emitRefrac(CallEntry entry) {
    final altitude = entry.args['altitude'];
    final atpress = entry.args['atpress'];
    final attemp = entry.args['attemp'];
    final calcFlag = entry.args['calcFlag'];

    final buf = StringBuffer();
    buf.write(
        'final altOut = swe.refrac($altitude, $atpress, $attemp, $calcFlag);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: altOut = ${entry.result}');
    }
    return buf.toString();
  }

  String _emitGetAyanamsaUt(CallEntry entry) {
    final jdUt = entry.args['jdUt'];
    final buf = StringBuffer();
    buf.write('final result = swe.getAyanamsaUt($jdUt);');
    if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _emitGetOrbitalElements(CallEntry entry) {
    final jdEt = entry.args['jdEt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write('final result = swe.getOrbitalElements($jdEt, $bodyStr, $flagStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    }
    return buf.toString();
  }

  String _emitOrbitMaxMinTrueDistance(CallEntry entry) {
    final jdEt = entry.args['jdEt'];
    final body = entry.args['body'] as int;
    final iflag = entry.args['iflag'] as int;

    final bodyStr = SweSymbolCatalog.bodyNameDart(body);
    final flagStr = _formatFlags(iflag);
    final buf = StringBuffer();
    buf.write(
        'final result = swe.orbitMaxMinTrueDistance($jdEt, $bodyStr, $flagStr);');
    if (entry.errorMessage != null) {
      buf.writeln();
      buf.write('// Error: ${entry.errorMessage}');
    } else if (entry.result != null) {
      buf.writeln();
      buf.write('// returns: ${entry.result}');
    }
    return buf.toString();
  }

  String _formatFlags(int flags) {
    final parts = SweSymbolCatalog.flagDecomposeDart(flags);
    if (parts.isEmpty) return '0';
    return parts.join(' | ');
  }
}
