/// Outcome of a tab calculation. Per ADR-0001, results are always a
/// projection of the current Context — there is no "not run" state.
sealed class CalcOutcome<T> {
  const CalcOutcome();
}

final class CalcOk<T> extends CalcOutcome<T> {
  const CalcOk(this.value);
  final T value;
}

final class CalcSweError<T> extends CalcOutcome<T> {
  const CalcSweError(this.message);
  final String message;
}
