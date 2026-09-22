import 'dart:math';

import '../steps/step_provider.dart';
import 'garden_state.dart';

export 'garden_state.dart'
    show GardenSnapshot, GrowthTier, Plant, PlantStage, Species, ZoneType;

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
  GardenSnapshot snapshot = GardenSnapshot.initial();

  Future<GardenSnapshot> load() async {
    snapshot = await _store.load();
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
    final zones = {
      for (final entry in snapshot.zones.entries)
        entry.key: [
          for (final plant in entry.value) plant?.withSteps(newSteps),
        ],
    };
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
    Species species,
  ) async {
    if (species.zone != zone) throw ArgumentError('Wrong zone for seed');
    if (slot < 0 || slot >= snapshot.zones[zone]!.length) {
      throw RangeError.index(slot, snapshot.zones[zone]!);
    }
    if (snapshot.zones[zone]![slot] != null) {
      throw StateError('This place already has a plant');
    }
    if ((snapshot.seeds[species] ?? 0) < 1) {
      throw StateError('No seed available');
    }

    // Establish the step baseline before adding a new plant.
    await refreshSteps();
    final zones = {
      for (final entry in snapshot.zones.entries) entry.key: [...entry.value],
    };
    zones[zone]![slot] = Plant(species: species);
    final seeds = {...snapshot.seeds};
    seeds[species] = seeds[species]! - 1;
    snapshot = snapshot.copyWith(zones: zones, seeds: seeds);
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
}
