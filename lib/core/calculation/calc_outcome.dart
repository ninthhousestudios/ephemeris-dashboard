// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Ninth House Studios LLC

/// Outcome of a tab calculation. Per ADR-0001, results are always a
/// projection of the current Context — there is no "not run" state.
sealed class CalcOutcome<T> {
  const CalcOutcome();
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
