// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/horizons/horizons_client.dart';
import 'package:swe_dashboard/core/horizons/horizons_request.dart';
import 'package:swe_dashboard/core/horizons/horizons_response.dart';
import 'package:swe_dashboard/core/horizons/horizons_types.dart';

const _observerRequest = HorizonsRequest(
  target: HorizonsTarget('499'),
  center: CoordinateCenter('500@399'),
  time: TimeRange(start: '2026-08-20', stop: '2026-08-21', step: '1 d'),
  options: ObserverOptions(quantities: {1, 9, 20}),
);

void main() {
  group('toQueryParameters', () {
    final params = _observerRequest.toQueryParameters();

    test('single-quotes values but not format', () {
      expect(params['format'], 'json');
      expect(params['COMMAND'], "'499'");
      expect(params['EPHEM_TYPE'], "'OBSERVER'");
      expect(params['CENTER'], "'500@399'");
    });

    test('emits the time range', () {
      expect(params['START_TIME'], "'2026-08-20'");
      expect(params['STOP_TIME'], "'2026-08-21'");
      expect(params['STEP_SIZE'], "'1 d'");
    });

    test('sorts and joins observer quantities', () {
      expect(params['QUANTITIES'], "'1,9,20'");
    });

    test('omits QUANTITIES when none selected', () {
      const req = HorizonsRequest(
        target: HorizonsTarget('499'),
        center: CoordinateCenter('500@399'),
        time: TimeList(['2451545.0']),
        options: ObserverOptions(),
      );
      expect(req.toQueryParameters().containsKey('QUANTITIES'), isFalse);
    });

    test('vectors query carries only vector params, no observer params', () {
      const req = HorizonsRequest(
        target: HorizonsTarget('499'),
        center: CoordinateCenter('500@10'),
        time: TimeRange(start: 'A', stop: 'B', step: '1 d'),
        options: VectorOptions(refPlane: RefPlane.frame),
      );
      final p = req.toQueryParameters();
      expect(p['EPHEM_TYPE'], "'VECTORS'");
      expect(p['VEC_TABLE'], "'3'");
      expect(p['REF_PLANE'], "'FRAME'");
      expect(p.containsKey('QUANTITIES'), isFalse);
      expect(p.containsKey('ANG_FORMAT'), isFalse);
    });

    test('topocentric center adds COORD_TYPE and SITE_COORD', () {
      const req = HorizonsRequest(
        target: HorizonsTarget('499'),
        center: TopocentricCenter(
          bodyId: '399',
          coordType: CoordType.geodetic,
          siteCoord: '-71.0,42.3,0.0',
        ),
        time: TimeRange(start: 'A', stop: 'B', step: '1 d'),
        options: ObserverOptions(),
      );
      final p = req.toQueryParameters();
      expect(p['CENTER'], "'coord@399'");
      expect(p['COORD_TYPE'], "'GEODETIC'");
      expect(p['SITE_COORD'], "'-71.0,42.3,0.0'");
    });

    test('TLIST quotes each epoch and space-joins', () {
      const req = HorizonsRequest(
        target: HorizonsTarget('499'),
        center: CoordinateCenter('500@399'),
        time: TimeList(['2451545.0', '2033-Jan-17 12:10']),
        options: ObserverOptions(),
      );
      final p = req.toQueryParameters();
      expect(p['TLIST'], "'2451545.0' '2033-Jan-17 12:10'");
      expect(p.containsKey('TLIST_TYPE'), isFalse);
    });

    test('TLIST_TYPE is emitted for JD epochs', () {
      const req = HorizonsRequest(
        target: HorizonsTarget('499'),
        center: CoordinateCenter('500@399'),
        time: TimeList(['2451545.0'], type: TimeListType.jd),
        options: ObserverOptions(),
      );
      final p = req.toQueryParameters();
      expect(p['TLIST'], "'2451545.0'");
      expect(p['TLIST_TYPE'], "'JD'");
    });

    test('rawOverrides win over built params', () {
      const req = HorizonsRequest(
        target: HorizonsTarget('499'),
        center: CoordinateCenter('500@399'),
        time: TimeRange(start: 'A', stop: 'B', step: '1 d'),
        options: ObserverOptions(),
        rawOverrides: {'CENTER': "'@0'", 'NEW_PARAM': 'X'},
      );
      final p = req.toQueryParameters();
      expect(p['CENTER'], "'@0'");
      expect(p['NEW_PARAM'], 'X');
    });
  });

  group('requestUrl', () {
    test('encodes space as %20, quotes as %27, and points at the API', () {
      final url = _observerRequest.requestUrl();
      expect(url, startsWith('$horizonsApiEndpoint?'));
      expect(url, contains('COMMAND=%27499%27'));
      expect(url, contains('STEP_SIZE=%271%20d%27'));
      expect(url, isNot(contains('+'))); // never form-encode spaces as '+'
    });
  });

  group('type-specific option params', () {
    HorizonsRequest req(EphemOptions options) => HorizonsRequest(
      target: const HorizonsTarget('499'),
      center: const CoordinateCenter('500@10'),
      time: const TimeRange(start: 'A', stop: 'B', step: '1 d'),
      options: options,
    );

    test('vectors emit VEC_LABELS and VEC_DELTA_T', () {
      final p = req(
        const VectorOptions(vecLabels: false, vecDeltaT: true),
      ).toQueryParameters();
      expect(p['VEC_LABELS'], "'NO'");
      expect(p['VEC_DELTA_T'], "'YES'");
    });

    test('elements emit ELM_LABELS and TP_TYPE', () {
      final p = req(
        const ElementOptions(
          elmLabels: false,
          tpType: PeriapsisTimeType.relative,
        ),
      ).toQueryParameters();
      expect(p['ELM_LABELS'], "'NO'");
      expect(p['TP_TYPE'], "'RELATIVE'");
    });

    test('approach emits CA_TABLE_TYPE', () {
      final p = req(
        const ApproachOptions(tableType: ApproachTableType.extended),
      ).toQueryParameters();
      expect(p['CA_TABLE_TYPE'], "'EXTENDED'");
    });

    test('observer filters emit only when set (R_T_S_ONLY always)', () {
      final bare = req(const ObserverOptions()).toQueryParameters();
      expect(bare['R_T_S_ONLY'], "'NO'");
      expect(bare.containsKey('ELEV_CUT'), isFalse);
      expect(bare.containsKey('AIRMASS'), isFalse);
      expect(bare.containsKey('SOLAR_ELONG'), isFalse);
      expect(bare.containsKey('TIME_ZONE'), isFalse);

      final set = req(
        const ObserverOptions(
          elevationCutDegrees: 10,
          airmass: 2.5,
          solarElong: '0,120',
          timeZone: '-05:00',
          riseTransitSetOnly: true,
        ),
      ).toQueryParameters();
      expect(set['ELEV_CUT'], "'10.0'");
      expect(set['AIRMASS'], "'2.5'");
      expect(set['SOLAR_ELONG'], "'0,120'");
      expect(set['TIME_ZONE'], "'-05:00'");
      expect(set['R_T_S_ONLY'], "'YES'");
    });
  });

  group('parseHorizonsBody', () {
    test('a result with an ephemeris block is a HorizonsTable', () {
      final body = jsonEncode({
        'signature': {'source': 'NASA/JPL Horizons API', 'version': '1.2'},
        'result':
            'Target body: Mars\n\$\$SOE\n2026-Aug-20 00:00, 1.5\n\$\$EOE\n',
      });
      final resp = parseHorizonsBody(body, httpStatus: 200);
      expect(resp, isA<HorizonsTable>());
      final table = resp as HorizonsTable;
      expect(table.rawText, contains(r'$$SOE'));
      expect(table.signature, 'NASA/JPL Horizons API');
    });

    test('an error field becomes a HorizonsApiError', () {
      final body = jsonEncode({'error': 'Cannot interpret COMMAND.'});
      final resp = parseHorizonsBody(body, httpStatus: 200);
      expect(resp, isA<HorizonsApiError>());
      expect((resp as HorizonsApiError).message, 'Cannot interpret COMMAND.');
    });

    test('a 400 message becomes a HorizonsApiError', () {
      final body = jsonEncode({'message': 'Unknown keyword FOO.'});
      final resp = parseHorizonsBody(body, httpStatus: 400);
      expect(resp, isA<HorizonsApiError>());
      expect((resp as HorizonsApiError).httpStatus, 400);
    });

    test('non-JSON body is a HorizonsApiError, not a throw', () {
      final resp = parseHorizonsBody('<html>500</html>', httpStatus: 500);
      expect(resp, isA<HorizonsApiError>());
      expect((resp as HorizonsApiError).rawText, contains('html'));
    });

    test('an spk field decodes to HorizonsSpk bytes', () {
      final bytes = [1, 2, 3, 4, 5];
      final body = jsonEncode({
        'spk': base64.encode(bytes),
        'spk_file_id': '1234567',
      });
      final resp = parseHorizonsBody(body, httpStatus: 200);
      expect(resp, isA<HorizonsSpk>());
      final spk = resp as HorizonsSpk;
      expect(spk.bytes, bytes);
      expect(spk.suggestedFilename, '1234567.bsp');
    });

    test('a non-unique target list is a HorizonsDisambiguation', () {
      final result = [
        'Multiple major-bodies match string "europa"',
        '  ID#      Name',
        '  502      Europa',
        '  52       Europa (asteroid)',
        '(2 matches. To SELECT, enter record # (integer), followed by semi-colon.)',
      ].join('\n');
      final resp = parseHorizonsBody(
        jsonEncode({'result': result}),
        httpStatus: 200,
      );
      expect(resp, isA<HorizonsDisambiguation>());
      final dis = resp as HorizonsDisambiguation;
      expect(dis.candidates.map((c) => c.recordId), containsAll(['502', '52']));
    });
  });

  group('parseEphemerisTable', () {
    // A CSV_FORMAT=YES OBSERVER block: header line, a **** rule, then the
    // $$SOE/$$EOE-delimited data. Both header and rows end with a trailing
    // comma (Horizons always does).
    const result = '''
Target body: Mars (499)
*******************************************************************************
 Date__(UT)__HR:MN, , , R.A._(ICRF), DEC_(ICRF), APmag,
*******************************************************************************
\$\$SOE
2026-Aug-20 00:00, , , 18 44 09.94, -23 02 45.6, -26.75,
2026-Aug-21 00:00, , , 18 46 12.01, -23 01 10.2, -26.74,
\$\$EOE
*******************************************************************************
''';

    test('extracts columns and rows from the delimited CSV block', () {
      final parsed = parseEphemerisTable(result)!;
      expect(parsed.columns, [
        'Date__(UT)__HR:MN',
        '',
        '',
        'R.A._(ICRF)',
        'DEC_(ICRF)',
        'APmag',
      ]);
      expect(parsed.rows.length, 2);
      expect(parsed.rows.first, [
        '2026-Aug-20 00:00',
        '',
        '',
        '18 44 09.94',
        '-23 02 45.6',
        '-26.75',
      ]);
      // Every row is fitted to the header width.
      expect(parsed.rows.every((r) => r.length == parsed.columns.length), true);
    });

    test('a HorizonsTable populates parsed when the block is present', () {
      final resp = parseHorizonsBody(
        jsonEncode({'result': result}),
        httpStatus: 200,
      );
      expect((resp as HorizonsTable).parsed, isNotNull);
      expect(resp.parsed!.rows.length, 2);
    });

    test('returns null when there is no \$\$SOE/\$\$EOE block', () {
      expect(parseEphemerisTable('Target body: Mars\nno table here'), isNull);
    });

    test('returns null for an empty data block', () {
      expect(parseEphemerisTable('h1,h2,\n\$\$SOE\n\$\$EOE\n'), isNull);
    });
  });

  group('horizonsCacheKey', () {
    test('is stable and independent of internal param order', () {
      final key1 = horizonsCacheKey(_observerRequest);
      final key2 = horizonsCacheKey(_observerRequest);
      expect(key1, key2);
    });

    test('differs when a parameter changes', () {
      const other = HorizonsRequest(
        target: HorizonsTarget('299'), // Venus, not Mars
        center: CoordinateCenter('500@399'),
        time: TimeRange(start: '2026-08-20', stop: '2026-08-21', step: '1 d'),
        options: ObserverOptions(quantities: {1, 9, 20}),
      );
      expect(
        horizonsCacheKey(_observerRequest),
        isNot(horizonsCacheKey(other)),
      );
    });
  });

  group('HorizonsCache', () {
    test('round-trips a response and returns null on a miss', () {
      final cache = HorizonsCache();
      const table = HorizonsTable(rawText: 'x');
      expect(cache.get(_observerRequest), isNull);
      cache.put(_observerRequest, table);
      expect(cache.get(_observerRequest), same(table));
    });
  });
}
