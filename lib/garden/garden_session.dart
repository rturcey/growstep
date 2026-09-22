import 'dart:math';

import '../steps/step_provider.dart';
import 'garden_state.dart';

export 'garden_state.dart'
    show
        FertilizerType,
        GardenSnapshot,
        GrowthTier,
        HarvestReward,
        Plant,
        PlantStage,
        Species,
        ZoneType;

typedef PlantLocation = ({ZoneType zone, int slot});

class HarvestPreview {
  const HarvestPreview({
    required this.locations,
    required this.ordinarySeeds,
    required this.brilliantSeeds,
    required this.florins,
  });

  final List<PlantLocation> locations;
  final Map<Species, int> ordinarySeeds;
  final Map<Species, int> brilliantSeeds;
  final int florins;

  int get count => locations.length;
}

class GardenSession {
  GardenSession({
    required GardenStore database,
    required this.stepProvider,
    DateTime Function()? now,
    double Function()? roll,
    this.harvestFlorinLimit = dailyHarvestFlorinLimit,
  }) : _store = database,
       _now = now ?? DateTime.now,
       _roll = roll ?? Random().nextDouble;

  final GardenStore _store;
  final DateTime Function() _now;
  final double Function() _roll;
  final StepProvider stepProvider;
  final int harvestFlorinLimit;
  GardenSnapshot snapshot = GardenSnapshot.initial();

  int get harvestFlorinsToday =>
      snapshot.harvestFlorinsDay == localDayKey(_now())
      ? snapshot.harvestFlorinsClaimed
      : 0;

