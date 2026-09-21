import '../steps/step_provider.dart';
import 'garden_state.dart';

export 'garden_state.dart' show GardenSnapshot, PlantStage;

class GardenSession {
  GardenSession({
    required GardenStore database,
    required this.stepProvider,
    DateTime Function()? now,
  }) : _store = database,
       _now = now ?? DateTime.now;

  final GardenStore _store;
  final DateTime Function() _now;
  final StepProvider stepProvider;
  GardenSnapshot snapshot = GardenSnapshot.empty;

  Future<GardenSnapshot> load() async {
    snapshot = await _store.load();
    return snapshot;
  }

  Future<GardenSnapshot> refreshSteps() async {
    final steps = await stepProvider.stepsToday();
    final today = localDayKey(_now());
    final earnedUnits = steps ~/ stepsPerWaterDose;
    final previouslyCredited = snapshot.creditedDay == today
        ? snapshot.creditedStepWaterDoses
        : 0;
    final newUnits = earnedUnits - previouslyCredited;
    if (newUnits <= 0 && snapshot.creditedDay == today) return snapshot;
    snapshot = GardenSnapshot(
      plantStage: snapshot.plantStage,
      waterDoses: snapshot.waterDoses + (newUnits > 0 ? newUnits : 0),
      waterProgress: snapshot.waterProgress,
      creditedStepWaterDoses: earnedUnits,
      creditedDay: today,
    );
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> plantSeed() async {
    if (snapshot.plantStage != null) return snapshot;
    snapshot = GardenSnapshot(
      plantStage: PlantStage.pousse,
      waterDoses: snapshot.waterDoses,
      waterProgress: 0,
      creditedStepWaterDoses: snapshot.creditedStepWaterDoses,
      creditedDay: snapshot.creditedDay,
    );
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> waterPlant() async {
    if (snapshot.plantStage != PlantStage.pousse || snapshot.waterDoses == 0) {
      return snapshot;
    }
    final completed = snapshot.waterProgress == 2;
    snapshot = GardenSnapshot(
      plantStage: completed ? PlantStage.jeunePlante : PlantStage.pousse,
      waterDoses: snapshot.waterDoses - 1,
      waterProgress: completed ? 0 : snapshot.waterProgress + 1,
      creditedStepWaterDoses: snapshot.creditedStepWaterDoses,
      creditedDay: snapshot.creditedDay,
    );
    await _store.save(snapshot);
    return snapshot;
  }
}
