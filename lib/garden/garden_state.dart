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

  // All initial brilliant variants belong to common species.
  double get extraOrdinarySeedChance => switch (this) {
    GrowthTier.commune || GrowthTier.brillante => 0.5,
    GrowthTier.peuCommune => 0.3,
    GrowthTier.rare => 0.1,
  };

  int get florinsPerHarvest => switch (this) {
    GrowthTier.commune => 5,
    GrowthTier.peuCommune => 8,
    GrowthTier.rare || GrowthTier.brillante => 12,
  };
}

const brilliantSeedChance = 0.05;
const dailyHarvestFlorinLimit = 20;

enum FertilizerType {
  basique('Basique', 5),
  superEngrais('Super', 6),
  mega('Méga', 8);

  const FertilizerType(this.label, this.quarterStepMultiplier);

  final String label;
  final int quarterStepMultiplier;

  String get multiplierLabel => switch (this) {
    FertilizerType.basique => '×1,25',
    FertilizerType.superEngrais => '×1,5',
    FertilizerType.mega => '×2',
  };
}

String localDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class HarvestReward {
  const HarvestReward({required this.ordinarySeeds, this.brilliantSeeds = 0});

  final int ordinarySeeds;
  final int brilliantSeeds;

  Map<String, int> toJson() => {
    'ordinarySeeds': ordinarySeeds,
    'brilliantSeeds': brilliantSeeds,
  };

  factory HarvestReward.fromJson(Map<String, dynamic> json) => HarvestReward(
    ordinarySeeds: json['ordinarySeeds'] as int,
    brilliantSeeds: json['brilliantSeeds'] as int? ?? 0,
  );
}

class Plant {
  const Plant({
    required this.species,
    this.tier = GrowthTier.commune,
    this.progressSteps = 0,
    this.completedCycles = 0,
    this.pendingHarvest,
    this.activeFertilizer,
    this.growthRemainderQuarters = 0,
  });

  final Species species;
  final GrowthTier tier;
  final int progressSteps;
  final int completedCycles;
  final HarvestReward? pendingHarvest;
  final FertilizerType? activeFertilizer;
  final int growthRemainderQuarters;

  int get targetSteps => completedCycles == 0
      ? tier.stepsToMature
      : (tier.stepsToMature / 2).ceil();

  bool get isReadyToHarvest => progressSteps >= targetSteps;

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

  Plant withSteps(int steps) {
    if (isReadyToHarvest || steps <= 0) return this;
    final gainedQuarters =
        steps * (activeFertilizer?.quarterStepMultiplier ?? 4);
    final totalQuarters =
        progressSteps * 4 + growthRemainderQuarters + gainedQuarters;
    final finished = totalQuarters >= targetSteps * 4;
    return Plant(
      species: species,
      tier: tier,
      progressSteps: finished ? targetSteps : totalQuarters ~/ 4,
      completedCycles: completedCycles,
      pendingHarvest: pendingHarvest,
      activeFertilizer: finished ? null : activeFertilizer,
      growthRemainderQuarters: finished ? 0 : totalQuarters % 4,
    );
  }

  Plant withFertilizer(FertilizerType type) => Plant(
    species: species,
    tier: tier,
    progressSteps: progressSteps,
    completedCycles: completedCycles,
    pendingHarvest: pendingHarvest,
    activeFertilizer: type,
    growthRemainderQuarters: growthRemainderQuarters,
  );

  Plant withPendingHarvest(HarvestReward reward) => Plant(
    species: species,
    tier: tier,
    progressSteps: progressSteps,
    completedCycles: completedCycles,
    pendingHarvest: reward,
    activeFertilizer: activeFertilizer,
    growthRemainderQuarters: growthRemainderQuarters,
  );

  Plant nextCycle() =>
      Plant(species: species, tier: tier, completedCycles: completedCycles + 1);

