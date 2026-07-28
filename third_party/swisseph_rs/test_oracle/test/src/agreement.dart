// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import 'package:test/test.dart';

enum AgreementClass { bitwise, positional, boundary, search }

const _positionalTolerance = 1e-9;

void expectAgreement(
  String label,
  double actual,
  double expected,
  AgreementClass cls, {
  double? tolerance,
  String? boundaryArtifact,
}) {
  switch (cls) {
    case AgreementClass.bitwise:
      expect(actual, equals(expected), reason: '$label: bitwise mismatch');
    case AgreementClass.positional:
      expect(
        (actual - expected).abs(),
        lessThanOrEqualTo(_positionalTolerance),
        reason:
            '$label: positional disagreement '
            '(delta=${(actual - expected).abs()}, '
            'tolerance=$_positionalTolerance)',
      );
    case AgreementClass.boundary:
      if (tolerance == null || boundaryArtifact == null) {
        throw ArgumentError(
          '$label: boundary class requires tolerance and boundaryArtifact',
        );
      }
      expect(
        (actual - expected).abs(),
        lessThanOrEqualTo(tolerance),
        reason:
            '$label: boundary disagreement '
            '[artifact: $boundaryArtifact] '
            '(delta=${(actual - expected).abs()}, tolerance=$tolerance)',
      );
    case AgreementClass.search:
      if (tolerance == null) {
        throw ArgumentError('$label: search class requires tolerance');
      }
      expect(
        (actual - expected).abs(),
        lessThanOrEqualTo(tolerance),
        reason:
            '$label: search disagreement '
            '(delta=${(actual - expected).abs()}, tolerance=$tolerance)',
      );
  }
}

class FieldPairSpec<A, E> {
  final String name;
  final double Function(A) extractActual;
  final double Function(E) extractExpected;
  final AgreementClass cls;
  final double? tolerance;
  final String? boundaryArtifact;

  const FieldPairSpec(
    this.name,
    this.extractActual,
    this.extractExpected,
    this.cls, {
    this.tolerance,
    this.boundaryArtifact,
  });
}

class ComparisonSpec<A, E> {
  final List<FieldPairSpec<A, E>> _fields;
  final Set<String> _allFieldNames;

  const ComparisonSpec(this._fields, this._allFieldNames);

  void compare(A actual, E expected) {
    final classified = {for (final f in _fields) f.name};
    final unclassified = _allFieldNames.difference(classified);
    if (unclassified.isNotEmpty) {
      throw StateError('Unclassified field(s): ${unclassified.join(', ')}');
    }
    final extra = classified.difference(_allFieldNames);
    if (extra.isNotEmpty) {
      throw StateError('Unknown field(s) in spec: ${extra.join(', ')}');
    }
    for (final field in _fields) {
      expectAgreement(
        field.name,
        field.extractActual(actual),
        field.extractExpected(expected),
        field.cls,
        tolerance: field.tolerance,
        boundaryArtifact: field.boundaryArtifact,
      );
    }
  }
}
