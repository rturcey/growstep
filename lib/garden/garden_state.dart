import 'dart:ui';

import 'active_pause.dart';
import 'daily_reward_id.dart';
import 'local_date.dart';

const _unset = Object();

enum ZoneType {
  potager('Potager', 4, 8, 0),
  jardinFleuri('Jardin fleuri', 4, 8, 100),
  verger('Verger', 1, 3, 250);

  const ZoneType(
    this.label,
    this.initialSlots,
    this.maxSlots,
    this.purchasePrice,
  );

  final String label;
  final int initialSlots;
  final int maxSlots;
  final int purchasePrice;
}

enum Species {
  tomate('Tomate', ZoneType.potager, GrowthTier.commune, 1000, 5, 8, false),
  carotte('Carotte', ZoneType.potager, GrowthTier.commune, 1000, 5, 8, false),
  courgette(
    'Courgette',
    ZoneType.potager,
    GrowthTier.commune,
    1000,
    5,
    8,
    false,
  ),
  tournesol(
    'Tournesol',
    ZoneType.jardinFleuri,
    GrowthTier.commune,
    1000,
    5,
    8,
    false,
  ),
  tulipe(
    'Tulipe',
    ZoneType.jardinFleuri,
    GrowthTier.commune,
    1000,
    5,
    8,
    false,
  ),
  lavande(
    'Lavande',
    ZoneType.jardinFleuri,
    GrowthTier.commune,
    1000,
    5,
    8,
    false,
  ),
  pommier('Pommier', ZoneType.verger, GrowthTier.commune, 2000, 5, 3, true),
  poirier('Poirier', ZoneType.verger, GrowthTier.commune, 2000, 5, 3, true);

  const Species(
    this.label,
    this.zone,
    this.rarity,
    this.stepsToMature,
    this.pricePerHarvest,
    this.dailyQuota,
    this.isTree,
  );

  final String label;
  final ZoneType zone;

  /// Rareté intrinsèque à l'espèce. La brillante est un tier posé par-dessus
  /// (voir [Plant.tier]), jamais une rareté d'espèce.
  final GrowthTier rarity;

  /// Pas nécessaires à la maturité (arbres : maturité du tronc).
  final int stepsToMature;

  /// Prix de vente d'une récolte au marché (plein tarif, sous quota).
  final int pricePerHarvest;

  /// Nombre de ventes à plein tarif par jour (surplus à 30 %).
  final int dailyQuota;

  /// Les arbres (verger) ont une production persistante.
  final bool isTree;
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

const brilliantSeedChance = 0.05;
const extraOrdinarySeedChance = 0.5;
const ordinaryBrillantDiscoveryChance = 0.003;

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
  const HarvestReward({this.ordinarySeeds = 0, this.brilliantSeeds = 0});

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
      ? (tier == GrowthTier.brillante
            ? tier.stepsToMature
            : species.stepsToMature)
      : (tier == GrowthTier.brillante
            ? (tier.stepsToMature / 2).ceil()
            : (species.stepsToMature / 2).ceil());

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

class PlacedDecoration {
  const PlacedDecoration({
    required this.placedId,
    required this.decorationId,
    required this.zone,
    required this.contact,
  });

  final String placedId;
  final String decorationId;
  final ZoneType zone;
  final Offset contact;

  Map<String, Object?> toJson() => {
    'placedId': placedId,
    'decorationId': decorationId,
    'zone': zone.name,
    'contact': {'dx': contact.dx, 'dy': contact.dy},
  };

  factory PlacedDecoration.fromJson(Map<String, dynamic> json) =>
      PlacedDecoration(
        placedId: json['placedId'] as String,
        decorationId: json['decorationId'] as String,
        zone: ZoneType.values.byName(json['zone'] as String),
        contact: Offset(
          (json['contact'] as Map<String, dynamic>)['dx'] as double,
          (json['contact'] as Map<String, dynamic>)['dy'] as double,
        ),
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
    this.discoveredSpecies = const {},
    this.discoveredBrilliants = const {},
    this.soldToday = const {},
    this.salesDay,
    this.starterFertilizerGranted = false,
    this.playerSeed = 0,
    this.claimedDailyRewards = const {},
    this.ownedDecorations = const {},
    this.placedDecorations = const [],
    this.pauseRewardsDay,
    this.pauseRewardsCount = 0,
    this.activePause,
    this.invitationHours = const [],
    this.invitationSentKeys = const {},
    this.lastActivityTime,
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
    discoveredSpecies: {Species.tomate, Species.carotte},
    discoveredBrilliants: {},
    soldToday: {},
    salesDay: null,
    creditedDay: null,
    creditedSteps: 0,
    florins: 0,
    fertilizers: {},
    starterFertilizerGranted: false,
    playerSeed: 0,
    claimedDailyRewards: {},
    ownedDecorations: {},
    placedDecorations: [],
    pauseRewardsDay: null,
    pauseRewardsCount: 0,
    activePause: null,
    invitationHours: [],
    invitationSentKeys: {},
    lastActivityTime: null,
    ownedZones: {ZoneType.potager},
  );

