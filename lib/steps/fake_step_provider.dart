import 'step_provider.dart';
import '../garden/garden_state.dart';

/// The first playable slice uses simulated steps until the iOS provider lands.
class FakeStepProvider implements StepProvider {
  FakeStepProvider({int initialSteps = 0, DateTime Function()? now})
    : _steps = initialSteps,
      _now = now ?? DateTime.now {
    _day = localDayKey(_now());
  }

  int _steps;
  final DateTime Function() _now;
  late String _day;

  void _refreshDay() {
    final today = localDayKey(_now());
    if (_day == today) return;
    _day = today;
    _steps = 0;
  }

  int get currentSteps {
    _refreshDay();
    return _steps;
  }

  void restoreCreditedSteps(int creditedStepWaterDoses) {
    _refreshDay();
    final creditedSteps = creditedStepWaterDoses * stepsPerWaterDose;
    if (_steps < creditedSteps) _steps = creditedSteps;
  }

  void addSteps(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    _refreshDay();
    _steps += count;
  }

  @override
  Future<int> stepsToday() async => currentSteps;
}
