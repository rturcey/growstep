import 'dart:math';

enum ZoneType {
  potager('Potager', 4, 8),
  jardinFleuri('Jardin fleuri', 4, 8),
  verger('Verger', 1, 3);

  const ZoneType(this.label, this.initialSlots, this.maxSlots);

  final String label;
  final int initialSlots;
  final int maxSlots;
}

enum Species {
  tomate('Tomate', ZoneType.potager),
  carotte('Carotte', ZoneType.potager),
  courgette('Courgette', ZoneType.potager),
  tournesol('Tournesol', ZoneType.jardinFleuri),
  tulipe('Tulipe', ZoneType.jardinFleuri),
  lavande('Lavande', ZoneType.jardinFleuri),
  pommier('Pommier', ZoneType.verger),
  poirier('Poirier', ZoneType.verger);

  const Species(this.label, this.zone);

  final String label;
  final ZoneType zone;
}

enum PlantStage { graineGermee, jeunePlant, presqueMature, mature }

enum GrowthTier {
  commune(1000),
  peuCommune(2500),
  rare(6000),
  brillante(15000);

  const GrowthTier(this.stepsToMature);

  final int stepsToMature;
}

enum FertilizerType { basique, superEngrais, mega }

String localDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class Plant {
  const Plant({
    required this.species,
    this.tier = GrowthTier.commune,
    this.progressSteps = 0,
    this.completedCycles = 0,
  });

  final Species species;
  final GrowthTier tier;
  final int progressSteps;
  final int completedCycles;

  int get targetSteps => completedCycles == 0
      ? tier.stepsToMature
      : (tier.stepsToMature / 2).ceil();

  List<int> get stageThresholds => [
    (targetSteps * 3 / 10).ceil(),
    (targetSteps * 7 / 10).ceil(),
    targetSteps,
  ];

  PlantStage get stage {
    if (completedCycles > 0 || progressSteps >= targetSteps) {
      return PlantStage.mature;
    }
    final thresholds = stageThresholds;
    if (progressSteps >= thresholds[1]) {
      return PlantStage.presqueMature;
    }
    if (progressSteps >= thresholds[0]) {
      return PlantStage.jeunePlant;
    }
    return PlantStage.graineGermee;
  }

  int get nextThreshold {
    if (completedCycles > 0) return targetSteps;
    for (final threshold in stageThresholds) {
      if (progressSteps < threshold) return threshold;
    }
    return targetSteps;
  }

  Plant withSteps(int steps) => Plant(
    species: species,
    tier: tier,
    progressSteps: min(progressSteps + steps, targetSteps),
    completedCycles: completedCycles,
  );

  Map<String, Object> toJson() => {
    'species': species.name,
    'tier': tier.name,
    'progressSteps': progressSteps,
    'completedCycles': completedCycles,
  };

  factory Plant.fromJson(Map<String, dynamic> json) => Plant(
    species: Species.values.byName(json['species'] as String),
    tier: GrowthTier.values.byName(
      json['tier'] as String? ?? GrowthTier.commune.name,
    ),
    progressSteps: json['progressSteps'] as int,
    completedCycles: json['completedCycles'] as int? ?? 0,
  );
}

class GardenSnapshot {
  const GardenSnapshot({
    required this.zones,
    required this.seeds,
    required this.starterChoices,
    required this.creditedDay,
    required this.creditedSteps,
    required this.florins,
    required this.fertilizers,
    required this.decorations,
    this.legacyArchive,
  });

  factory GardenSnapshot.initial() => GardenSnapshot(
    zones: {
      for (final zone in ZoneType.values)
        zone: List<Plant?>.filled(zone.initialSlots, null),
    },
    seeds: {},
    starterChoices: {},
    creditedDay: null,
    creditedSteps: 0,
    florins: 0,
    fertilizers: {},
    decorations: const [],
  );

  final Map<ZoneType, List<Plant?>> zones;
  final Map<Species, int> seeds;
  final Set<ZoneType> starterChoices;
  final String? creditedDay;
  final int creditedSteps;
  final int florins;
  final Map<FertilizerType, int> fertilizers;
  final List<String> decorations;
  final Map<String, dynamic>? legacyArchive;

  bool get needsFirstPlanting =>
      zones.values.every((slots) => slots.every((plant) => plant == null));

  GardenSnapshot copyWith({
    Map<ZoneType, List<Plant?>>? zones,
    Map<Species, int>? seeds,
    Set<ZoneType>? starterChoices,
    String? creditedDay,
    int? creditedSteps,
    int? florins,
    Map<FertilizerType, int>? fertilizers,
    List<String>? decorations,
    Map<String, dynamic>? legacyArchive,
  }) => GardenSnapshot(
    zones: zones ?? this.zones,
    seeds: seeds ?? this.seeds,
    starterChoices: starterChoices ?? this.starterChoices,
    creditedDay: creditedDay ?? this.creditedDay,
    creditedSteps: creditedSteps ?? this.creditedSteps,
    florins: florins ?? this.florins,
    fertilizers: fertilizers ?? this.fertilizers,
    decorations: decorations ?? this.decorations,
    legacyArchive: legacyArchive ?? this.legacyArchive,
  );

  Map<String, Object?> toJson() => {
    'zones': {
      for (final zone in ZoneType.values)
        zone.name: zones[zone]!.map((plant) => plant?.toJson()).toList(),
    },
    'seeds': {for (final entry in seeds.entries) entry.key.name: entry.value},
    'starterChoices': starterChoices.map((zone) => zone.name).toList(),
    'creditedDay': creditedDay,
    'creditedSteps': creditedSteps,
    'florins': florins,
    'fertilizers': {
      for (final entry in fertilizers.entries) entry.key.name: entry.value,
    },
    'decorations': decorations,
    'legacyArchive': legacyArchive,
  };

  factory GardenSnapshot.fromJson(Map<String, dynamic> json) {
    final rawZones = json['zones'] as Map<String, dynamic>;
    final rawSeeds = json['seeds'] as Map<String, dynamic>;
    final rawFertilizers = json['fertilizers'] as Map<String, dynamic>;
    return GardenSnapshot(
      zones: {
        for (final zone in ZoneType.values)
          zone: (rawZones[zone.name] as List<dynamic>)
              .map(
                (item) => item == null
                    ? null
                    : Plant.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      },
      seeds: {
        for (final entry in rawSeeds.entries)
          Species.values.byName(entry.key): entry.value as int,
      },
      starterChoices: (json['starterChoices'] as List<dynamic>)
          .map((name) => ZoneType.values.byName(name as String))
          .toSet(),
      creditedDay: json['creditedDay'] as String?,
      creditedSteps: json['creditedSteps'] as int,
      florins: json['florins'] as int,
      fertilizers: {
        for (final entry in rawFertilizers.entries)
          FertilizerType.values.byName(entry.key): entry.value as int,
      },
      decorations: (json['decorations'] as List<dynamic>).cast<String>(),
      legacyArchive: json['legacyArchive'] as Map<String, dynamic>?,
    );
  }
}

abstract interface class GardenStore {
  Future<GardenSnapshot> load();
  Future<void> save(GardenSnapshot snapshot);
}
