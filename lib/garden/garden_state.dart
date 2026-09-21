enum PlantStage { pousse, jeunePlante }

class GardenSnapshot {
  const GardenSnapshot({
    required this.plantStage,
    required this.waterDoses,
    required this.waterProgress,
    required this.creditedWaterUnits,
  });

  static const empty = GardenSnapshot(
    plantStage: null,
    waterDoses: 0,
    waterProgress: 0,
    creditedWaterUnits: 0,
  );

  final PlantStage? plantStage;
  final int waterDoses;
  final int waterProgress;
  final int creditedWaterUnits;
}

abstract interface class GardenStore {
  Future<GardenSnapshot> load();
  Future<void> save(GardenSnapshot snapshot);
}
