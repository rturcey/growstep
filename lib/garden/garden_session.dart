import '../steps/step_provider.dart';
import 'garden_state.dart';

export 'garden_state.dart' show GardenSnapshot, PlantStage;

class GardenSession {
  GardenSession({required GardenStore database, required this.stepProvider})
    : _store = database;

  final GardenStore _store;
  final StepProvider stepProvider;
  GardenSnapshot snapshot = GardenSnapshot.empty;

  Future<GardenSnapshot> load() async {
    snapshot = await _store.load();
    return snapshot;
  }

  Future<GardenSnapshot> refreshSteps() async {
    final steps = await stepProvider.stepsToday();
    final earnedUnits = steps ~/ 300;
    final newUnits = earnedUnits - snapshot.creditedWaterUnits;
    if (newUnits <= 0) return snapshot;
    snapshot = GardenSnapshot(
      plantStage: snapshot.plantStage,
      waterDoses: snapshot.waterDoses + newUnits,
      waterProgress: snapshot.waterProgress,
      creditedWaterUnits: earnedUnits,
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
      creditedWaterUnits: snapshot.creditedWaterUnits,
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
      creditedWaterUnits: snapshot.creditedWaterUnits,
    );
    await _store.save(snapshot);
    return snapshot;
  }
}
