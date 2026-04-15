import 'package:flutter_test/flutter_test.dart';
import 'package:swe_dashboard/core/ephe/active_file.dart';
import 'package:swe_dashboard/core/ephe/scanner.dart';
import 'package:swe_dashboard/core/ephe/types.dart';

EpheFile _file({
  required String name,
  required BodyFamily family,
  required double startJd,
  required double endJd,
  EpheFileStatus status = EpheFileStatus.installed,
}) =>
    EpheFile(
      filename: name,
      family: family,
      startJd: startJd,
      endJd: endJd,
      startYear: 0,
      endYear: 0,
      sizeBytes: 1,
      status: status,
    );

void main() {
  group('resolveActiveFile', () {
    final scan = EphemerisScan(
      [
        _file(
          name: 'sepl_18.se1',
          family: BodyFamily.planets,
          startJd: 2378496.5,
          endJd: 2597640.5,
        ),
        _file(
          name: 'sepl_12.se1',
          family: BodyFamily.planets,
          startJd: 2159351.5,
          endJd: 2378496.5,
          status: EpheFileStatus.corrupt,
        ),
      ],
      DateTime(2026),
      '/tmp/fake',
    );

    test('in-range JD returns the covering file', () {
      final f = resolveActiveFile(scan, 2460000, BodyFamily.planets);
      expect(f, isNotNull);
      expect(f!.filename, 'sepl_18.se1');
    });

    test('out-of-range JD returns null', () {
      final f = resolveActiveFile(scan, 2700000, BodyFamily.planets);
      expect(f, isNull);
    });

    test('wrong family returns null', () {
      final f = resolveActiveFile(scan, 2460000, BodyFamily.moon);
      expect(f, isNull);
    });

    test('corrupt file in range is skipped', () {
      // 1400 CE sits inside sepl_12's range, but that file is corrupt.
      final f = resolveActiveFile(scan, 2232400, BodyFamily.planets);
      expect(f, isNull);
    });

    test('empty scan returns null', () {
      final empty = EphemerisScan(const [], DateTime(2026), '');
      expect(resolveActiveFile(empty, 2460000, BodyFamily.planets), isNull);
    });
  });
}
