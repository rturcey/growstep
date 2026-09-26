import 'step_provider.dart';
import '../garden/garden_state.dart';
import '../garden/local_date.dart';

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

  final Map<String, int> _stepsByDay = {};

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

  void restoreCreditedSteps(int creditedSteps) {
    _refreshDay();
    if (_steps < creditedSteps) _steps = creditedSteps;
  }

  void addSteps(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    _refreshDay();
    _steps += count;
  }

  void setSteps(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    _refreshDay();
    _steps = count;
  }

  void setStepsOnDay(LocalDate day, int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    _stepsByDay[day.toIsoString()] = count;
  }

  @override
  Future<int> stepsOnDay(LocalDate day) async =>
      _stepsByDay[day.toIsoString()] ?? 0;

  @override
  Future<int> stepsToday() async => currentSteps;
}
