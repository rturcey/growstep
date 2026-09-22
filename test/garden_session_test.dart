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

  test(
    'la récolte attend le clic et chaque cycle utilise de nouveaux pas',
    () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        roll: () => 0.2,
      );
      await garden.load();
      await garden.chooseStarterSeed(Species.tomate);
      await garden.plantSeed(ZoneType.potager, 0, Species.tomate);

      steps.addSteps(1400);
      await garden.refreshSteps();
      await garden.refreshSteps();
      expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 1000);
      expect(garden.previewReadyHarvests().ordinarySeeds[Species.tomate], 2);
      expect(garden.snapshot.seeds[Species.tomate], 0);

      await garden.harvestPlant(ZoneType.potager, 0);
      expect(garden.snapshot.seeds[Species.tomate], 2);
      expect(garden.snapshot.zones[ZoneType.potager]![0]!.completedCycles, 1);
      expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 0);
      expect(
        garden.snapshot.zones[ZoneType.potager]![0]!.stage,
        PlantStage.mature,
      );
      await garden.harvestPlant(ZoneType.potager, 0);
      expect(garden.snapshot.seeds[Species.tomate], 2);

      steps.addSteps(499);
      await garden.refreshSteps();
      expect(garden.previewReadyHarvests().count, 0);
      steps.addSteps(1);
      await garden.refreshSteps();
      expect(garden.previewReadyHarvests().count, 1);
      await garden.harvestPlant(ZoneType.potager, 0);
      expect(garden.snapshot.seeds[Species.tomate], 4);
      expect(garden.snapshot.zones[ZoneType.potager]![0]!.completedCycles, 2);

      final reopened = GardenSession(database: database, stepProvider: steps);
      await reopened.load();
      await reopened.harvestPlant(ZoneType.potager, 0);
      expect(reopened.snapshot.seeds[Species.tomate], 4);
      expect(reopened.snapshot.zones[ZoneType.potager]![0]!.completedCycles, 2);
    },
  );

  test(
    'la récolte groupée annonce ses graines exactes, dont une brillante',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'growstep-harvest-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      final initial = GardenSnapshot.initial();
      final zones = {
        for (final entry in initial.zones.entries) entry.key: [...entry.value],
      };
      zones[ZoneType.potager]![0] = const Plant(
        species: Species.tomate,
        progressSteps: 1000,
      );
      zones[ZoneType.jardinFleuri]![0] = const Plant(
        species: Species.tournesol,
        tier: GrowthTier.brillante,
        progressSteps: 15000,
      );
      await database.save(initial.copyWith(zones: zones));
      final draws = [0.8, 0.8, 0.04];
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
        roll: () => draws.removeAt(0),
      );
      await garden.load();
      final preview = garden.previewReadyHarvests();
      expect(preview.count, 2);
      expect(preview.ordinarySeeds, {Species.tomate: 1, Species.tournesol: 1});
      expect(preview.brilliantSeeds, {Species.tournesol: 1});
      await database.close();

      final reopenedDatabase = GardenDatabase(NativeDatabase(file));
      addTearDown(reopenedDatabase.close);
      final reopened = GardenSession(
        database: reopenedDatabase,
        stepProvider: FakeStepProvider(),
        roll: () => throw StateError('La récompense ne doit pas être retirée'),
      );
      await reopened.load();
      expect(
        reopened.previewReadyHarvests().brilliantSeeds,
        preview.brilliantSeeds,
      );
      await reopened.harvestAll(preview.locations);
      expect(reopened.snapshot.seeds[Species.tomate], 1);
      expect(reopened.snapshot.seeds[Species.tournesol], 1);
      expect(reopened.snapshot.brilliantSeeds[Species.tournesol], 1);
      await reopened.harvestAll(preview.locations);
      expect(reopened.snapshot.brilliantSeeds[Species.tournesol], 1);

      await reopened.plantSeed(
        ZoneType.jardinFleuri,
        1,
        Species.tournesol,
        brilliant: true,
      );
      expect(reopened.snapshot.brilliantSeeds[Species.tournesol], 0);
      expect(
        reopened.snapshot.zones[ZoneType.jardinFleuri]![1]!.tier,
        GrowthTier.brillante,
      );
    },
  );

  test(
    'une plante supprimée avant ou après maturité ne donne pas de graines',
    () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();
      await garden.chooseStarterSeed(Species.tomate);
      await garden.plantSeed(ZoneType.potager, 0, Species.tomate);
      await garden.removePlant(ZoneType.potager, 0);
      expect(garden.snapshot.seeds[Species.tomate], 0);

      await garden.chooseStarterSeed(Species.tournesol);
      await garden.plantSeed(ZoneType.jardinFleuri, 0, Species.tournesol);
      steps.addSteps(1000);
      await garden.refreshSteps();
      expect(garden.previewReadyHarvests().count, 1);
      await garden.removePlant(ZoneType.jardinFleuri, 0);
      expect(garden.previewReadyHarvests().count, 0);
      expect(garden.snapshot.seeds[Species.tournesol], 0);
    },
  );

  test(
    'le quota des florins suit le jour du clic et laisse les graines',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'growstep-quota-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      final initial = GardenSnapshot.initial();
      final zones = {
        for (final entry in initial.zones.entries) entry.key: [...entry.value],
      };
      for (var slot = 0; slot < 4; slot++) {
        zones[ZoneType.potager]![slot] = const Plant(
          species: Species.tomate,
          tier: GrowthTier.rare,
          progressSteps: 6000,
          pendingHarvest: HarvestReward(ordinarySeeds: 1),
        );
      }
      await database.save(initial.copyWith(zones: zones, florins: 100));
      var now = DateTime(2026, 9, 22, 23, 59);
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
        now: () => now,
      );
      await garden.load();

      await garden.harvestPlant(ZoneType.potager, 0);
      expect(garden.snapshot.florins, 112);
      expect(garden.harvestFlorinsToday, 12);
      final remaining = garden.previewReadyHarvests();
      expect(remaining.florins, 8);
      await garden.harvestAll(remaining.locations.take(2).toList());
      expect(garden.snapshot.florins, 120);
      expect(garden.snapshot.seeds[Species.tomate], 3);
      expect(garden.harvestFlorinsToday, 20);
      expect(garden.previewReadyHarvests().florins, 0);
      await garden.harvestPlant(ZoneType.potager, 0);
      expect(garden.snapshot.florins, 120);

      await database.close();
      final reopenedDatabase = GardenDatabase(NativeDatabase(file));
      addTearDown(reopenedDatabase.close);
      final reopened = GardenSession(
        database: reopenedDatabase,
        stepProvider: FakeStepProvider(),
        now: () => now,
      );
      await reopened.load();
      expect(reopened.harvestFlorinsToday, 20);
      expect(reopened.snapshot.florins, 120);

      now = DateTime(2026, 9, 23, 0, 1);
      expect(reopened.harvestFlorinsToday, 0);
      await reopened.harvestPlant(ZoneType.potager, 3);
      expect(reopened.snapshot.florins, 132);
      expect(reopened.harvestFlorinsToday, 12);
      expect(reopened.snapshot.seeds[Species.tomate], 4);
    },
  );

  test(
    'l’engrais accélère seulement les nouveaux pas du cycle courant',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'growstep-fertilizer-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      final steps = FakeStepProvider();
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();
      expect(garden.snapshot.fertilizers[FertilizerType.basique], 1);
      await garden.chooseStarterSeed(Species.tomate);
      await garden.plantSeed(ZoneType.potager, 0, Species.tomate);
      steps.addSteps(200);
      await garden.applyFertilizer(ZoneType.potager, 0, FertilizerType.basique);
      expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 200);
      expect(garden.snapshot.fertilizers[FertilizerType.basique], 0);
      await garden.applyFertilizer(ZoneType.potager, 0, FertilizerType.basique);
      expect(garden.snapshot.fertilizers[FertilizerType.basique], 0);

      steps.addSteps(3);
      await garden.refreshSteps();
      expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 203);
      await database.close();
      final reopenedDatabase = GardenDatabase(NativeDatabase(file));
      addTearDown(reopenedDatabase.close);
      final reopened = GardenSession(
        database: reopenedDatabase,
        stepProvider: steps,
      );
      await reopened.load();
      expect(reopened.snapshot.fertilizers[FertilizerType.basique], 0);
      expect(
        reopened.snapshot.zones[ZoneType.potager]![0]!.activeFertilizer,
        FertilizerType.basique,
      );
      steps.addSteps(1);
      await reopened.refreshSteps();
      expect(reopened.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 205);

      steps.addSteps(636);
      await reopened.refreshSteps();
      final mature = reopened.snapshot.zones[ZoneType.potager]![0]!;
      expect(mature.progressSteps, 1000);
      expect(mature.activeFertilizer, isNull);
      await reopened.harvestPlant(ZoneType.potager, 0);
      steps.addSteps(100);
      await reopened.refreshSteps();
      expect(reopened.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 100);
    },
  );

  test('les trois engrais conservent chacun leur multiplicateur', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final initial = GardenSnapshot.initial();
    final zones = {
      for (final entry in initial.zones.entries) entry.key: [...entry.value],
    };
    for (var slot = 0; slot < 3; slot++) {
      zones[ZoneType.potager]![slot] = const Plant(species: Species.tomate);
    }
    await database.save(
      initial.copyWith(
        zones: zones,
        fertilizers: {
          FertilizerType.basique: 1,
          FertilizerType.superEngrais: 1,
          FertilizerType.mega: 1,
        },
      ),
    );
    final steps = FakeStepProvider();
    final garden = GardenSession(database: database, stepProvider: steps);
    await garden.load();
    await garden.applyFertilizer(ZoneType.potager, 0, FertilizerType.basique);
    await garden.applyFertilizer(
      ZoneType.potager,
      0,
      FertilizerType.superEngrais,
    );
    expect(garden.snapshot.fertilizers[FertilizerType.superEngrais], 1);
    await garden.applyFertilizer(
      ZoneType.potager,
      1,
      FertilizerType.superEngrais,
    );
    await garden.applyFertilizer(ZoneType.potager, 2, FertilizerType.mega);
    steps.addSteps(4);
    await garden.refreshSteps();
    expect(
      [
        for (final plant in garden.snapshot.zones[ZoneType.potager]!.take(3))
          plant!.progressSteps,
      ],
      [5, 6, 8],
    );
  });
}
