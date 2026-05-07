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
    buf.writeln('    double xx[6];');
    buf.writeln('    char serr[256];');
    buf.writeln();
    buf.write(emitSection(entries, metadata: metadata));
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

  String _formatFlags(int flags) {
    final parts = SweSymbolCatalog.flagDecompose(flags);
    if (parts.isEmpty) return '0';
    return parts.join(' | ');
  }
}
