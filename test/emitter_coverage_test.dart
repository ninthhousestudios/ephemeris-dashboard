import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephemeris/code_emitter.dart';
import 'package:swe_dashboard/core/ephemeris/swe_symbol_catalog.dart';
import 'package:swe_dashboard/core/ephemeris/trace_model.dart';

const _defaultArgs = <String, Object>{
  'jdUt': 2460412.5,
  'jd': 2460412.5,
  'jdLmt': 2460412.5,
  'jdLat': 2460412.5,
  'jdStart': 2460412.5,
  'body': 0,
  'ipl': 0,
  'iflag': 258,
  'ifltype': 0,
  'sidMode': 1,
  't0': 0.0,
  'ayanT0': 0.0,
  'geolon': 0.0,
  'geolat': 0.0,
  'geoalt': 0.0,
  'path': '/tmp/ephe',
  'filename': 'de441.eph',
  'star': 'Aldebaran',
  'hsys': 80,
  'calcFlag': 0,
  'method': 0,
  'backward': 0,
  'rsmi': 0,
  'lon': 0.0,
  'lat': 0.0,
  'alt': 0.0,
  'atpress': 1013.25,
  'attemp': 15.0,
  'eps': 23.4,
  'nut': 0.0,
  'typeEvent': 0,
  'horone': 0.0,
  'centerBody': 0,
  'jdEt': 2460412.5,
  'epheflag': 258,
  'flags': 258,
  'objectName': 'Sun',
  'horizonHeight': 0.0,
};

void main() {
  test('TracedFunction covers all 39 traced methods', () {
    expect(TracedFunction.values, hasLength(39));
  });

  final emitters = <CodeEmitter>[const CEmitter(), const DartEmitter()];

  for (final fn in TracedFunction.values) {
    for (final emitter in emitters) {
      test('${emitter.displayName} renders ${fn.cName}', () {
        final entry = CallEntry(
          functionName: fn,
          args: _defaultArgs,
          category: CallCategory.calc,
          traceId: 'test:coverage',
        );
        final snippet = emitter.emitSnippet(entry);
        expect(
          snippet,
          isNot(startsWith('//')),
          reason: '${fn.cName} must render real code, not a comment stub',
        );
      });
    }
  }
}
