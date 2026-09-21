enum PlantStage { pousse, jeunePlante }

const stepsPerWaterDose = 300;

String localDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class GardenSnapshot {
  const GardenSnapshot({
    required this.plantStage,
    required this.waterDoses,
    required this.waterProgress,
    required this.creditedStepWaterDoses,
    required this.creditedDay,
  });

  static const empty = GardenSnapshot(
    plantStage: null,
    waterDoses: 0,
    waterProgress: 0,
    creditedStepWaterDoses: 0,
    creditedDay: null,
  );

  final PlantStage? plantStage;
  final int waterDoses;
  final int waterProgress;
  final int creditedStepWaterDoses;
  final String? creditedDay;
}

abstract interface class GardenStore {
  Future<GardenSnapshot> load();
  Future<void> save(GardenSnapshot snapshot);
}