  Map<String, Object?> toJson() => {
    'species': species.name,
    'tier': tier.name,
    'progressSteps': progressSteps,
    'completedCycles': completedCycles,
    'pendingHarvest': pendingHarvest?.toJson(),
    'activeFertilizer': activeFertilizer?.name,
    'growthRemainderQuarters': growthRemainderQuarters,
  };

  factory Plant.fromJson(Map<String, dynamic> json) => Plant(
    species: Species.values.byName(json['species'] as String),
    tier: GrowthTier.values.byName(
      json['tier'] as String? ?? GrowthTier.commune.name,
    ),
    progressSteps: json['progressSteps'] as int,
    completedCycles: json['completedCycles'] as int? ?? 0,
    pendingHarvest: json['pendingHarvest'] == null
        ? null
        : HarvestReward.fromJson(
            json['pendingHarvest'] as Map<String, dynamic>,
          ),
    activeFertilizer: json['activeFertilizer'] == null
        ? null
        : FertilizerType.values.byName(json['activeFertilizer'] as String),
    growthRemainderQuarters: json['growthRemainderQuarters'] as int? ?? 0,
  );
}

class GardenSnapshot {
  const GardenSnapshot({
    required this.zones,
    required this.seeds,
    this.brilliantSeeds = const {},
    required this.starterChoices,
    required this.creditedDay,
    required this.creditedSteps,
    required this.florins,
    required this.fertilizers,
    this.harvestFlorinsDay,
    this.harvestFlorinsClaimed = 0,
    this.starterFertilizerGranted = false,
    required this.decorations,
    this.legacyArchive,
    this.ownedZones = const {},
  });

  factory GardenSnapshot.initial() => GardenSnapshot(
    zones: {
      ZoneType.potager: [
        Plant(species: Species.tomate, progressSteps: 700),
        Plant(species: Species.carotte, progressSteps: 300),
        null,
        null,
      ],
      ZoneType.jardinFleuri: List<Plant?>.filled(
        ZoneType.jardinFleuri.initialSlots,
        null,
      ),
      ZoneType.verger: List<Plant?>.filled(ZoneType.verger.initialSlots, null),
    },
    seeds: {},
    brilliantSeeds: {},
    starterChoices: {},
    creditedDay: null,
    creditedSteps: 0,
    florins: 0,
    fertilizers: {},
    harvestFlorinsDay: null,
    harvestFlorinsClaimed: 0,
    starterFertilizerGranted: false,
    decorations: const [],
    ownedZones: {ZoneType.potager},
  );

  final Map<ZoneType, List<Plant?>> zones;
  final Map<Species, int> seeds;
  final Map<Species, int> brilliantSeeds;
  final Set<ZoneType> starterChoices;
  final String? creditedDay;
  final int creditedSteps;
  final int florins;
  final Map<FertilizerType, int> fertilizers;
  final String? harvestFlorinsDay;
  final int harvestFlorinsClaimed;
  final bool starterFertilizerGranted;
  final List<String> decorations;
  final Map<String, dynamic>? legacyArchive;
  final Set<ZoneType> ownedZones;

  bool get needsFirstPlanting =>
      !starterChoices.contains(ZoneType.potager) &&
      zones[ZoneType.potager]!.any((plant) => plant == null);