  final Map<ZoneType, List<Plant?>> zones;
  final Map<Species, int> seeds;
  final Map<Species, int> brilliantSeeds;
  final Set<ZoneType> starterChoices;
  final Set<Species> discoveredSpecies;
  final Set<Species> discoveredBrilliants;
  final Map<Species, int> soldToday;
  final String? salesDay;
  final String? creditedDay;
  final int creditedSteps;
  final int florins;
  final Map<FertilizerType, int> fertilizers;
  final bool starterFertilizerGranted;
  final int playerSeed;
  final Set<DailyRewardId> claimedDailyRewards;
  final Map<String, int> ownedDecorations;
  final List<PlacedDecoration> placedDecorations;
  final String? pauseRewardsDay;
  final int pauseRewardsCount;
  final ActivePause? activePause;
  final List<int> invitationHours;
  final Set<String> invitationSentKeys;
  final String? lastActivityTime;
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
    Set<Species>? discoveredSpecies,
    Set<Species>? discoveredBrilliants,
    Map<Species, int>? soldToday,
    String? salesDay,
    String? creditedDay,
    int? creditedSteps,
    int? florins,
    Map<FertilizerType, int>? fertilizers,
    bool? starterFertilizerGranted,
    int? playerSeed,
    Set<DailyRewardId>? claimedDailyRewards,
    Map<String, int>? ownedDecorations,
    List<PlacedDecoration>? placedDecorations,
    String? pauseRewardsDay,
    int? pauseRewardsCount,
    Object? activePause = _unset,
    List<int>? invitationHours,
    Set<String>? invitationSentKeys,
    String? lastActivityTime,
    Map<String, dynamic>? legacyArchive,
    Set<ZoneType>? ownedZones,
  }) => GardenSnapshot(
    zones: zones ?? this.zones,
    seeds: seeds ?? this.seeds,
    brilliantSeeds: brilliantSeeds ?? this.brilliantSeeds,
    starterChoices: starterChoices ?? this.starterChoices,
    discoveredSpecies: discoveredSpecies ?? this.discoveredSpecies,
    discoveredBrilliants: discoveredBrilliants ?? this.discoveredBrilliants,
    soldToday: soldToday ?? this.soldToday,
    salesDay: salesDay ?? this.salesDay,
    creditedDay: creditedDay ?? this.creditedDay,
    creditedSteps: creditedSteps ?? this.creditedSteps,
    florins: florins ?? this.florins,
    fertilizers: fertilizers ?? this.fertilizers,
    starterFertilizerGranted:
        starterFertilizerGranted ?? this.starterFertilizerGranted,
    playerSeed: playerSeed ?? this.playerSeed,
    claimedDailyRewards: claimedDailyRewards ?? this.claimedDailyRewards,
    ownedDecorations: ownedDecorations ?? this.ownedDecorations,
    placedDecorations: placedDecorations ?? this.placedDecorations,
    pauseRewardsDay: pauseRewardsDay ?? this.pauseRewardsDay,
    pauseRewardsCount: pauseRewardsCount ?? this.pauseRewardsCount,
    activePause: activePause == _unset
        ? this.activePause
        : activePause as ActivePause?,
    invitationHours: invitationHours ?? this.invitationHours,
    invitationSentKeys: invitationSentKeys ?? this.invitationSentKeys,
    lastActivityTime: lastActivityTime ?? this.lastActivityTime,
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
    'discoveredSpecies': discoveredSpecies
        .map((species) => species.name)
        .toList(),
    'discoveredBrilliants': discoveredBrilliants
        .map((species) => species.name)
        .toList(),
    'soldToday': {
      for (final entry in soldToday.entries) entry.key.name: entry.value,
    },
    'salesDay': salesDay,
    'creditedDay': creditedDay,
    'creditedSteps': creditedSteps,
    'florins': florins,
    'fertilizers': {
      for (final entry in fertilizers.entries) entry.key.name: entry.value,
    },
    'starterFertilizerGranted': starterFertilizerGranted,
    'playerSeed': playerSeed,
    'claimedDailyRewards': [
      for (final id in claimedDailyRewards)
        {'day': id.day.toIsoString(), 'threshold': id.threshold},
    ],
    'ownedDecorations': ownedDecorations,
    'placedDecorations': [for (final d in placedDecorations) d.toJson()],
    'pauseRewardsDay': pauseRewardsDay,
    'pauseRewardsCount': pauseRewardsCount,
    'activePause': activePause?.toJson(),
    'invitationHours': invitationHours,
    'invitationSentKeys': invitationSentKeys.toList(),
    'lastActivityTime': lastActivityTime,
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
        ? rawOwnedZones
              .map((name) => ZoneType.values.byName(name as String))
              .toSet()
        : <ZoneType>{};
    final ownedZones = <ZoneType>{
      ...explicitOwned,
      for (final entry in zones.entries)
        if (entry.value.any((plant) => plant != null)) entry.key,
    };

    final rawClaimedDailyRewards =
        json['claimedDailyRewards'] as List<dynamic>? ?? [];
    final claimedDailyRewards = <DailyRewardId>{
      for (final entry in rawClaimedDailyRewards)
        DailyRewardId(
          LocalDate.fromDateTime(
            DateTime.parse((entry as Map<String, dynamic>)['day'] as String),
          ),
          entry['threshold'] as int,
        ),
    };

    final rawOwnedDecorations =
        json['ownedDecorations'] as Map<String, dynamic>? ?? {};
    final rawPlacedDecorations =
        json['placedDecorations'] as List<dynamic>? ?? [];
    final rawLegacyDecorations = json['decorations'] as List<dynamic>?;
    final migratedOwnedDecorations = <String, int>{
      for (final entry in rawOwnedDecorations.entries)
        entry.key: entry.value as int,
    };
    if (rawLegacyDecorations != null) {
      for (final id in rawLegacyDecorations.cast<String>()) {
        migratedOwnedDecorations[id] = (migratedOwnedDecorations[id] ?? 0) + 1;
      }
    }

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
      discoveredSpecies: (json['discoveredSpecies'] as List<dynamic>? ?? [])
          .map((name) => Species.values.byName(name as String))
          .toSet(),
      discoveredBrilliants:
          (json['discoveredBrilliants'] as List<dynamic>? ?? [])
              .map((name) => Species.values.byName(name as String))
              .toSet(),
      soldToday: {
        for (final entry
            in (json['soldToday'] as Map<String, dynamic>? ?? {}).entries)
          Species.values.byName(entry.key): entry.value as int,
      },
      salesDay: json['salesDay'] as String?,
      creditedDay: json['creditedDay'] as String?,
      creditedSteps: json['creditedSteps'] as int,
      florins: json['florins'] as int,
      fertilizers: {
        for (final entry in rawFertilizers.entries)
          FertilizerType.values.byName(entry.key): entry.value as int,
      },
      starterFertilizerGranted:
          json['starterFertilizerGranted'] as bool? ?? false,
      playerSeed: json['playerSeed'] as int? ?? 0,
      claimedDailyRewards: claimedDailyRewards,
      ownedDecorations: migratedOwnedDecorations,
      placedDecorations: [
        for (final d in rawPlacedDecorations)
          PlacedDecoration.fromJson(d as Map<String, dynamic>),
      ],
      pauseRewardsDay: json['pauseRewardsDay'] as String?,
      pauseRewardsCount: json['pauseRewardsCount'] as int? ?? 0,
      activePause: json['activePause'] == null
          ? null
          : ActivePause.fromJson(json['activePause'] as Map<String, dynamic>),
      invitationHours: (json['invitationHours'] as List<dynamic>? ?? [])
          .cast<int>(),
      invitationSentKeys: (json['invitationSentKeys'] as List<dynamic>? ?? [])
          .cast<String>()
          .toSet(),
      lastActivityTime: json['lastActivityTime'] as String?,
      legacyArchive: json['legacyArchive'] as Map<String, dynamic>?,
      ownedZones: ownedZones,
    );
  }
}

abstract interface class GardenStore {
  Future<GardenSnapshot> load();
  Future<void> save(GardenSnapshot snapshot);
}
