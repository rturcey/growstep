import '../garden/local_date.dart';

abstract interface class StepProvider {
  Future<int> stepsToday();

  /// Returns the step count for a past calendar day.
  Future<int> stepsOnDay(LocalDate day);
}