  GardenSnapshot copyWith({
    Map<ZoneType, List<Plant?>>? zones,
    Map<Species, int>? seeds,
    Map<Species, int>? brilliantSeeds,
    Set<ZoneType>? starterChoices,
    String? creditedDay,
    int? creditedSteps,
    int? florins,
    Map<FertilizerType, int>? fertilizers,
    String? harvestFlorinsDay,
    int? harvestFlorinsClaimed,
    bool? starterFertilizerGranted,
    List<String>? decorations,
    Map<String, dynamic>? legacyArchive,
    Set<ZoneType>? ownedZones,
  }) => GardenSnapshot(
    zones: zones ?? this.zones,
    seeds: seeds ?? this.seeds,
    brilliantSeeds: brilliantSeeds ?? this.brilliantSeeds,
    starterChoices: starterChoices ?? this.starterChoices,
    creditedDay: creditedDay ?? this.creditedDay,
    creditedSteps: creditedSteps ?? this.creditedSteps,
    florins: florins ?? this.florins,
    fertilizers: fertilizers ?? this.fertilizers,
    harvestFlorinsDay: harvestFlorinsDay ?? this.harvestFlorinsDay,
    harvestFlorinsClaimed: harvestFlorinsClaimed ?? this.harvestFlorinsClaimed,
    starterFertilizerGranted:
        starterFertilizerGranted ?? this.starterFertilizerGranted,
    decorations: decorations ?? this.decorations,
    legacyArchive: legacyArchive ?? this.legacyArchive,
    ownedZones: ownedZones ?? this.ownedZones,
  );

  Map<String, Object?> toJson() => {
    'zones': {
      for (final zone in ZoneType.values)
        zone.name: zones[zone]!.map((plant) => plant?.toJson()).toList(),
    },
    'seeds': {for (final entry in seeds.entries) entry.key.name: entry.value},
    'brilliantSeeds': {
      for (final entry in brilliantSeeds.entries) entry.key.name: entry.value,
    },
    'starterChoices': starterChoices.map((zone) => zone.name).toList(),
    'creditedDay': creditedDay,
    'creditedSteps': creditedSteps,
    'florins': florins,
    'fertilizers': {
      for (final entry in fertilizers.entries) entry.key.name: entry.value,
    },
    'harvestFlorinsDay': harvestFlorinsDay,
    'harvestFlorinsClaimed': harvestFlorinsClaimed,
    'starterFertilizerGranted': starterFertilizerGranted,
    'decorations': decorations,
    'legacyArchive': legacyArchive,
    'ownedZones': ownedZones.map((zone) => zone.name).toList(),
  };

  factory GardenSnapshot.fromJson(Map<String, dynamic> json) {
    final rawZones = json['zones'] as Map<String, dynamic>;
    final rawSeeds = json['seeds'] as Map<String, dynamic>;
    final rawBrilliantSeeds =
        json['brilliantSeeds'] as Map<String, dynamic>? ?? {};
    final rawFertilizers = json['fertilizers'] as Map<String, dynamic>;
    final zones = <ZoneType, List<Plant?>>{
      for (final zone in ZoneType.values)
        zone: (rawZones[zone.name] as List<dynamic>)
            .map(
              (item) => item == null
                  ? null
                  : Plant.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
    };
    final rawOwnedZones = json['ownedZones'] as List<dynamic>?;
    final explicitOwned = rawOwnedZones != null
        ? rawOwnedZones.map((name) => ZoneType.values.byName(name as String)).toSet()
        : <ZoneType>{};
    final ownedZones = <ZoneType>{
      ...explicitOwned,
      for (final entry in zones.entries)
        if (entry.value.any((plant) => plant != null)) entry.key,
    };
    return GardenSnapshot(
      zones: zones,
      seeds: {
        for (final entry in rawSeeds.entries)
          Species.values.byName(entry.key): entry.value as int,
      },
      brilliantSeeds: {
        for (final entry in rawBrilliantSeeds.entries)
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
      harvestFlorinsDay: json['harvestFlorinsDay'] as String?,
      harvestFlorinsClaimed: json['harvestFlorinsClaimed'] as int? ?? 0,
      starterFertilizerGranted:
          json['starterFertilizerGranted'] as bool? ?? false,
      decorations: (json['decorations'] as List<dynamic>).cast<String>(),
      legacyArchive: json['legacyArchive'] as Map<String, dynamic>?,
      ownedZones: ownedZones,
    );
  }
}

abstract interface class GardenStore {
  Future<GardenSnapshot> load();
  Future<void> save(GardenSnapshot snapshot);
}
