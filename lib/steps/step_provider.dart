import '../garden/local_date.dart';

abstract interface class StepProvider {
  Future<int> stepsToday();

  /// Returns the step count for a past calendar day.
  Future<int> stepsOnDay(LocalDate day);

  /// Returns the step count in the interval [start, end).
  /// These steps are also included in stepsToday()/stepsOnDay();
  /// do not add them to the daily total manually.
  Future<int> stepsBetween(DateTime start, DateTime end);
}
