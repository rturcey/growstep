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

  test('une nouvelle journée crédite ses pas après redémarrage', () async {
    final directory = await Directory.systemTemp.createTemp('growstep-day-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/garden.sqlite');
    var now = DateTime(2026, 9, 21, 23, 55);
    DateTime clock() => now;
    final steps = FakeStepProvider(now: clock);

    final firstDatabase = GardenDatabase(NativeDatabase(file));
    final first = GardenSession(
      database: firstDatabase,
      stepProvider: steps,
      now: clock,
    );
    await first.load();
    steps.addSteps(900);
    expect((await first.refreshSteps()).waterDoses, 3);
    await firstDatabase.close();

    now = DateTime(2026, 9, 22, 0, 5);
    final reopenedDatabase = GardenDatabase(NativeDatabase(file));
    addTearDown(reopenedDatabase.close);
    final reopened = GardenSession(
      database: reopenedDatabase,
      stepProvider: steps,
      now: clock,
    );
    final restored = await reopened.load();
    expect(restored.waterDoses, 3);
    expect(restored.creditedDay, '2026-09-21');
    expect(steps.currentSteps, 0);

    await reopened.refreshSteps();
    steps.addSteps(300);
    expect((await reopened.refreshSteps()).waterDoses, 4);
    expect((await reopened.refreshSteps()).waterDoses, 4);
    expect(reopened.snapshot.creditedDay, '2026-09-22');
  });
}
