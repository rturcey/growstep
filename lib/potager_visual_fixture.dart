// Standalone, static app entry point for full-size potager visual review.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';

import 'garden/garden_database.dart';
import 'garden/garden_state.dart';
import 'main.dart' show GrowstepApp;
import 'steps/fake_step_provider.dart';

const visualState = String.fromEnvironment(
  'GROWSTEP_POTAGER_STATE',
  defaultValue: 'initial',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = GardenDatabase(NativeDatabase.memory());
  final initial = await database.load();
  if (visualState == 'intermediaire' || visualState == 'sature') {
    final species = Species.values
        .where((candidate) => candidate.zone == ZoneType.potager)
        .toList();
    final count = visualState == 'intermediaire' ? 6 : 8;
    final potager = List<Plant?>.generate(count, (index) {
      final tier = index == 4 ? GrowthTier.brillante : GrowthTier.commune;
      return Plant(
        species: species[index % species.length],
        tier: tier,
        progressSteps: tier.stepsToMature,
      );
    });
    await database.save(
      initial.copyWith(zones: {...initial.zones, ZoneType.potager: potager}),
    );
  }
  runApp(GrowstepApp(database: database, steps: FakeStepProvider()));
}
