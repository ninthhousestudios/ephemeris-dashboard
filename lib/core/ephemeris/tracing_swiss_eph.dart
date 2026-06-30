import 'package:swisseph/swisseph.dart';

import 'ephemeris.dart';
import 'swe_symbol_catalog.dart';
import 'trace_model.dart';

class TracingSwissEph implements Ephemeris {
  TracingSwissEph(this._delegate);

  final SwissEph _delegate;
  final List<CallEntry> _entries = [];
  String _tabTag = '';

  List<CallEntry> get entries => _entries;

  void setTabTag(String tag) => _tabTag = tag;

  void clearEntries() => _entries.clear();

  // --------------- Context setters ---------------

  @override
  void setEphePath(String path) {
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSetEphePath,
        args: {'path': path},
        category: CallCategory.context,
        traceId: '$_tabTag:set_ephe_path',
      ),
    );
    _delegate.setEphePath(path);
  }

  @override
  void setSidMode(int sidMode, {double t0 = 0, double ayanT0 = 0}) {
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSetSidMode,
        args: {'sidMode': sidMode, 't0': t0, 'ayanT0': ayanT0},
        category: CallCategory.context,
        traceId: '$_tabTag:set_sid_mode',
      ),
    );
    _delegate.setSidMode(sidMode, t0: t0, ayanT0: ayanT0);
  }

  @override
  void setTopo(double geolon, double geolat, double geoalt) {
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSetTopo,
        args: {'geolon': geolon, 'geolat': geolat, 'geoalt': geoalt},
        category: CallCategory.context,
        traceId: '$_tabTag:set_topo',
      ),
    );
    _delegate.setTopo(geolon, geolat, geoalt);
  }

  @override
  void setJplFile(String filename) {
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSetJplFile,
        args: {'filename': filename},
        category: CallCategory.context,
        traceId: '$_tabTag:set_jpl_file',
      ),
    );
    _delegate.setJplFile(filename);
  }

  // --------------- Calculation methods ---------------

  @override
  CalcResult calcUt(double jdUt, int body, int flags) {
    final traceId = '$_tabTag:calc_ut:body=$body';
    String? errorMessage;
    try {
      final result = _delegate.calcUt(jdUt, body, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCalcUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
          returnFlag: result.returnFlag,
        ),
      );
      return result;
    } catch (e) {
      errorMessage = e.toString();
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCalcUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: errorMessage,
        ),
      );
      rethrow;
    }
  }

  @override
  CalcResult calcPctr(double jdEt, int body, int centerBody, int flags) {
    final traceId = '$_tabTag:calc_pctr:body=$body,center=$centerBody';
    try {
      final result = _delegate.calcPctr(jdEt, body, centerBody, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCalcPctr,
          args: {
            'jdEt': jdEt,
            'body': body,
            'centerBody': centerBody,
            'iflag': flags,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
          returnFlag: result.returnFlag,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCalcPctr,
          args: {
            'jdEt': jdEt,
            'body': body,
            'centerBody': centerBody,
            'iflag': flags,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  HouseResult houses(double jdUt, double geolat, double geolon, int hsys) {
    final traceId = '$_tabTag:houses:hsys=$hsys';
    try {
      final result = _delegate.houses(jdUt, geolat, geolon, hsys);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHouses,
          args: {
            'jdUt': jdUt,
            'geolat': geolat,
            'geolon': geolon,
            'hsys': hsys,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHouses,
          args: {
            'jdUt': jdUt,
            'geolat': geolat,
            'geolon': geolon,
            'hsys': hsys,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  double gauquelinSector(
    double jdUt,
    int body,
    int flags,
    int method, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    String? starName,
  }) {
    final traceId = '$_tabTag:gauquelin_sector:body=$body';
    try {
      final result = _delegate.gauquelinSector(
        jdUt,
        body,
        flags,
        method,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
        starName: starName,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGauquelinSector,
          args: {
            'jdUt': jdUt,
            'body': body,
            'iflag': flags,
            'method': method,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGauquelinSector,
          args: {
            'jdUt': jdUt,
            'body': body,
            'iflag': flags,
            'method': method,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  double getAyanamsaUt(double jdUt) {
    final traceId = '$_tabTag:get_ayanamsa_ut';
    final result = _delegate.getAyanamsaUt(jdUt);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweGetAyanamsaUt,
        args: {'jdUt': jdUt},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  AyanamsaResult getAyanamsaExUt(double jdUt, int flags) {
    final traceId = '$_tabTag:get_ayanamsa_ex_ut';
    try {
      final result = _delegate.getAyanamsaExUt(jdUt, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGetAyanamsaExUt,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGetAyanamsaExUt,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  FixstarResult fixstar2Ut(String star, double jdUt, int flags) {
    final traceId = '$_tabTag:fixstar2_ut:star=$star';
    try {
      final result = _delegate.fixstar2Ut(star, jdUt, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweFixstar2Ut,
          args: {'star': star, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
          returnFlag: result.returnFlag,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweFixstar2Ut,
          args: {'star': star, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  double solCrossUt(double longitude, double jdUt, int flags) {
    final traceId = '$_tabTag:sol_cross_ut:lon=$longitude';
    try {
      final result = _delegate.solCrossUt(longitude, jdUt, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolcrossUt,
          args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolcrossUt,
          args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  double moonCrossUt(double longitude, double jdUt, int flags) {
    final traceId = '$_tabTag:moon_cross_ut:lon=$longitude';
    try {
      final result = _delegate.moonCrossUt(longitude, jdUt, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweMooncrossUt,
          args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweMooncrossUt,
          args: {'longitude': longitude, 'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  MoonNodeCrossResult moonCrossNodeUt(double jdUt, int flags) {
    final traceId = '$_tabTag:moon_cross_node_ut';
    try {
      final result = _delegate.moonCrossNodeUt(jdUt, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweMooncrossNodeUt,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweMooncrossNodeUt,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  double helioCrossUt(
    int body,
    double longitude,
    double jdUt,
    int flags,
    int dir,
  ) {
    final traceId = '$_tabTag:helio_cross_ut:body=$body,lon=$longitude';
    try {
      final result = _delegate.helioCrossUt(body, longitude, jdUt, flags, dir);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHeliocrossUt,
          args: {
            'body': body,
            'longitude': longitude,
            'jdUt': jdUt,
            'iflag': flags,
            'dir': dir,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHeliocrossUt,
          args: {
            'body': body,
            'longitude': longitude,
            'jdUt': jdUt,
            'iflag': flags,
            'dir': dir,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  SolarEclipseLocalResult solEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    final traceId = '$_tabTag:sol_eclipse_when_loc';
    try {
      final result = _delegate.solEclipseWhenLoc(
        jdStart,
        flags,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        backward: backward,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhenLoc,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhenLoc,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  SolarEclipseGlobalResult solEclipseWhenGlob(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    final traceId = '$_tabTag:sol_eclipse_when_glob';
    try {
      final result = _delegate.solEclipseWhenGlob(
        jdStart,
        flags,
        eclType: eclType,
        backward: backward,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhenGlob,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'eclType': eclType,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhenGlob,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'eclType': eclType,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  SolarEclipseAttrResult solEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    final traceId = '$_tabTag:sol_eclipse_how';
    try {
      final result = _delegate.solEclipseHow(
        jdUt,
        flags,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseHow,
          args: {
            'jdUt': jdUt,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseHow,
          args: {
            'jdUt': jdUt,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  EclipseWhereResult solEclipseWhere(double jdUt, int flags) {
    final traceId = '$_tabTag:sol_eclipse_where';
    try {
      final result = _delegate.solEclipseWhere(jdUt, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhere,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweSolEclipseWhere,
          args: {'jdUt': jdUt, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  LunarEclipseGlobalResult lunEclipseWhen(
    double jdStart,
    int flags, {
    int eclType = 0,
    bool backward = false,
  }) {
    final traceId = '$_tabTag:lun_eclipse_when';
    try {
      final result = _delegate.lunEclipseWhen(
        jdStart,
        flags,
        eclType: eclType,
        backward: backward,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseWhen,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'eclType': eclType,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseWhen,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'eclType': eclType,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  LunarEclipseLocalResult lunEclipseWhenLoc(
    double jdStart,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    bool backward = false,
  }) {
    final traceId = '$_tabTag:lun_eclipse_when_loc';
    try {
      final result = _delegate.lunEclipseWhenLoc(
        jdStart,
        flags,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        backward: backward,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseWhenLoc,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseWhenLoc,
          args: {
            'jdStart': jdStart,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'backward': backward,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  LunarEclipseAttrResult lunEclipseHow(
    double jdUt,
    int flags, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
  }) {
    final traceId = '$_tabTag:lun_eclipse_how';
    try {
      final result = _delegate.lunEclipseHow(
        jdUt,
        flags,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseHow,
          args: {
            'jdUt': jdUt,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweLunEclipseHow,
          args: {
            'jdUt': jdUt,
            'iflag': flags,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  RiseTransResult riseTrans(
    double jdUt,
    int body, {
    String? starName,
    int epheflag = 4,
    int rsmi = 1,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
  }) {
    final traceId = '$_tabTag:rise_trans:body=$body,rsmi=$rsmi';
    try {
      final result = _delegate.riseTrans(
        jdUt,
        body,
        starName: starName,
        epheflag: epheflag,
        rsmi: rsmi,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweRiseTrans,
          args: {
            'jdUt': jdUt,
            'body': body,
            'epheflag': epheflag,
            'rsmi': rsmi,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweRiseTrans,
          args: {
            'jdUt': jdUt,
            'body': body,
            'epheflag': epheflag,
            'rsmi': rsmi,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  RiseTransResult riseTransTrueHor(
    double jdUt,
    int body, {
    String? starName,
    int epheflag = 4,
    int rsmi = 1,
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    required double horizonHeight,
  }) {
    final traceId = '$_tabTag:rise_trans_true_hor:body=$body,rsmi=$rsmi';
    try {
      final result = _delegate.riseTransTrueHor(
        jdUt,
        body,
        starName: starName,
        epheflag: epheflag,
        rsmi: rsmi,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
        horizonHeight: horizonHeight,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweRiseTransTrueHor,
          args: {
            'jdUt': jdUt,
            'body': body,
            'epheflag': epheflag,
            'rsmi': rsmi,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'horizonHeight': horizonHeight,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweRiseTransTrueHor,
          args: {
            'jdUt': jdUt,
            'body': body,
            'epheflag': epheflag,
            'rsmi': rsmi,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'horizonHeight': horizonHeight,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  AzAltResult azAlt(
    double jdUt,
    int calcFlag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    double atpress = 1013.25,
    double attemp = 15.0,
    required double bodyLon,
    required double bodyLat,
    double bodyDist = 1.0,
  }) {
    final traceId = '$_tabTag:azalt:flag=$calcFlag';
    try {
      final result = _delegate.azAlt(
        jdUt,
        calcFlag,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atpress: atpress,
        attemp: attemp,
        bodyLon: bodyLon,
        bodyLat: bodyLat,
        bodyDist: bodyDist,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweAzalt,
          args: {
            'jdUt': jdUt,
            'calcFlag': calcFlag,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'bodyLon': bodyLon,
            'bodyLat': bodyLat,
            'bodyDist': bodyDist,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweAzalt,
          args: {
            'jdUt': jdUt,
            'calcFlag': calcFlag,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'atpress': atpress,
            'attemp': attemp,
            'bodyLon': bodyLon,
            'bodyLat': bodyLat,
            'bodyDist': bodyDist,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  AzAltRevResult azAltRev(
    double jdUt,
    int calcFlag, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required double azimuth,
    required double altitude,
  }) {
    final traceId = '$_tabTag:azalt_rev:flag=$calcFlag';
    try {
      final result = _delegate.azAltRev(
        jdUt,
        calcFlag,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        azimuth: azimuth,
        altitude: altitude,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweAzaltRev,
          args: {
            'jdUt': jdUt,
            'calcFlag': calcFlag,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'azimuth': azimuth,
            'altitude': altitude,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweAzaltRev,
          args: {
            'jdUt': jdUt,
            'calcFlag': calcFlag,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'azimuth': azimuth,
            'altitude': altitude,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  CoTransResult cotrans(double lon, double lat, double dist, double eps) {
    final traceId = '$_tabTag:cotrans';
    try {
      final result = _delegate.cotrans(lon, lat, dist, eps);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCotrans,
          args: {'lon': lon, 'lat': lat, 'dist': dist, 'eps': eps},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweCotrans,
          args: {'lon': lon, 'lat': lat, 'dist': dist, 'eps': eps},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  double refrac(double altitude, double atpress, double attemp, int calcFlag) {
    final traceId = '$_tabTag:refrac:flag=$calcFlag';
    final result = _delegate.refrac(altitude, atpress, attemp, calcFlag);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweRefrac,
        args: {
          'altitude': altitude,
          'atpress': atpress,
          'attemp': attemp,
          'calcFlag': calcFlag,
        },
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double deltat(double jd) {
    final traceId = '$_tabTag:deltat';
    final result = _delegate.deltat(jd);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweDeltat,
        args: {'jd': jd},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double timeEqu(double jd) {
    final traceId = '$_tabTag:time_equ';
    final result = _delegate.timeEqu(jd);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweTimeEqu,
        args: {'jd': jd},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double sidTime(double jdUt) {
    final traceId = '$_tabTag:sid_time';
    final result = _delegate.sidTime(jdUt);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSidtime,
        args: {'jdUt': jdUt},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double sidTime0(double jdUt, double eps, double nut) {
    final traceId = '$_tabTag:sid_time0';
    final result = _delegate.sidTime0(jdUt, eps, nut);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweSidtime0,
        args: {'jdUt': jdUt, 'eps': eps, 'nut': nut},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double lmtToLat(double jdLmt, double geolon) {
    final traceId = '$_tabTag:lmt_to_lat';
    final result = _delegate.lmtToLat(jdLmt, geolon);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweLmtToLat,
        args: {'jdLmt': jdLmt, 'geolon': geolon},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  double latToLmt(double jdLat, double geolon) {
    final traceId = '$_tabTag:lat_to_lmt';
    final result = _delegate.latToLmt(jdLat, geolon);
    _entries.add(
      CallEntry(
        functionName: TracedFunction.sweLatToLmt,
        args: {'jdLat': jdLat, 'geolon': geolon},
        category: CallCategory.calc,
        traceId: traceId,
        result: result,
      ),
    );
    return result;
  }

  @override
  NodeApsResult nodApsUt(double jdUt, int body, int flags, int method) {
    final traceId = '$_tabTag:nod_aps_ut:body=$body';
    try {
      final result = _delegate.nodApsUt(jdUt, body, flags, method);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweNodApsUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags, 'method': method},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweNodApsUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags, 'method': method},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  OrbitalElementsResult getOrbitalElements(double jdEt, int body, int flags) {
    final traceId = '$_tabTag:get_orbital_elements:body=$body';
    try {
      final result = _delegate.getOrbitalElements(jdEt, body, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGetOrbitalElements,
          args: {'jdEt': jdEt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweGetOrbitalElements,
          args: {'jdEt': jdEt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  OrbitDistanceResult orbitMaxMinTrueDistance(
    double jdEt,
    int body,
    int flags,
  ) {
    final traceId = '$_tabTag:orbit_max_min_true_distance:body=$body';
    try {
      final result = _delegate.orbitMaxMinTrueDistance(jdEt, body, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweOrbitMaxMinTrueDistance,
          args: {'jdEt': jdEt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweOrbitMaxMinTrueDistance,
          args: {'jdEt': jdEt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  PhenoResult phenoUt(double jdUt, int body, int flags) {
    final traceId = '$_tabTag:pheno_ut:body=$body';
    try {
      final result = _delegate.phenoUt(jdUt, body, flags);
      _entries.add(
        CallEntry(
          functionName: TracedFunction.swePhenoUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.swePhenoUt,
          args: {'jdUt': jdUt, 'body': body, 'iflag': flags},
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  HeliacalResult heliacalUt(
    double jdStart, {
    required double geolon,
    required double geolat,
    double geoalt = 0,
    required AtmoConditions atmo,
    required ObserverConditions observer,
    required String objectName,
    required int typeEvent,
    int flags = 0,
  }) {
    final traceId = '$_tabTag:heliacal_ut:obj=$objectName,event=$typeEvent';
    try {
      final result = _delegate.heliacalUt(
        jdStart,
        geolon: geolon,
        geolat: geolat,
        geoalt: geoalt,
        atmo: atmo,
        observer: observer,
        objectName: objectName,
        typeEvent: typeEvent,
        flags: flags,
      );
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHeliacalUt,
          args: {
            'jdStart': jdStart,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'objectName': objectName,
            'typeEvent': typeEvent,
            'flags': flags,
          },
          category: CallCategory.calc,
          traceId: traceId,
          result: result,
        ),
      );
      return result;
    } catch (e) {
      _entries.add(
        CallEntry(
          functionName: TracedFunction.sweHeliacalUt,
          args: {
            'jdStart': jdStart,
            'geolon': geolon,
            'geolat': geolat,
            'geoalt': geoalt,
            'objectName': objectName,
            'typeEvent': typeEvent,
            'flags': flags,
          },
          category: CallCategory.calc,
          traceId: traceId,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }
}
