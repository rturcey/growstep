import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_session.dart';
import 'package:growstep/garden/local_date.dart';
import 'package:growstep/garden/economy_config.dart';
import 'package:growstep/garden/economy_rules.dart';
import 'package:growstep/garden/daily_reward_id.dart';
import 'package:growstep/steps/fake_step_provider.dart';
import 'package:growstep/steps/fake_notification_scheduler.dart';

void main() {
  test('les nouveaux pas font grandir toutes les plantes présentes', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final steps = FakeStepProvider(initialSteps: 500);
    final garden = GardenSession(database: database, stepProvider: steps);
    await garden.load();

    await garden.chooseStarterSeed(Species.tomate);
    await garden.chooseStarterSeed(Species.tournesol);
    await garden.plantSeed(ZoneType.potager, 2, Species.tomate);
    await garden.plantSeed(ZoneType.jardinFleuri, 0, Species.tournesol);

    expect(garden.snapshot.zones[ZoneType.potager]![2]!.progressSteps, 0);
    expect(garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.progressSteps, 0);

    steps.addSteps(299);
    await garden.refreshSteps();
    expect(
      garden.snapshot.zones[ZoneType.potager]![2]!.stage,
      PlantStage.graineGermee,
    );
    steps.addSteps(1);
    await garden.refreshSteps();
    expect(
      garden.snapshot.zones[ZoneType.potager]![2]!.stage,
      PlantStage.jeunePlant,
    );
    expect(
      garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.progressSteps,
      300,
    );

    steps.addSteps(400);
    await garden.refreshSteps();
    expect(
      garden.snapshot.zones[ZoneType.potager]![2]!.stage,
      PlantStage.presqueMature,
    );
    steps.addSteps(300);
    await garden.refreshSteps();
    expect(
      garden.snapshot.zones[ZoneType.potager]![2]!.stage,
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
    await garden.plantSeed(ZoneType.potager, 2, Species.tomate);

    steps.setSteps(300);
    await garden.refreshSteps();
    steps.setSteps(200);
    await garden.refreshSteps();
    expect(garden.snapshot.zones[ZoneType.potager]![2]!.progressSteps, 300);

    steps.setSteps(350);
    await garden.refreshSteps();
    expect(garden.snapshot.zones[ZoneType.potager]![2]!.progressSteps, 350);
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
    await garden.plantSeed(ZoneType.potager, 2, Species.tomate);

    steps.addSteps(300);
    await garden.refreshSteps();
    await garden.plantSeed(ZoneType.jardinFleuri, 0, Species.tulipe);
    expect(garden.snapshot.zones[ZoneType.potager]![2]!.progressSteps, 300);
    expect(
      garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.progressSteps,
      0,
    );

    steps.addSteps(100);
    await garden.refreshSteps();
    expect(garden.snapshot.zones[ZoneType.potager]![2]!.progressSteps, 400);
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
      await database.save(GardenSnapshot.initial().copyWith(
        zones: {
          for (final zone in ZoneType.values)
            zone: List<Plant?>.filled(zone.initialSlots, null),
        },
      ));
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
      await database.save(GardenSnapshot.initial().copyWith(
        zones: {
          for (final zone in ZoneType.values)
            zone: List<Plant?>.filled(zone.initialSlots, null),
        },
      ));
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
      await database.save(GardenSnapshot.initial().copyWith(
        zones: {
          for (final zone in ZoneType.values)
            zone: List<Plant?>.filled(zone.initialSlots, null),
        },
      ));
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

  group('fondation — migration et types de base', () {
    test('une sauvegarde sans playerSeed génère une graine stable au chargement', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial());
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();
      expect(garden.snapshot.playerSeed, isNot(0));
      final firstSeed = garden.snapshot.playerSeed;

      final reopened = GardenDatabase(NativeDatabase.memory());
      addTearDown(reopened.close);
      await reopened.save(garden.snapshot);
      final reopenedGarden = GardenSession(
        database: reopened,
        stepProvider: FakeStepProvider(),
      );
      await reopenedGarden.load();
      expect(reopenedGarden.snapshot.playerSeed, firstSeed);
    });

    test('une nouvelle partie a une playerSeed non nulle', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();
      expect(garden.snapshot.playerSeed, isNot(0));
    });

    test('les champs de progression quotidienne sont vides au démarrage', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();
      expect(garden.snapshot.claimedDailyRewards, isEmpty);
      expect(garden.snapshot.walkFlorinsDay, isNull);
      expect(garden.snapshot.walkFlorinsClaimed, 0);
      expect(garden.snapshot.ownedDecorations, isEmpty);
      expect(garden.snapshot.placedDecorations, isEmpty);
    });

    test('LocalDate se convertit depuis DateTime et a une égalité stable', () {
      final date = LocalDate.fromDateTime(DateTime(2026, 9, 25));
      expect(date.year, 2026);
      expect(date.month, 9);
      expect(date.day, 25);
      expect(date, LocalDate(2026, 9, 25));
      expect(date, isNot(LocalDate(2026, 9, 26)));
      expect(date.toString(), '2026-09-25');
    });

    test('DailyRewardId distingue par jour et par palier', () {
      final day1 = LocalDate(2026, 9, 25);
      final day2 = LocalDate(2026, 9, 26);
      expect(
        DailyRewardId(day1, 1000),
        DailyRewardId(day1, 1000),
      );
      expect(
        DailyRewardId(day1, 1000),
        isNot(DailyRewardId(day1, 3000)),
      );
      expect(
        DailyRewardId(day1, 1000),
        isNot(DailyRewardId(day2, 1000)),
      );
    });

    test('FakeStepProvider retourne les pas d\'un jour passé', () async {
      final steps = FakeStepProvider(now: () => DateTime(2026, 9, 26, 12));
      final pastDay = LocalDate(2026, 9, 25);
      expect(await steps.stepsOnDay(pastDay), 0);
      steps.setStepsOnDay(pastDay, 5000);
      expect(await steps.stepsOnDay(pastDay), 5000);
      expect(await steps.stepsOnDay(LocalDate(2026, 9, 24)), 0);
    });

    test('EconomyConfig a les valeurs de test par défaut', () {
      final config = EconomyConfig.defaults();
      expect(config.florinsPerWalkStep, 1 / 500);
      expect(config.walkFlorinDailyCap, 30);
      expect(config.slotPrices[ZoneType.potager], [30, 45, 60, 75]);
      expect(config.slotPrices[ZoneType.verger], [30, 45]);
      expect(config.seedPrices[GrowthTier.commune], 5);
      expect(config.seedPrices[GrowthTier.peuCommune], 20);
      expect(config.seedPrices[GrowthTier.rare], 60);
      expect(config.fertilizerPrices[FertilizerType.basique], 10);
      expect(config.fertilizerPrices[FertilizerType.superEngrais], 20);
      expect(config.fertilizerPrices[FertilizerType.mega], 40);
      expect(config.harvestFlorinDailyLimit, 20);
    });

    test('EconomyRules calcule le prix d\'emplacement par zone et rang', () {
      final rules = EconomyRules(EconomyConfig.defaults());
      expect(rules.slotPrice(ZoneType.potager, 0), 30);
      expect(rules.slotPrice(ZoneType.potager, 1), 45);
      expect(rules.slotPrice(ZoneType.potager, 2), 60);
      expect(rules.slotPrice(ZoneType.potager, 3), 75);
      expect(rules.slotPrice(ZoneType.verger, 0), 30);
      expect(rules.slotPrice(ZoneType.verger, 1), 45);
      expect(() => rules.slotPrice(ZoneType.verger, 2), throwsStateError);
      expect(() => rules.slotPrice(ZoneType.potager, 4), throwsStateError);
    });
  });

  group('florins de marche', () {
    test('la marche rapporte des florins à raison de 1 pour 500 pas', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
      );
      await garden.load();

      steps.addSteps(499);
      await garden.refreshSteps();
      expect(garden.snapshot.florins, 0);

      steps.addSteps(1);
      await garden.refreshSteps();
      expect(garden.snapshot.florins, 1);
    });

    test('le plafond quotidien de florins de marche est respecté', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
      );
      await garden.load();

      steps.addSteps(500 * 30);
      await garden.refreshSteps();
      expect(garden.snapshot.walkFlorinsClaimed, 30);

      steps.addSteps(500);
      await garden.refreshSteps();
      expect(garden.snapshot.walkFlorinsClaimed, 30);
    });

    test('une relecture sans nouveau pas ne crédite rien', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
      );
      await garden.load();

      steps.addSteps(500);
      await garden.refreshSteps();
      expect(garden.snapshot.florins, 1);

      await garden.refreshSteps();
      expect(garden.snapshot.florins, 1);
    });

    test('une correction à la baisse ne retire pas les florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
      );
      await garden.load();

      steps.addSteps(1000);
      await garden.refreshSteps();
      final florinsAfterFirst = garden.snapshot.florins;

      steps.setSteps(500);
      await garden.refreshSteps();
      expect(garden.snapshot.florins, florinsAfterFirst);
    });

    test('le changement de jour réinitialise le compteur des florins de marche', () async {
      var now = DateTime(2026, 9, 25, 12);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      steps.addSteps(500);
      await garden.refreshSteps();
      expect(garden.snapshot.florins, 1);

      now = DateTime(2026, 9, 26, 12);
      steps.addSteps(500);
      await garden.refreshSteps();
      expect(garden.snapshot.florins, 2);
    });
  });

  group('achat d\'emplacements', () {
    test('le prix augmente avec chaque emplacement acheté', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 1000));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();
      await garden.buyIsland(ZoneType.jardinFleuri);

      expect(garden.snapshot.zones[ZoneType.jardinFleuri]!.length, 4);
      await garden.buySlot(ZoneType.jardinFleuri);
      expect(garden.snapshot.zones[ZoneType.jardinFleuri]!.length, 5);
      expect(garden.snapshot.florins, 1000 - 100 - 30);
    });

    test('les florins insuffisants refusent l\'achat', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 100));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();
      await garden.buyIsland(ZoneType.jardinFleuri);

      expect(() => garden.buySlot(ZoneType.jardinFleuri), throwsStateError);
      expect(garden.snapshot.zones[ZoneType.jardinFleuri]!.length, 4);
    });

    test('le verger est limité à deux achats d\'emplacements', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final initial = GardenSnapshot.initial().copyWith(
        florins: 1000,
        ownedZones: {ZoneType.potager, ZoneType.verger},
        zones: {
          ZoneType.potager: GardenSnapshot.initial().zones[ZoneType.potager]!,
          ZoneType.jardinFleuri: List<Plant?>.filled(4, null),
          ZoneType.verger: List<Plant?>.filled(1, null),
        },
      );
      await database.save(initial);
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buySlot(ZoneType.verger);
      expect(garden.snapshot.zones[ZoneType.verger]!.length, 2);
      await garden.buySlot(ZoneType.verger);
      expect(garden.snapshot.zones[ZoneType.verger]!.length, 3);
      expect(() => garden.buySlot(ZoneType.verger), throwsStateError);
    });

    test('le potager atteint le maximum à 8 emplacements', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final initial = GardenSnapshot.initial().copyWith(
        florins: 1000,
      );
      await database.save(initial);
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      for (var i = 0; i < 4; i++) {
        await garden.buySlot(ZoneType.potager);
      }
      expect(garden.snapshot.zones[ZoneType.potager]!.length, 8);
      expect(() => garden.buySlot(ZoneType.potager), throwsStateError);
    });

    test('un emplacement acheté est vide et immédiatement plantable', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 100));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();
      await garden.chooseStarterSeed(Species.tomate);
      await garden.buySlot(ZoneType.potager);

      final slot = garden.snapshot.zones[ZoneType.potager]!.last;
      expect(slot, isNull);

      await garden.plantSeed(ZoneType.potager, 4, Species.tomate);
      expect(
        garden.snapshot.zones[ZoneType.potager]![4]!.species,
        Species.tomate,
      );
    });
  });

  group('boutique graines et engrais', () {
    test('acheter une graine commune débite 5 florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 100));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buySeed(Species.tomate, GrowthTier.commune);
      expect(garden.snapshot.florins, 95);
      expect(garden.snapshot.seeds[Species.tomate], 1);
    });

    test('acheter une graine peu commune débite 20 florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 100));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buySeed(Species.tomate, GrowthTier.peuCommune);
      expect(garden.snapshot.florins, 80);
      expect(garden.snapshot.seeds[Species.tomate], 1);
    });

    test('acheter une graine rare débite 60 florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 100));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buySeed(Species.tomate, GrowthTier.rare);
      expect(garden.snapshot.florins, 40);
      expect(garden.snapshot.seeds[Species.tomate], 1);
    });

    test('acheter une graine brillante est refusé', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 100));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      expect(
        () => garden.buySeed(Species.tomate, GrowthTier.brillante),
        throwsStateError,
      );
      expect(garden.snapshot.florins, 100);
    });

    test('acheter un engrais basique débite 10 florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 100,
        starterFertilizerGranted: true,
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buyFertilizer(FertilizerType.basique);
      expect(garden.snapshot.florins, 90);
      expect(garden.snapshot.fertilizers[FertilizerType.basique], 1);
    });

    test('acheter un engrais méga débite 40 florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 100,
        starterFertilizerGranted: true,
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buyFertilizer(FertilizerType.mega);
      expect(garden.snapshot.florins, 60);
      expect(garden.snapshot.fertilizers[FertilizerType.mega], 1);
    });

    test('des florins insuffisants refusent l\'achat d\'engrais', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 5,
        starterFertilizerGranted: true,
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      expect(
        () => garden.buyFertilizer(FertilizerType.basique),
        throwsStateError,
      );
      expect(garden.snapshot.florins, 5);
    });

    test('supprimer des graines excédentaires ne donne pas de florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 50,
        seeds: {Species.tomate: 3},
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.discardSeeds(Species.tomate, count: 2);
      expect(garden.snapshot.seeds[Species.tomate], 1);
      expect(garden.snapshot.florins, 50);
    });
  });

  group('boutique et inventaire de décors', () {
    test('acheter un décor ajoute à l\'inventaire et débite les florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 200));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buyDecoration('arrosoir');
      expect(garden.snapshot.florins, 200 - 15);
      expect(garden.snapshot.ownedDecorations['arrosoir'], 1);
    });

    test('acheter deux décors du même type donne deux exemplaires', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 200));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buyDecoration('banc');
      await garden.buyDecoration('banc');
      expect(garden.snapshot.ownedDecorations['banc'], 2);
      expect(garden.snapshot.florins, 200 - 40);
    });

    test('des florins insuffisants refusent l\'achat de décor', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 5));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      expect(
        () => garden.buyDecoration('fontaine'),
        throwsStateError,
      );
      expect(garden.snapshot.ownedDecorations, isEmpty);
    });
  });

  group('placement de décors', () {
    test('placer un décor le retire de l\'inventaire et l\'ajoute au jardin', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 200,
        ownedDecorations: {'arrosoir': 1},
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      final placedId = await garden.placeDecoration(
        'arrosoir',
        ZoneType.potager,
        const Offset(80, 40),
      );
      expect(garden.snapshot.ownedDecorations['arrosoir'], 0);
      expect(garden.snapshot.placedDecorations.length, 1);
      expect(garden.snapshot.placedDecorations.first.placedId, placedId);
      expect(garden.snapshot.placedDecorations.first.zone, ZoneType.potager);
    });

    test('déplacer un décor met à jour son contact', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 200,
        ownedDecorations: {'banc': 1},
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      final placedId = await garden.placeDecoration(
        'banc',
        ZoneType.potager,
        const Offset(80, 40),
      );
      await garden.moveDecoration(placedId, ZoneType.potager, const Offset(160, 80));
      expect(garden.snapshot.placedDecorations.first.contact, const Offset(160, 80));
    });

    test('retirer un décor le remet dans l\'inventaire', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 200,
        ownedDecorations: {'tonneau': 1},
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      final placedId = await garden.placeDecoration(
        'tonneau',
        ZoneType.potager,
        const Offset(80, 40),
      );
      expect(garden.snapshot.ownedDecorations['tonneau'], 0);
      await garden.removeDecoration(placedId);
      expect(garden.snapshot.placedDecorations, isEmpty);
      expect(garden.snapshot.ownedDecorations['tonneau'], 1);
    });

    test('le placement survit au redémarrage', () async {
      final directory = await Directory.systemTemp.createTemp('growstep-decor-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 200,
        ownedDecorations: {'arrosoir': 1},
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();
      await garden.placeDecoration(
        'arrosoir',
        ZoneType.potager,
        const Offset(80, 40),
      );
      await database.close();

      final reopenedDatabase = GardenDatabase(NativeDatabase(file));
      addTearDown(reopenedDatabase.close);
      final reopened = GardenSession(
        database: reopenedDatabase,
        stepProvider: FakeStepProvider(),
      );
      await reopened.load();
      expect(reopened.snapshot.placedDecorations.length, 1);
      expect(
        reopened.snapshot.placedDecorations.first.decorationId,
        'arrosoir',
      );
    });

    test('un contact hors grille est refusé', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 200,
        ownedDecorations: {'arrosoir': 1},
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      expect(
        () => garden.placeDecoration(
          'arrosoir',
          ZoneType.potager,
          const Offset(81, 41),
        ),
        throwsStateError,
      );
      expect(garden.snapshot.ownedDecorations['arrosoir'], 1);
    });

    test('deux décors qui se chevauchent sont refusés', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(
        florins: 200,
        ownedDecorations: {'arrosoir': 2},
      ));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.placeDecoration(
        'arrosoir',
        ZoneType.potager,
        const Offset(80, 40),
      );
      expect(
        () => garden.placeDecoration(
          'arrosoir',
          ZoneType.potager,
          const Offset(80, 40),
        ),
        throwsStateError,
      );
      expect(garden.snapshot.ownedDecorations['arrosoir'], 1);
    });
  });

  group('paliers quotidiens et lots', () {
    test('les lots sont déterministes pour un même joueur et un même jour', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      var now = DateTime(2026, 9, 25, 12);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();
      final playerSeed = garden.snapshot.playerSeed;

      final day = LocalDate(2026, 9, 25);
      final lots1 = garden.previewDailyLots(day);
      steps.addSteps(1000);
      await garden.refreshSteps();

      final database2 = GardenDatabase(NativeDatabase.memory());
      addTearDown(database2.close);
      final garden2 = GardenSession(
        database: database2,
        stepProvider: FakeStepProvider(now: () => now),
        now: () => now,
      );
      await database2.save(garden.snapshot);
      await garden2.load();
      final lots2 = garden2.previewDailyLots(day);

      expect(garden2.snapshot.playerSeed, playerSeed);
      expect(lots2.map((l) => l.threshold).toList(),
          lots1.map((l) => l.threshold).toList());
    });

    test('999 pas ne déclenche pas le premier palier', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
      );
      await garden.load();

      steps.addSteps(999);
      await garden.refreshSteps();
      expect(garden.snapshot.claimedDailyRewards, isEmpty);
    });

    test('1000 pas déclenche le premier palier', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
      );
      await garden.load();

      steps.addSteps(1000);
      await garden.refreshSteps();
      final today = LocalDate.fromDateTime(DateTime.now());
      expect(
        garden.snapshot.claimedDailyRewards,
        contains(DailyRewardId(today, 1000)),
      );
    });

    test('10000 pas déclenche les quatre paliers', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
      );
      await garden.load();

      steps.addSteps(10000);
      await garden.refreshSteps();
      final today = LocalDate.fromDateTime(DateTime.now());
      for (final threshold in [1000, 3000, 6000, 10000]) {
        expect(
          garden.snapshot.claimedDailyRewards,
          contains(DailyRewardId(today, threshold)),
        );
      }
    });

    test('une relecture ne crédite pas deux fois le même palier', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
      );
      await garden.load();

      steps.addSteps(1000);
      await garden.refreshSteps();
      final florinsAfterFirst = garden.snapshot.florins;
      await garden.refreshSteps();
      expect(garden.snapshot.florins, florinsAfterFirst);
    });

    test('une correction à la baisse ne retire pas un palier déjà crédité', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
      );
      await garden.load();

      steps.addSteps(3000);
      await garden.refreshSteps();
      final claimedAfterFirst = Set<DailyRewardId>.from(
        garden.snapshot.claimedDailyRewards,
      );

      steps.setSteps(500);
      await garden.refreshSteps();
      expect(
        garden.snapshot.claimedDailyRewards.length,
        claimedAfterFirst.length,
      );
      for (final id in claimedAfterFirst) {
        expect(garden.snapshot.claimedDailyRewards, contains(id));
      }
    });

    test('le changement de jour réinitialise les paliers', () async {
      var now = DateTime(2026, 9, 25, 12);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      steps.addSteps(1000);
      await garden.refreshSteps();
      final day1Count = garden.snapshot.claimedDailyRewards.length;
      expect(day1Count, 1);

      now = DateTime(2026, 9, 26, 12);
      steps.addSteps(1000);
      await garden.refreshSteps();
      final day2 = LocalDate(2026, 9, 26);
      expect(
        garden.snapshot.claimedDailyRewards,
        contains(DailyRewardId(day2, 1000)),
      );
    });
  });

  group('crédit tardif des pas', () {
    test('les pas d\'un jour passé créditent les paliers manquants', () async {
      var now = DateTime(2026, 9, 26, 12);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      final pastDay = LocalDate(2026, 9, 25);
      steps.setStepsOnDay(pastDay, 3000);
      await garden.applyLateSteps(pastDay);

      expect(
        garden.snapshot.claimedDailyRewards,
        contains(DailyRewardId(pastDay, 1000)),
      );
      expect(
        garden.snapshot.claimedDailyRewards,
        contains(DailyRewardId(pastDay, 3000)),
      );
    });

    test('un re-crédit du même jour ne crédite rien de nouveau', () async {
      var now = DateTime(2026, 9, 26, 12);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      final pastDay = LocalDate(2026, 9, 25);
      steps.setStepsOnDay(pastDay, 1000);
      await garden.applyLateSteps(pastDay);
      final claimedAfterFirst = garden.snapshot.claimedDailyRewards.length;
      final florinsAfterFirst = garden.snapshot.florins;

      await garden.applyLateSteps(pastDay);
      expect(garden.snapshot.claimedDailyRewards.length, claimedAfterFirst);
      expect(garden.snapshot.florins, florinsAfterFirst);
    });

    test('une correction à la baisse ne retire pas un palier déjà crédité', () async {
      var now = DateTime(2026, 9, 26, 12);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      final pastDay = LocalDate(2026, 9, 25);
      steps.setStepsOnDay(pastDay, 3000);
      await garden.applyLateSteps(pastDay);
      final claimedAfterFirst = Set<DailyRewardId>.from(
        garden.snapshot.claimedDailyRewards,
      );

      steps.setStepsOnDay(pastDay, 500);
      await garden.applyLateSteps(pastDay);
      for (final id in claimedAfterFirst) {
        expect(garden.snapshot.claimedDailyRewards, contains(id));
      }
    });

    test('DailyRewardId distingue par jour et par palier', () async {
      var now = DateTime(2026, 9, 27, 12);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      final day1 = LocalDate(2026, 9, 25);
      final day2 = LocalDate(2026, 9, 26);
      steps.setStepsOnDay(day1, 1000);
      steps.setStepsOnDay(day2, 1000);
      await garden.applyLateSteps(day1);
      await garden.applyLateSteps(day2);

      expect(
        garden.snapshot.claimedDailyRewards,
        contains(DailyRewardId(day1, 1000)),
      );
      expect(
        garden.snapshot.claimedDailyRewards,
        contains(DailyRewardId(day2, 1000)),
      );
      expect(garden.snapshot.claimedDailyRewards.length, 2);
    });

    test('les pas tardifs créditent aussi les florins de marche manqués', () async {
      var now = DateTime(2026, 9, 26, 12);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      final pastDay = LocalDate(2026, 9, 25);
      steps.setStepsOnDay(pastDay, 500);
      final florinsBefore = garden.snapshot.florins;
      await garden.applyLateSteps(pastDay);
      expect(garden.snapshot.florins, florinsBefore + 1);
      expect(garden.snapshot.walkFlorinsDay, pastDay.toIsoString());
      expect(garden.snapshot.walkFlorinsClaimed, 1);
    });

    test('un re-crédit tardif des florins de marche ne double pas', () async {
      var now = DateTime(2026, 9, 26, 12);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      final pastDay = LocalDate(2026, 9, 25);
      steps.setStepsOnDay(pastDay, 500);
      await garden.applyLateSteps(pastDay);
      final florinsAfterFirst = garden.snapshot.florins;

      await garden.applyLateSteps(pastDay);
      expect(garden.snapshot.florins, florinsAfterFirst);
    });
  });

  group('pauses marche', () {
    test('une pause réussie donne un engrais basique', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await database.save(GardenSnapshot.initial().copyWith(
        starterFertilizerGranted: true,
        fertilizers: {},
      ));
      await garden.load();

      final start = now;
      await garden.startPause();
      now = start.add(const Duration(minutes: 10));
      steps.setStepsBetween(start, now, 300);
      await garden.checkActivePause();

      expect(garden.snapshot.fertilizers[FertilizerType.basique], 1);
      expect(garden.snapshot.pauseRewardsCount, 1);
    });

    test('299 pas en 10 minutes ne réussit pas la pause', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await database.save(GardenSnapshot.initial().copyWith(
        starterFertilizerGranted: true,
        fertilizers: {},
      ));
      await garden.load();

      final start = now;
      await garden.startPause();
      now = start.add(const Duration(minutes: 10));
      steps.setStepsBetween(start, now, 299);
      await garden.checkActivePause();

      expect(garden.snapshot.fertilizers[FertilizerType.basique], isNull);
      expect(garden.snapshot.pauseRewardsCount, 0);
    });

    test('au plus trois récompenses par jour', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await database.save(GardenSnapshot.initial().copyWith(
        starterFertilizerGranted: true,
        fertilizers: {},
      ));
      await garden.load();

      for (var i = 0; i < 3; i++) {
        final start = now;
        await garden.startPause();
        now = start.add(const Duration(minutes: 10));
        steps.setStepsBetween(start, now, 300);
        await garden.checkActivePause();
      }
      expect(garden.snapshot.pauseRewardsCount, 3);
      expect(garden.snapshot.fertilizers[FertilizerType.basique], 3);

      final start = now;
      await garden.startPause();
      now = start.add(const Duration(minutes: 10));
      steps.setStepsBetween(start, now, 300);
      await garden.checkActivePause();
      expect(garden.snapshot.pauseRewardsCount, 3);
      expect(garden.snapshot.fertilizers[FertilizerType.basique], 3);
    });

    test('une pause reste possible après le troisième bonus', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await database.save(GardenSnapshot.initial().copyWith(
        starterFertilizerGranted: true,
        fertilizers: {},
        pauseRewardsCount: 3,
      ));
      await garden.load();

      await garden.startPause();
      expect(garden.snapshot.activePause, isNotNull);
    });

    test('abandonner une pause ne donne ni récompense ni malus', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await database.save(GardenSnapshot.initial().copyWith(
        starterFertilizerGranted: true,
        fertilizers: {},
      ));
      await garden.load();

      await garden.startPause();
      await garden.cancelPause();
      expect(garden.snapshot.activePause, isNull);
      expect(garden.snapshot.fertilizers[FertilizerType.basique], isNull);
    });

    test('une pause évaluée à la reprise ne double pas la récompense', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      final start = now;
      await garden.startPause();
      now = start.add(const Duration(minutes: 15));
      steps.setStepsBetween(start, start.add(const Duration(minutes: 10)), 300);
      await garden.checkActivePause();
      final fertilizersAfterFirst = garden.snapshot.fertilizers[FertilizerType.basique];

      await garden.checkActivePause();
      expect(
        garden.snapshot.fertilizers[FertilizerType.basique],
        fertilizersAfterFirst,
      );
    });

    test('le changement de jour réinitialise le compteur de pauses', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();
      await database.save(garden.snapshot.copyWith(
        starterFertilizerGranted: true,
        fertilizers: {},
        pauseRewardsCount: 3,
      ));

      now = DateTime(2026, 9, 27, 10);
      final start = now;
      await garden.startPause();
      now = start.add(const Duration(minutes: 10));
      steps.setStepsBetween(start, now, 300);
      await garden.checkActivePause();
      expect(garden.snapshot.pauseRewardsCount, 1);
    });
  });

  group('inactivité', () {
    test('300 pas détectés remettent le compteur d\'inactivité à zéro', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      final earlier = now.subtract(const Duration(minutes: 30));
      await database.save(GardenSnapshot.initial().copyWith(
        starterFertilizerGranted: true,
        lastActivityTime: earlier.toIso8601String(),
      ));
      await garden.load();

      steps.addSteps(300);
      await garden.refreshSteps();
      expect(
        garden.snapshot.lastActivityTime,
        isNot(earlier.toIso8601String()),
      );
    });

    test('lancer une pause ne remet pas le compteur à zéro', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      final earlier = now.subtract(const Duration(minutes: 30));
      await database.save(GardenSnapshot.initial().copyWith(
        starterFertilizerGranted: true,
        lastActivityTime: earlier.toIso8601String(),
      ));
      await garden.load();

      await garden.startPause();
      expect(
        garden.snapshot.lastActivityTime,
        earlier.toIso8601String(),
      );
    });

    test('60 minutes d\'inactivité déclenche une proposition', () async {
      var now = DateTime(2026, 9, 26, 11);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final notifications = FakeNotificationScheduler();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
        notificationScheduler: notifications,
      );
      final lastActivity = now.subtract(const Duration(minutes: 61));
      await database.save(GardenSnapshot.initial().copyWith(
        lastActivityTime: lastActivity.toIso8601String(),
        starterFertilizerGranted: true,
      ));
      await garden.load();

      garden.evaluateInactivity();

      expect(notifications.scheduled, anyElement(isA<ProposeWalkIntent>()));
    });

    test('90 minutes d\'inactivité déclenche un rappel', () async {
      var now = DateTime(2026, 9, 26, 11, 31);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final notifications = FakeNotificationScheduler();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
        notificationScheduler: notifications,
      );
      final lastActivity = now.subtract(const Duration(minutes: 91));
      await database.save(GardenSnapshot.initial().copyWith(
        lastActivityTime: lastActivity.toIso8601String(),
        starterFertilizerGranted: true,
      ));
      await garden.load();

      garden.evaluateInactivity();

      expect(notifications.scheduled, anyElement(isA<ReminderWalkIntent>()));
    });

    test('moins de 60 minutes d\'inactivité ne déclenche rien', () async {
      var now = DateTime(2026, 9, 26, 10, 30);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final notifications = FakeNotificationScheduler();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
        notificationScheduler: notifications,
      );
      final lastActivity = now.subtract(const Duration(minutes: 45));
      await database.save(GardenSnapshot.initial().copyWith(
        lastActivityTime: lastActivity.toIso8601String(),
        starterFertilizerGranted: true,
      ));
      await garden.load();

      garden.evaluateInactivity();

      expect(notifications.scheduled, isEmpty);
    });
  });

  group('invitations à heures choisies', () {
    test('les heures d\'invitation se règlent et persistent', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.setInvitationHours([9, 14, 18]);
      expect(garden.snapshot.invitationHours, [9, 14, 18]);

      final reopened = GardenDatabase(NativeDatabase.memory());
      addTearDown(reopened.close);
      await reopened.save(garden.snapshot);
      final reopenedGarden = GardenSession(
        database: reopened,
        stepProvider: FakeStepProvider(),
      );
      await reopenedGarden.load();
      expect(reopenedGarden.snapshot.invitationHours, [9, 14, 18]);
    });

    test('une invitation à heure choisie produit une intention de notification', () async {
      var now = DateTime(2026, 9, 26, 9, 5);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final notifications = FakeNotificationScheduler();
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(now: () => now),
        now: () => now,
        notificationScheduler: notifications,
      );
      await garden.load();
      await garden.setInvitationHours([9]);

      garden.evaluateScheduledInvitations();

      expect(
        notifications.scheduled,
        anyElement(isA<InvitationWalkIntent>()),
      );
    });

    test('une invitation est supprimée si 300 pas ont été détectés récemment', () async {
      var now = DateTime(2026, 9, 26, 9, 5);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final notifications = FakeNotificationScheduler();
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
        notificationScheduler: notifications,
      );
      await garden.load();
      await garden.setInvitationHours([9]);

      steps.addSteps(300);
      await garden.refreshSteps();
      notifications.clear();
      garden.evaluateScheduledInvitations();

      expect(notifications.scheduled, isEmpty);
      expect(notifications.cancelled, isNotEmpty);
    });

    test('le refus des notifications n\'empêche pas les pauses manuelles', () async {
      var now = DateTime(2026, 9, 26, 10);
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(now: () => now);
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        now: () => now,
      );
      await garden.load();

      await garden.startPause();
      expect(garden.snapshot.activePause, isNotNull);
    });
  });
}
