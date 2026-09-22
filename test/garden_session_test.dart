import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_session.dart';
import 'package:growstep/steps/fake_step_provider.dart';

void main() {
  test('les nouveaux pas font grandir toutes les plantes présentes', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final steps = FakeStepProvider(initialSteps: 500);
    final garden = GardenSession(database: database, stepProvider: steps);
    await garden.load();

    await garden.chooseStarterSeed(Species.tomate);
    await garden.chooseStarterSeed(Species.tournesol);
    await garden.plantSeed(ZoneType.potager, 0, Species.tomate);
    await garden.plantSeed(ZoneType.jardinFleuri, 0, Species.tournesol);

    expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 0);
    expect(garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.progressSteps, 0);

    steps.addSteps(299);
    await garden.refreshSteps();
    expect(
      garden.snapshot.zones[ZoneType.potager]![0]!.stage,
      PlantStage.graineGermee,
    );
    steps.addSteps(1);
    await garden.refreshSteps();
    expect(
      garden.snapshot.zones[ZoneType.potager]![0]!.stage,
      PlantStage.jeunePlant,
    );
    expect(
      garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.progressSteps,
      300,
    );

    steps.addSteps(400);
    await garden.refreshSteps();
    expect(
      garden.snapshot.zones[ZoneType.potager]![0]!.stage,
      PlantStage.presqueMature,
    );
    steps.addSteps(300);
    await garden.refreshSteps();
    expect(
      garden.snapshot.zones[ZoneType.potager]![0]!.stage,
      PlantStage.mature,
    );
    expect(
      garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.progressSteps,
      1000,
    );
  });

  test(
    'les seuils de rareté progressent ensemble et les cycles sont conservés',
    () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final initial = GardenSnapshot.initial();
      final zones = {
        for (final entry in initial.zones.entries) entry.key: [...entry.value],
      };
      zones[ZoneType.potager]![0] = const Plant(
        species: Species.tomate,
        tier: GrowthTier.peuCommune,
      );
      zones[ZoneType.potager]![1] = const Plant(
        species: Species.carotte,
        tier: GrowthTier.rare,
      );
      zones[ZoneType.jardinFleuri]![0] = const Plant(
        species: Species.tournesol,
        tier: GrowthTier.brillante,
      );
      zones[ZoneType.verger]![0] = const Plant(
        species: Species.pommier,
        completedCycles: 1,
      );
      await database.save(initial.copyWith(zones: zones));

      final steps = FakeStepProvider();
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();
      expect(garden.snapshot.zones[ZoneType.verger]![0]!.targetSteps, 500);
      expect(
        garden.snapshot.zones[ZoneType.verger]![0]!.stage,
        PlantStage.mature,
      );

      steps.addSteps(2500);
      await garden.refreshSteps();
      expect(
        garden.snapshot.zones[ZoneType.potager]![0]!.stage,
        PlantStage.mature,
      );
      expect(
        garden.snapshot.zones[ZoneType.potager]![1]!.stage,
        isNot(PlantStage.mature),
      );
      expect(garden.snapshot.zones[ZoneType.verger]![0]!.progressSteps, 500);

      steps.addSteps(3500);
      await garden.refreshSteps();
      expect(
        garden.snapshot.zones[ZoneType.potager]![1]!.stage,
        PlantStage.mature,
      );
      expect(
        garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.stage,
        isNot(PlantStage.mature),
      );

      steps.addSteps(9000);
      await garden.refreshSteps();
      final reopened = GardenSession(database: database, stepProvider: steps);
      await reopened.load();
      expect(
        reopened.snapshot.zones[ZoneType.jardinFleuri]![0]!.stage,
        PlantStage.mature,
      );
      expect(
        reopened.snapshot.zones[ZoneType.jardinFleuri]![0]!.tier,
        GrowthTier.brillante,
      );
      expect(reopened.snapshot.zones[ZoneType.verger]![0]!.completedCycles, 1);
    },
  );

  test('plantations et progression survivent au redémarrage', () async {
    final directory = await Directory.systemTemp.createTemp('growstep-garden-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/garden.sqlite');
    final steps = FakeStepProvider();

    final firstDatabase = GardenDatabase(NativeDatabase(file));
    final first = GardenSession(database: firstDatabase, stepProvider: steps);
    await first.load();
    await first.chooseStarterSeed(Species.carotte);
    await first.chooseStarterSeed(Species.poirier);
    await first.plantSeed(ZoneType.potager, 2, Species.carotte);
    await first.plantSeed(ZoneType.verger, 0, Species.poirier);
    steps.addSteps(700);
    await first.refreshSteps();
    await firstDatabase.close();

    final reopenedDatabase = GardenDatabase(NativeDatabase(file));
    addTearDown(reopenedDatabase.close);
    final reopened = GardenSession(
      database: reopenedDatabase,
      stepProvider: steps,
    );
    await reopened.load();
    expect(
      reopened.snapshot.zones[ZoneType.potager]![2]!.species,
      Species.carotte,
    );
    expect(reopened.snapshot.zones[ZoneType.verger]![0]!.progressSteps, 700);
    expect(
      reopened.snapshot.starterChoices,
      containsAll([ZoneType.potager, ZoneType.verger]),
    );
    await reopened.refreshSteps();
    expect(reopened.snapshot.zones[ZoneType.verger]![0]!.progressSteps, 700);
  });

  test('une correction de pas ne retire pas la croissance acquise', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final steps = FakeStepProvider();
    final garden = GardenSession(database: database, stepProvider: steps);
    await garden.load();
    await garden.chooseStarterSeed(Species.tomate);
    await garden.plantSeed(ZoneType.potager, 0, Species.tomate);

    steps.setSteps(300);
    await garden.refreshSteps();
    steps.setSteps(200);
    await garden.refreshSteps();
    expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 300);

    steps.setSteps(350);
    await garden.refreshSteps();
    expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 350);
  });

  test(
    'une graine plantée après une marche ne reçoit que les pas suivants',
    () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();
      await garden.chooseStarterSeed(Species.tomate);
      await garden.chooseStarterSeed(Species.tulipe);
      await garden.plantSeed(ZoneType.potager, 0, Species.tomate);

      steps.addSteps(300);
      await garden.refreshSteps();
      await garden.plantSeed(ZoneType.jardinFleuri, 0, Species.tulipe);
      expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 300);
      expect(
        garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.progressSteps,
        0,
      );

      steps.addSteps(100);
      await garden.refreshSteps();
      expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 400);
      expect(
        garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.progressSteps,
        100,
      );
    },
  );

  test('la sauvegarde à eau est reprise et conservée en archive', () async {
    final directory = await Directory.systemTemp.createTemp('growstep-old-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/garden.sqlite');
    final old = GardenDatabase(NativeDatabase(file));
    await old.load();
    await old.customStatement('''
      INSERT INTO garden_records VALUES
      (1, 'pousse', 2, 1, 3, '2026-09-22')
    ''');
    await old.customStatement('DROP TABLE garden_state');
    await old.customStatement('PRAGMA user_version = 1');
    await old.close();

    final database = GardenDatabase(NativeDatabase(file));
    addTearDown(database.close);
    final garden = await database.load();
    expect(garden.zones[ZoneType.jardinFleuri]![0]!.species, Species.tournesol);
    expect(garden.zones[ZoneType.jardinFleuri]![0]!.progressSteps, 100);
    expect(garden.florins, 2);
    expect(garden.creditedSteps, 900);
    expect(garden.legacyArchive?['waterDoses'], 2);
    expect((await database.load()).legacyArchive?['waterProgress'], 1);
  });
}
