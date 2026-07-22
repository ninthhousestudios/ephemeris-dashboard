// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Outcome of a tab calculation. Per ADR-0001, results are always a
/// projection of the current Context — there is no "not run" state.
sealed class CalcOutcome<T> {
  const CalcOutcome();

  /// Projects the value of a successful outcome, carrying a failure through
  /// unchanged.
  ///
  /// This is how a tab in series mode runs its existing `*ToExportRows` over
  /// each step: the series yields the tab's typed result, and only the grid
  /// needs the projected form.
  CalcOutcome<R> map<R>(R Function(T value) project) => switch (this) {
    CalcOk<T>(value: final value) => CalcOk(project(value)),
    CalcError<T>(message: final message) => CalcError<R>(message),
  };
}

final class CalcOk<T> extends CalcOutcome<T> {
  const CalcOk(this.value);
  final T value;
}

/// A calculation that failed. [message] is the engine's message for a
/// `SweException`; in a series it may also be the `toString()` of any other
/// error thrown by the step — see `computeSeries`.
final class CalcError<T> extends CalcOutcome<T> {
  const CalcError(this.message);
  final String message;
}
