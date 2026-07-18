// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

import '../../core/swe_constants.dart';

import '../../core/export_service.dart';
import '../../core/swe_utils.dart';
import '../../widgets/result_card.dart';

/// The math operations available on this tab.
enum MathOp {
  degnorm('degnorm', 'Normalize to 0–360°', 1),
  radNorm('radNorm', 'Normalize radians', 1),
  splitDeg('splitDeg', 'Split degrees → DMS', 1),
  degMidp('degMidp', 'Midpoint (degrees)', 2),
  radMidp('radMidp', 'Midpoint (radians)', 2),
  difDegn('difDegn', 'Difference 0–360°', 2),
  difDeg2n('difDeg2n', 'Difference −180–180°', 2);

  const MathOp(this.id, this.label, this.inputCount);

  final String id;
  final String label;

  /// How many inputs this operation requires.
  final int inputCount;
}

/// JUSTIFIED EXCEPTION to the reactive-projection model (ADR-0001,
/// swe-dashboard/14): the Math tab is a stateless calculator, not a projection
/// of the Context. Inputs are user-typed per card (not derived from
/// Context/Moment), and the ops (degnorm/splitDeg/degMidp/…) are untraced pure
/// math that touch no Applied Globals. It therefore needs no kernel, no
/// CalcOutcome, and no trace provider; each card owns its own input State and
/// computes on demand.
///
/// Compute a single math operation — pure function, no providers needed.
List<ResultField> computeMathOp(SweUtils swe, MathOp op, double a, double b) {
  try {
    switch (op) {
      case MathOp.degnorm:
        final result = swe.degnorm(a);
        return [
          ResultField(
            label: 'Result (°)',
            value: result.toStringAsFixed(8),
            rawValue: result,
          ),
        ];

      case MathOp.radNorm:
        final result = swe.radNorm(a);
        return [
          ResultField(
            label: 'Result (rad)',
            value: result.toStringAsFixed(8),
            rawValue: result,
          ),
        ];

      case MathOp.splitDeg:
        final r = swe.splitDeg(a, 0);
        return [
          ResultField(
            label: 'Degrees',
            value: '${r.degrees}°',
            rawValue: r.degrees.toDouble(),
          ),
          ResultField(
            label: 'Minutes',
            value: "${r.minutes}'",
            rawValue: r.minutes.toDouble(),
          ),
          ResultField(
            label: 'Seconds',
            value: '${r.seconds}"',
            rawValue: r.seconds.toDouble(),
          ),
          ResultField(
            label: 'Sec fraction',
            value: r.secondsFraction.toStringAsFixed(6),
            rawValue: r.secondsFraction,
          ),
          ResultField(
            label: 'Sign',
            value: '${r.sign}',
            rawValue: r.sign.toDouble(),
          ),
        ];

      case MathOp.degMidp:
        final result = swe.degMidp(a, b);
        return [
          ResultField(
            label: 'Midpoint (°)',
            value: result.toStringAsFixed(8),
            rawValue: result,
          ),
        ];

      case MathOp.radMidp:
        final result = swe.radMidp(a, b);
        return [
          ResultField(
            label: 'Midpoint (rad)',
            value: result.toStringAsFixed(8),
            rawValue: result,
          ),
        ];

      case MathOp.difDegn:
        final result = swe.degnorm(a - b);
        return [
          ResultField(
            label: 'Difference 0–360 (°)',
            value: result.toStringAsFixed(8),
            rawValue: result,
          ),
        ];

      case MathOp.difDeg2n:
        var result = swe.degnorm(a - b);
        if (result > 180.0) result -= 360.0;
        return [
          ResultField(
            label: 'Difference −180–180 (°)',
            value: result.toStringAsFixed(8),
            rawValue: result,
          ),
        ];
    }
  } on SweException catch (e) {
    return [ResultField(label: 'Error', value: e.message, rawValue: 0.0)];
  }
}

/// Convert math results to export rows — collects all computed cards.
List<ExportRow> mathToExportRows(Map<MathOp, List<ResultField>> allResults) {
  return allResults.entries
      .where((e) => e.value.isNotEmpty)
      .map(
        (e) => ExportRow(
          header: e.key.label,
          fields: e.value.map((f) => (f.label, f.value)).toList(),
        ),
      )
      .toList();
}
