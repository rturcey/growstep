import 'step_provider.dart';

/// The first playable slice uses simulated steps until the iOS provider lands.
class FakeStepProvider implements StepProvider {
  FakeStepProvider({int initialSteps = 0}) : _steps = initialSteps;

  int _steps;

  int get currentSteps => _steps;

  void restoreCreditedSteps(int creditedWaterUnits) {
    final creditedSteps = creditedWaterUnits * 300;
    if (_steps < creditedSteps) _steps = creditedSteps;
  }

  void addSteps(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    _steps += count;
  }

  @override
  Future<int> stepsToday() async => _steps;
}
