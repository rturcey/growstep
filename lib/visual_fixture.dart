// Separate executable for reproducible visual review. The production entry
// point in main.dart never creates this fixture.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';

import 'garden/garden_database.dart';
import 'garden/garden_state.dart';
import 'main.dart' show GrowstepApp;
import 'steps/fake_step_provider.dart';

const visualState = String.fromEnvironment('GROWSTEP_VISUAL_STATE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = GardenDatabase(NativeDatabase.memory());
  final initial = await database.load();
  final zones = <ZoneType, List<Plant?>>{
    for (final entry in initial.zones.entries) entry.key: [...entry.value],
  };
  if (visualState == 'sature') {
    for (final zone in ZoneType.values) {
      final species = Species.values
          .where((value) => value.zone == zone)
          .toList();
      zones[zone] = List.generate(zone.maxSlots, (index) {
        final tier = index == 0 ? GrowthTier.brillante : GrowthTier.commune;
        return Plant(
          species: species[index % species.length],
          tier: tier,
          progressSteps: tier.stepsToMature,
        );
      });
    }
  }
  await database.save(
    initial.copyWith(zones: zones, ownedZones: ZoneType.values.toSet()),
  );
  runApp(GrowstepApp(database: database, steps: FakeStepProvider()));
}
