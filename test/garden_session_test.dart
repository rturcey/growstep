import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_session.dart';
import 'package:growstep/steps/fake_step_provider.dart';

void main() {
  test(
    'les pas simulés permettent de planter puis faire grandir une plante',
    () async {
      final database = GardenDatabase(NativeDatabase.memory());
      final steps = FakeStepProvider();
      final garden = GardenSession(database: database, stepProvider: steps);
      addTearDown(database.close);

      expect((await garden.load()).waterDoses, 0);

      await garden.plantSeed();
      expect(garden.snapshot.plantStage, PlantStage.pousse);

      for (var dose = 1; dose <= 3; dose++) {
        steps.addSteps(300);
        await garden.refreshSteps();
        expect(garden.snapshot.waterDoses, 1);
        await garden.waterPlant();
        expect(garden.snapshot.waterDoses, 0);
      }

      expect(garden.snapshot.plantStage, PlantStage.jeunePlante);
      expect(garden.snapshot.waterProgress, 0);
    },
  );

  test(
    'le jardin et la dose déjà attribuée survivent au redémarrage',
    () async {
      final directory = await Directory.systemTemp.createTemp('growstep-test-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final steps = FakeStepProvider();

      final firstDatabase = GardenDatabase(NativeDatabase(file));
      final first = GardenSession(database: firstDatabase, stepProvider: steps);
      await first.load();
      await first.plantSeed();
      steps.addSteps(300);
      await first.refreshSteps();
      await first.waterPlant();
      await firstDatabase.close();

      final reopenedDatabase = GardenDatabase(NativeDatabase(file));
      addTearDown(reopenedDatabase.close);
      final reopened = GardenSession(
        database: reopenedDatabase,
        stepProvider: steps,
      );
      final restored = await reopened.load();

      expect(restored.plantStage, PlantStage.pousse);
      expect(restored.waterProgress, 1);
      expect(restored.waterDoses, 0);
      expect((await reopened.refreshSteps()).waterDoses, 0);

      steps.addSteps(600);
      expect((await reopened.refreshSteps()).waterDoses, 2);
    },
  );
}