  Future<GardenSnapshot> load() async {
    snapshot = await _store.load();
    final ready = _prepareHarvests(snapshot.zones);
    var changed = false;
    if (ready != null) {
      snapshot = snapshot.copyWith(zones: ready);
      changed = true;
    }
    if (!snapshot.starterFertilizerGranted) {
      final fertilizers = {...snapshot.fertilizers};
      fertilizers[FertilizerType.basique] =
          (fertilizers[FertilizerType.basique] ?? 0) + 1;
      snapshot = snapshot.copyWith(
        fertilizers: fertilizers,
        starterFertilizerGranted: true,
      );
      changed = true;
    }
    if (changed) await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> refreshSteps() async {
    final steps = max(0, await stepProvider.stepsToday());
    final today = localDayKey(_now());
    final previouslyCredited = snapshot.creditedDay == today
        ? snapshot.creditedSteps
        : 0;
    if (snapshot.creditedDay == today && steps <= previouslyCredited) {
      return snapshot;
    }

    final newSteps = max(0, steps - previouslyCredited);
    var zones = {
      for (final entry in snapshot.zones.entries)
        entry.key: [
          for (final plant in entry.value) plant?.withSteps(newSteps),
        ],
    };
    zones = _prepareHarvests(zones) ?? zones;
    snapshot = snapshot.copyWith(
      zones: zones,
      creditedDay: today,
      creditedSteps: max(steps, previouslyCredited),
    );
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> chooseStarterSeed(Species species) async {
    if (snapshot.starterChoices.contains(species.zone)) return snapshot;
    final choices = {...snapshot.starterChoices, species.zone};
    final seeds = {...snapshot.seeds};
    seeds[species] = (seeds[species] ?? 0) + 1;
    snapshot = snapshot.copyWith(seeds: seeds, starterChoices: choices);
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> plantSeed(
    ZoneType zone,
    int slot,
    Species species, {
    bool brilliant = false,
  }) async {
    if (species.zone != zone) throw ArgumentError('Wrong zone for seed');
    if (slot < 0 || slot >= snapshot.zones[zone]!.length) {
      throw RangeError.index(slot, snapshot.zones[zone]!);
    }
    if (snapshot.zones[zone]![slot] != null) {
      throw StateError('This place already has a plant');
    }
    final inventory = brilliant ? snapshot.brilliantSeeds : snapshot.seeds;
    if ((inventory[species] ?? 0) < 1) {
      throw StateError('No seed available');
    }

    // Establish the step baseline before adding a new plant.
    await refreshSteps();
    final zones = {
      for (final entry in snapshot.zones.entries) entry.key: [...entry.value],
    };
    zones[zone]![slot] = Plant(
      species: species,
      tier: brilliant ? GrowthTier.brillante : GrowthTier.commune,
    );
    final seeds = {...inventory};
    seeds[species] = seeds[species]! - 1;
    snapshot = brilliant
        ? snapshot.copyWith(zones: zones, brilliantSeeds: seeds)
        : snapshot.copyWith(zones: zones, seeds: seeds);
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> removePlant(ZoneType zone, int slot) async {
    if (slot < 0 || slot >= snapshot.zones[zone]!.length) {
      throw RangeError.index(slot, snapshot.zones[zone]!);
    }
    if (snapshot.zones[zone]![slot] == null) return snapshot;
    final zones = {
      for (final entry in snapshot.zones.entries) entry.key: [...entry.value],
    };
    zones[zone]![slot] = null;
    snapshot = snapshot.copyWith(zones: zones);
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> applyFertilizer(
    ZoneType zone,
    int slot,
    FertilizerType type,
  ) async {
    if (slot < 0 || slot >= snapshot.zones[zone]!.length) {
      throw RangeError.index(slot, snapshot.zones[zone]!);
    }
    if ((snapshot.fertilizers[type] ?? 0) <= 0) return snapshot;

    // Steps recorded before application retain their original growth rate.
    await refreshSteps();
    final plant = snapshot.zones[zone]![slot];
    if (plant == null ||
        plant.isReadyToHarvest ||
        plant.activeFertilizer != null) {
      return snapshot;
    }
    final zones = {
      for (final entry in snapshot.zones.entries) entry.key: [...entry.value],
    };
    zones[zone]![slot] = plant.withFertilizer(type);
    final fertilizers = {...snapshot.fertilizers};
    fertilizers[type] = fertilizers[type]! - 1;
    final next = snapshot.copyWith(zones: zones, fertilizers: fertilizers);
    await _store.save(next);
    snapshot = next;
    return snapshot;
  }

  Map<ZoneType, List<Plant?>>? _prepareHarvests(
    Map<ZoneType, List<Plant?>> source,
  ) {
    var changed = false;
    final zones = <ZoneType, List<Plant?>>{};
    for (final entry in source.entries) {
      final slots = [...entry.value];
      for (var slot = 0; slot < slots.length; slot++) {
        final plant = slots[slot];
        if (plant == null ||
            !plant.isReadyToHarvest ||
            plant.pendingHarvest != null) {
          continue;
        }
        slots[slot] = plant.withPendingHarvest(_rollReward(plant));
        changed = true;
      }
      zones[entry.key] = slots;
    }
    return changed ? zones : null;
  }

  HarvestReward _rollReward(Plant plant) => HarvestReward(
    ordinarySeeds: 1 + (_roll() < plant.tier.extraOrdinarySeedChance ? 1 : 0),
    brilliantSeeds:
        plant.tier == GrowthTier.brillante && _roll() < brilliantSeedChance
        ? 1
        : 0,
  );

  HarvestPreview previewReadyHarvests() {
    final locations = <PlantLocation>[];
    final ordinarySeeds = <Species, int>{};
    final brilliantSeeds = <Species, int>{};
    var requestedFlorins = 0;
    for (final entry in snapshot.zones.entries) {
      for (var slot = 0; slot < entry.value.length; slot++) {
        final plant = entry.value[slot];
        final reward = plant?.pendingHarvest;
        if (plant == null || !plant.isReadyToHarvest || reward == null) {
          continue;
        }
        locations.add((zone: entry.key, slot: slot));
        requestedFlorins += plant.tier.florinsPerHarvest;
        ordinarySeeds[plant.species] =
            (ordinarySeeds[plant.species] ?? 0) + reward.ordinarySeeds;
        if (reward.brilliantSeeds > 0) {
          brilliantSeeds[plant.species] =
              (brilliantSeeds[plant.species] ?? 0) + reward.brilliantSeeds;
        }
      }
    }
    return HarvestPreview(
      locations: List.unmodifiable(locations),
      ordinarySeeds: Map.unmodifiable(ordinarySeeds),
      brilliantSeeds: Map.unmodifiable(brilliantSeeds),
      florins: min(
        max(0, harvestFlorinLimit - harvestFlorinsToday),
        requestedFlorins,
      ),
    );
  }

  Future<GardenSnapshot> harvestPlant(ZoneType zone, int slot) =>
      harvestAll([(zone: zone, slot: slot)]);

  Future<GardenSnapshot> harvestAll(List<PlantLocation> locations) async {
    if (locations.isEmpty) return snapshot;
    final zones = {
      for (final entry in snapshot.zones.entries) entry.key: [...entry.value],
    };
    final ordinarySeeds = {...snapshot.seeds};
    final brilliantSeeds = {...snapshot.brilliantSeeds};
    var harvested = false;
    var requestedFlorins = 0;
    for (final location in locations.toSet()) {
      final slots = zones[location.zone]!;
      if (location.slot < 0 || location.slot >= slots.length) {
        throw RangeError.index(location.slot, slots);
      }
      final plant = slots[location.slot];
      final reward = plant?.pendingHarvest;
      if (plant == null || !plant.isReadyToHarvest || reward == null) {
        continue;
      }
      ordinarySeeds[plant.species] =
          (ordinarySeeds[plant.species] ?? 0) + reward.ordinarySeeds;
      requestedFlorins += plant.tier.florinsPerHarvest;
      if (reward.brilliantSeeds > 0) {
        brilliantSeeds[plant.species] =
            (brilliantSeeds[plant.species] ?? 0) + reward.brilliantSeeds;
      }
      slots[location.slot] = plant.nextCycle();
      harvested = true;
    }
    if (!harvested) return snapshot;
    final harvestDay = localDayKey(_now());
    final alreadyClaimed = snapshot.harvestFlorinsDay == harvestDay
        ? snapshot.harvestFlorinsClaimed
        : 0;
    final grantedFlorins = min(
      max(0, harvestFlorinLimit - alreadyClaimed),
      requestedFlorins,
    );
    final next = snapshot.copyWith(
      zones: zones,
      seeds: ordinarySeeds,
      brilliantSeeds: brilliantSeeds,
      florins: snapshot.florins + grantedFlorins,
      harvestFlorinsDay: harvestDay,
      harvestFlorinsClaimed: alreadyClaimed + grantedFlorins,
    );
    await _store.save(next);
    snapshot = next;
    return snapshot;
  }
}
