import 'dart:math';
import 'dart:ui';

import '../steps/step_provider.dart';
import 'daily_progression.dart';
import 'daily_reward_id.dart';
import 'decoration_catalogue.dart';
import 'economy_config.dart';
import 'economy_rules.dart';
import 'garden_scene.dart';
import 'garden_state.dart';
import 'local_date.dart';

export 'daily_progression.dart' show DailyLot;
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
    EconomyConfig? economyConfig,
  }) : _store = database,
       _now = now ?? DateTime.now,
       _roll = roll ?? Random().nextDouble,
       economyConfig = economyConfig ?? EconomyConfig.defaults();

  final GardenStore _store;
  final DateTime Function() _now;
  final double Function() _roll;
  final StepProvider stepProvider;
  final EconomyConfig economyConfig;
  late final EconomyRules _economyRules = EconomyRules(economyConfig);
  late final DailyProgression _dailyProgression = DailyProgression(economyConfig);
  GardenSnapshot snapshot = GardenSnapshot.initial();

  int get harvestFlorinLimit => economyConfig.harvestFlorinDailyLimit;

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
    if (snapshot.playerSeed == 0) {
      snapshot = snapshot.copyWith(playerSeed: Random().nextInt(1 << 31) + 1);
      changed = true;
    }
    if (changed) await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> refreshSteps() async {
    final steps = max(0, await stepProvider.stepsToday());
    final today = localDayKey(_now());
    final todayLocal = LocalDate.fromDateTime(_now());
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

    final isSameWalkDay =
        snapshot.walkFlorinsDay == todayLocal.toIsoString();
    final alreadyClaimedWalk =
        isSameWalkDay ? snapshot.walkFlorinsClaimed : 0;
    final walkFlorins = _economyRules.walkFlorinsFromSteps(
      steps,
      alreadyClaimedWalk,
    );

    snapshot = snapshot.copyWith(
      zones: zones,
      creditedDay: today,
      creditedSteps: max(steps, previouslyCredited),
      florins: snapshot.florins + walkFlorins,
      walkFlorinsDay: todayLocal.toIsoString(),
      walkFlorinsClaimed: alreadyClaimedWalk + walkFlorins,
    );

    snapshot = _creditDailyLots(snapshot, todayLocal, steps);

    await _store.save(snapshot);
    return snapshot;
  }

  GardenSnapshot _creditDailyLots(
    GardenSnapshot current,
    LocalDate day,
    int stepsToday,
  ) {
    final lots = _dailyProgression.lotsFor(current.playerSeed, day);
    final reachedThresholds = _dailyProgression.reachedThresholds(stepsToday);

    var florins = current.florins;
    var seeds = {...current.seeds};
    var brilliantSeeds = {...current.brilliantSeeds};
    var fertilizers = {...current.fertilizers};
    var ownedDecorations = {...current.ownedDecorations};
    final claimed = {...current.claimedDailyRewards};
    var changed = false;

    for (final lot in lots) {
      if (!reachedThresholds.contains(lot.threshold)) continue;
      final rewardId = DailyRewardId(day, lot.threshold);
      if (claimed.contains(rewardId)) continue;

      florins += lot.florins;
      if (lot.seedSpecies != null) {
        seeds[lot.seedSpecies!] = (seeds[lot.seedSpecies!] ?? 0) + 1;
      }
      if (lot.fertilizerType != null) {
        fertilizers[lot.fertilizerType!] =
            (fertilizers[lot.fertilizerType!] ?? 0) + 1;
      }
      if (lot.decorationId != null) {
        ownedDecorations[lot.decorationId!] =
            (ownedDecorations[lot.decorationId!] ?? 0) + 1;
      }
      if (lot.shinySeedSpecies != null) {
        brilliantSeeds[lot.shinySeedSpecies!] =
            (brilliantSeeds[lot.shinySeedSpecies!] ?? 0) + 1;
      }
      claimed.add(rewardId);
      changed = true;
    }

    if (!changed) return current;
    return current.copyWith(
      florins: florins,
      seeds: seeds,
      brilliantSeeds: brilliantSeeds,
      fertilizers: fertilizers,
      ownedDecorations: ownedDecorations,
      claimedDailyRewards: claimed,
    );
  }

  List<DailyLot> previewDailyLots(LocalDate day) =>
      _dailyProgression.lotsFor(snapshot.playerSeed, day);

  Future<GardenSnapshot> applyLateSteps(LocalDate pastDay) async {
    final steps = max(0, await stepProvider.stepsOnDay(pastDay));
    if (steps <= 0) return snapshot;

    final dayKey = pastDay.toIsoString();
    final isSameWalkDay = snapshot.walkFlorinsDay == dayKey;
    final alreadyClaimedWalk =
        isSameWalkDay ? snapshot.walkFlorinsClaimed : 0;
    final walkFlorins = _economyRules.walkFlorinsFromSteps(
      steps,
      alreadyClaimedWalk,
    );

    if (walkFlorins > 0) {
      snapshot = snapshot.copyWith(
        florins: snapshot.florins + walkFlorins,
        walkFlorinsDay: dayKey,
        walkFlorinsClaimed: alreadyClaimedWalk + walkFlorins,
      );
    }

    snapshot = _creditDailyLots(snapshot, pastDay, steps);
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

  Future<GardenSnapshot> buyIsland(ZoneType zone) async {
    if (zone == ZoneType.potager || snapshot.ownedZones.contains(zone)) {
      return snapshot;
    }
    if (snapshot.florins < zone.purchasePrice) {
      throw StateError('Not enough florins to buy ${zone.label}');
    }
    final ownedZones = {...snapshot.ownedZones, zone};
    final zones = {
      for (final entry in snapshot.zones.entries) entry.key: [...entry.value],
    };
    zones[zone] = List<Plant?>.filled(zone.initialSlots, null);
    final next = snapshot.copyWith(
      zones: zones,
      florins: snapshot.florins - zone.purchasePrice,
      ownedZones: ownedZones,
    );
    await _store.save(next);
    snapshot = next;
    return snapshot;
  }

  Future<GardenSnapshot> buySlot(ZoneType zone) async {
    if (!snapshot.ownedZones.contains(zone)) {
      throw StateError('${zone.label} is not owned yet');
    }
    final currentSlots = snapshot.zones[zone]!;
    final alreadyPurchased = currentSlots.length - zone.initialSlots;
    if (currentSlots.length >= zone.maxSlots) {
      throw StateError('${zone.label} has reached its maximum slots');
    }
    final price = _economyRules.slotPrice(zone, alreadyPurchased);
    if (snapshot.florins < price) {
      throw StateError('Not enough florins to buy a slot in ${zone.label}');
    }
    final zones = {
      for (final entry in snapshot.zones.entries) entry.key: [...entry.value],
    };
    zones[zone] = [...currentSlots, null];
    final next = snapshot.copyWith(
      zones: zones,
      florins: snapshot.florins - price,
    );
    await _store.save(next);
    snapshot = next;
    return next;
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

  Future<GardenSnapshot> buySeed(Species species, GrowthTier tier) async {
    if (tier == GrowthTier.brillante) {
      throw StateError('Brillant seeds cannot be purchased');
    }
    final price = _economyRules.seedPrice(tier);
    if (snapshot.florins < price) {
      throw StateError('Not enough florins to buy a ${tier.name} seed');
    }
    final seeds = {...snapshot.seeds};
    seeds[species] = (seeds[species] ?? 0) + 1;
    snapshot = snapshot.copyWith(
      seeds: seeds,
      florins: snapshot.florins - price,
    );
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> buyFertilizer(FertilizerType type) async {
    final price = _economyRules.fertilizerPrice(type);
    if (snapshot.florins < price) {
      throw StateError('Not enough florins to buy ${type.label} fertilizer');
    }
    final fertilizers = {...snapshot.fertilizers};
    fertilizers[type] = (fertilizers[type] ?? 0) + 1;
    snapshot = snapshot.copyWith(
      fertilizers: fertilizers,
      florins: snapshot.florins - price,
    );
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> discardSeeds(
    Species species, {
    bool brilliant = false,
    int count = 1,
  }) async {
    final inventory = brilliant
        ? {...snapshot.brilliantSeeds}
        : {...snapshot.seeds};
    final current = inventory[species] ?? 0;
    if (current < count) {
      throw StateError('Not enough seeds to discard');
    }
    inventory[species] = current - count;
    snapshot = brilliant
        ? snapshot.copyWith(brilliantSeeds: inventory)
        : snapshot.copyWith(seeds: inventory);
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> buyDecoration(String decorationId) async {
    if (!const DecorationCatalogue().contains(decorationId)) {
      throw StateError('Unknown decoration: $decorationId');
    }
    final price = _economyRules.decorationPrice(decorationId);
    if (snapshot.florins < price) {
      throw StateError('Not enough florins to buy $decorationId');
    }
    final owned = {...snapshot.ownedDecorations};
    owned[decorationId] = (owned[decorationId] ?? 0) + 1;
    snapshot = snapshot.copyWith(
      ownedDecorations: owned,
      florins: snapshot.florins - price,
    );
    await _store.save(snapshot);
    return snapshot;
  }

  Future<String> placeDecoration(
    String decorationId,
    ZoneType zone,
    Offset contact,
  ) async {
    if (!snapshot.ownedZones.contains(zone)) {
      throw StateError('${zone.label} is not owned yet');
    }
    final inInventory = snapshot.ownedDecorations[decorationId] ?? 0;
    if (inInventory < 1) {
      throw StateError('No $decorationId in inventory');
    }
    _validateGridContact(contact, decorationId, zone);
    final placedId = '${decorationId}_${_now().microsecondsSinceEpoch}';
    final placed = PlacedDecoration(
      placedId: placedId,
      decorationId: decorationId,
      zone: zone,
      contact: contact,
    );
    final owned = {...snapshot.ownedDecorations};
    owned[decorationId] = inInventory - 1;
    snapshot = snapshot.copyWith(
      ownedDecorations: owned,
      placedDecorations: [...snapshot.placedDecorations, placed],
    );
    await _store.save(snapshot);
    return placedId;
  }

  void _validateGridContact(Offset contact, String decorationId, ZoneType zone) {
    final catalogue = const DecorationCatalogue();
    final def = catalogue.find(decorationId);
    if (def == null) return;
    final halfCellW = IsoGrid.cellWidth / 2;
    final halfCellH = IsoGrid.cellHeight / 2;
    final snappedDx = (contact.dx / halfCellW).round() * halfCellW;
    final snappedDy = (contact.dy / halfCellH).round() * halfCellH;
    if ((snappedDx - contact.dx).abs() > 0.01 ||
        (snappedDy - contact.dy).abs() > 0.01) {
      throw StateError(
        'Contact $contact is not aligned on the 80×40 grid',
      );
    }
    for (final placed in snapshot.placedDecorations) {
      if (placed.zone != zone) continue;
      final dx = (placed.contact.dx - contact.dx).abs();
      final dy = (placed.contact.dy - contact.dy).abs();
      if (dx < halfCellW && dy < halfCellH) {
        throw StateError(
          'Decoration overlaps existing placement at ${placed.contact}',
        );
      }
    }
  }

  Future<GardenSnapshot> moveDecoration(
    String placedId,
    ZoneType zone,
    Offset newContact,
  ) async {
    final placements = [...snapshot.placedDecorations];
    var index = -1;
    for (var i = 0; i < placements.length; i++) {
      if (placements[i].placedId == placedId) {
        index = i;
        break;
      }
    }
    if (index == -1) {
      throw StateError('No placed decoration with id $placedId');
    }
    placements[index] = PlacedDecoration(
      placedId: placedId,
      decorationId: placements[index].decorationId,
      zone: zone,
      contact: newContact,
    );
    snapshot = snapshot.copyWith(placedDecorations: placements);
    await _store.save(snapshot);
    return snapshot;
  }

  Future<GardenSnapshot> removeDecoration(String placedId) async {
    final placements = [...snapshot.placedDecorations];
    var index = -1;
    for (var i = 0; i < placements.length; i++) {
      if (placements[i].placedId == placedId) {
        index = i;
        break;
      }
    }
    if (index == -1) {
      throw StateError('No placed decoration with id $placedId');
    }
    final removed = placements.removeAt(index);
    final owned = {...snapshot.ownedDecorations};
    owned[removed.decorationId] =
        (owned[removed.decorationId] ?? 0) + 1;
    snapshot = snapshot.copyWith(
      placedDecorations: placements,
      ownedDecorations: owned,
    );
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
