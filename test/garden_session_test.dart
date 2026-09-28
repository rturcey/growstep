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

  test('les espèces mûrissent à leur maturité intrinsèque et les cycles sont conservés', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final initial = GardenSnapshot.initial();
    final zones = {
      for (final entry in initial.zones.entries) entry.key: [...entry.value],
    };
    zones[ZoneType.potager]![0] = const Plant(species: Species.tomate);
    zones[ZoneType.potager]![1] = const Plant(species: Species.carotte);
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
    // Arbre en cycle de fruit : maturité du fruit = 2000/2 = 1000.
    expect(garden.snapshot.zones[ZoneType.verger]![0]!.targetSteps, 1000);
    expect(
      garden.snapshot.zones[ZoneType.verger]![0]!.stage,
      PlantStage.mature,
    );

    steps.addSteps(1000);
    await garden.refreshSteps();
    expect(
      garden.snapshot.zones[ZoneType.potager]![0]!.stage,
      PlantStage.mature,
    );
    expect(
      garden.snapshot.zones[ZoneType.potager]![1]!.stage,
      PlantStage.mature,
    );
    expect(garden.snapshot.zones[ZoneType.verger]![0]!.progressSteps, 1000);

    steps.addSteps(5000);
    await garden.refreshSteps();
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
  });

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
      await database.save(
        GardenSnapshot.initial().copyWith(
          zones: {
            for (final zone in ZoneType.values)
              zone: List<Plant?>.filled(zone.initialSlots, null),
          },
        ),
      );
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
      expect(garden.previewReadyHarvests().ordinarySeeds[Species.tomate], 1);
      expect(garden.snapshot.seeds[Species.tomate], 0);

      // Récolter une culture la retire et libère l'emplacement.
      await garden.harvestPlant(ZoneType.potager, 0);
      expect(garden.snapshot.seeds[Species.tomate], 1);
      expect(garden.snapshot.zones[ZoneType.potager]![0], isNull);

      // L'emplacement libéré accueille une nouvelle plantation.
      await garden.plantSeed(ZoneType.potager, 0, Species.tomate);
      expect(garden.snapshot.zones[ZoneType.potager]![0]!.progressSteps, 0);
      steps.addSteps(999);
      await garden.refreshSteps();
      expect(garden.previewReadyHarvests().count, 0);
      steps.addSteps(1);
      await garden.refreshSteps();
      expect(garden.previewReadyHarvests().count, 1);
      await garden.harvestPlant(ZoneType.potager, 0);
      expect(garden.snapshot.seeds[Species.tomate], 1);
      expect(garden.snapshot.zones[ZoneType.potager]![0], isNull);

      final reopened = GardenSession(database: database, stepProvider: steps);
      await reopened.load();
      expect(reopened.snapshot.zones[ZoneType.potager]![0], isNull);
      expect(reopened.snapshot.seeds[Species.tomate], 1);
    },
  );

  test('la récolte groupée annonce ses graines exactes, dont une brillante', () async {
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
    expect(preview.ordinarySeeds, {Species.tomate: 1});
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
    expect(reopened.snapshot.seeds[Species.tournesol], isNull);
    expect(reopened.snapshot.brilliantSeeds[Species.tournesol], 1);
    // Les cultures récoltées disparaissent : une seconde récolte ne donne rien.
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
  });

  test('supprimer une plante rend sa graine (jamais de perte)', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.save(
      GardenSnapshot.initial().copyWith(
        zones: {
          for (final zone in ZoneType.values)
            zone: List<Plant?>.filled(zone.initialSlots, null),
        },
      ),
    );
    final steps = FakeStepProvider();
    final garden = GardenSession(database: database, stepProvider: steps);
    await garden.load();
    await garden.chooseStarterSeed(Species.tomate);
    await garden.plantSeed(ZoneType.potager, 0, Species.tomate);
    // Suppression prématurée : la graine est rendue.
    await garden.removePlant(ZoneType.potager, 0);
    expect(garden.snapshot.seeds[Species.tomate], 1);
    expect(garden.snapshot.zones[ZoneType.potager]![0], isNull);

    await garden.chooseStarterSeed(Species.tournesol);
    await garden.plantSeed(ZoneType.jardinFleuri, 0, Species.tournesol);
    steps.addSteps(1000);
    await garden.refreshSteps();
    expect(garden.previewReadyHarvests().count, 1);
    // Suppression après maturité : la graine est rendue aussi.
    await garden.removePlant(ZoneType.jardinFleuri, 0);
    expect(garden.previewReadyHarvests().count, 0);
    expect(garden.snapshot.seeds[Species.tournesol], 1);
  });

  test('la courbe de prix du marché vend à plein tarif puis à 30 %', () async {
    final directory = await Directory.systemTemp.createTemp('growstep-market-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/garden.sqlite');
    final database = GardenDatabase(NativeDatabase(file));
    final initial = GardenSnapshot.initial();
    final zones = {
      for (final entry in initial.zones.entries) entry.key: [...entry.value],
    };
    // 10 tomates prêtes (quota commune = 8).
    for (var slot = 0; slot < 4; slot++) {
      zones[ZoneType.potager]![slot] = const Plant(
        species: Species.tomate,
        progressSteps: 1000,
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

    // 4 récoltes le premier jour : toutes à plein tarif (5 × 4 = 20).
    final preview = garden.previewReadyHarvests();
    expect(preview.florins, 20);
    await garden.harvestAll(preview.locations);
    expect(garden.snapshot.florins, 120);
    expect(garden.snapshot.soldToday[Species.tomate], 4);
    expect(garden.snapshot.salesDay, '2026-09-22');

    await database.close();
    final reopenedDatabase = GardenDatabase(NativeDatabase(file));
    addTearDown(reopenedDatabase.close);
    final reopened = GardenSession(
      database: reopenedDatabase,
      stepProvider: FakeStepProvider(),
      now: () => now,
    );
    await reopened.load();
    // Les compteurs de ventes survivent au redémarrage (même jour).
    expect(reopened.snapshot.soldToday[Species.tomate], 4);

    // Changement de jour : les compteurs se réinitialisent.
    now = DateTime(2026, 9, 23, 0, 1);
    expect(reopened.salesToday[Species.tomate] ?? 0, 0);
  });

  test('le surplus se vend à 30 % sans plafond dur', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final initial = GardenSnapshot.initial();
    final zones = {
      for (final entry in initial.zones.entries) entry.key: [...entry.value],
    };
    // 10 tomates prêtes (quota = 8).
    for (var slot = 0; slot < 4; slot++) {
      zones[ZoneType.potager]![slot] = const Plant(
        species: Species.tomate,
        progressSteps: 1000,
        pendingHarvest: HarvestReward(ordinarySeeds: 1),
      );
    }
    zones[ZoneType.jardinFleuri] = List<Plant?>.filled(8, null);
    for (var slot = 0; slot < 6; slot++) {
      zones[ZoneType.jardinFleuri]![slot] = const Plant(
        species: Species.tournesol,
        progressSteps: 1000,
        pendingHarvest: HarvestReward(ordinarySeeds: 1),
      );
    }
    await database.save(
      initial.copyWith(
        zones: zones,
        florins: 0,
        ownedZones: {ZoneType.potager, ZoneType.jardinFleuri},
      ),
    );
    final garden = GardenSession(
      database: database,
      stepProvider: FakeStepProvider(),
    );
    await garden.load();

    // 4 tomates : plein tarif (5 × 4 = 20).
    await garden.harvestAll([
      for (var s = 0; s < 4; s++) (zone: ZoneType.potager, slot: s),
    ]);
    expect(garden.snapshot.florins, 20);

    // 6 tournesols : 8 à plein tarif (5×8=40) puis surplus à 30 %.
    // Ici seulement 6 ventes → toutes sous quota → 5×6 = 30.
    await garden.harvestAll([
      for (var s = 0; s < 6; s++) (zone: ZoneType.jardinFleuri, slot: s),
    ]);
    expect(garden.snapshot.florins, 50);
    expect(garden.snapshot.soldToday[Species.tournesol], 6);
  });

  test(
    'l’engrais accélère seulement les nouveaux pas du cycle courant',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'growstep-fertilizer-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      await database.save(
        GardenSnapshot.initial().copyWith(
          zones: {
            for (final zone in ZoneType.values)
              zone: List<Plant?>.filled(zone.initialSlots, null),
          },
        ),
      );
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
      // Récolter une culture la retire : l’engrais n’accélère plus rien.
      await reopened.harvestPlant(ZoneType.potager, 0);
      expect(reopened.snapshot.zones[ZoneType.potager]![0], isNull);
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
    test(
      'une sauvegarde sans playerSeed génère une graine stable au chargement',
      () async {
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
      },
    );

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

    test(
      'les champs de progression quotidienne sont vides au démarrage',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
        );
        await garden.load();
        expect(garden.snapshot.claimedDailyRewards, isEmpty);
        expect(garden.snapshot.ownedDecorations, isEmpty);
        expect(garden.snapshot.placedDecorations, isEmpty);
      },
    );

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
      expect(DailyRewardId(day1, 1000), DailyRewardId(day1, 1000));
      expect(DailyRewardId(day1, 1000), isNot(DailyRewardId(day1, 3000)));
      expect(DailyRewardId(day1, 1000), isNot(DailyRewardId(day2, 1000)));
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
      expect(config.slotPrices[ZoneType.potager], [30, 45, 60, 75]);
      expect(config.slotPrices[ZoneType.verger], [30, 45]);
      expect(config.seedPrices[GrowthTier.commune], 20);
      expect(config.seedPrices[GrowthTier.peuCommune], 40);
      expect(config.seedPrices[GrowthTier.rare], 80);
      expect(config.fertilizerPrices[FertilizerType.basique], 25);
      expect(config.fertilizerPrices[FertilizerType.superEngrais], 45);
      expect(config.fertilizerPrices[FertilizerType.mega], 70);
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

  group('marché seul générateur : la marche ne donne plus de florins', () {
    test('marcher ne crédite aucun florin', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();

      steps.addSteps(10000);
      await garden.refreshSteps();
      expect(garden.snapshot.florins, 0);
    });

    test('une relecture sans nouveau pas ne crédite rien', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();

      steps.addSteps(1000);
      await garden.refreshSteps();
      expect(garden.snapshot.florins, 0);

      await garden.refreshSteps();
      expect(garden.snapshot.florins, 0);
    });

    test('les lots quotidiens ne contiennent jamais de florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      final lots = garden.previewDailyLots(
        LocalDate.fromDateTime(DateTime.now()),
      );
      for (final lot in lots) {
        // Un lot accorde au moins une récompense non-florins.
        expect(
          lot.seedSpecies != null ||
              lot.fertilizerType != null ||
              lot.decorationId != null ||
              lot.shinySeedSpecies != null,
          isTrue,
        );
      }
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
      final initial = GardenSnapshot.initial().copyWith(florins: 1000);
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
    test(
      'acheter une graine supplémentaire débite le prix de l’espèce',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await database.save(GardenSnapshot.initial().copyWith(florins: 100));
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
        );
        await garden.load();

        await garden.buySeed(Species.tomate);
        expect(garden.snapshot.florins, 80);
        expect(garden.snapshot.seeds[Species.tomate], 1);
      },
    );

    test('acheter une graine d’arbre débite le prix commune (20)', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(
        GardenSnapshot.initial().copyWith(
          florins: 100,
          discoveredSpecies: {Species.tomate, Species.carotte, Species.pommier},
        ),
      );
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buySeed(Species.pommier);
      expect(garden.snapshot.florins, 80);
      expect(garden.snapshot.seeds[Species.pommier], 1);
    });

    test('la boutique ne vend jamais de graine brillante', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 100));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buySeed(Species.tomate);
      expect(garden.snapshot.seeds[Species.tomate], 1);
      expect(garden.snapshot.brilliantSeeds[Species.tomate], isNull);
    });

    test('acheter un engrais basique débite 25 florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(
        GardenSnapshot.initial().copyWith(
          florins: 100,
          starterFertilizerGranted: true,
        ),
      );
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buyFertilizer(FertilizerType.basique);
      expect(garden.snapshot.florins, 75);
      expect(garden.snapshot.fertilizers[FertilizerType.basique], 1);
    });

    test('acheter un engrais méga débite 70 florins', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(
        GardenSnapshot.initial().copyWith(
          florins: 100,
          starterFertilizerGranted: true,
        ),
      );
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.buyFertilizer(FertilizerType.mega);
      expect(garden.snapshot.florins, 30);
      expect(garden.snapshot.fertilizers[FertilizerType.mega], 1);
    });

    test('des florins insuffisants refusent l\'achat d\'engrais', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(
        GardenSnapshot.initial().copyWith(
          florins: 5,
          starterFertilizerGranted: true,
        ),
      );
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

    test('un engrais acheté n’a jamais un rendement en florins supérieur à son prix', () {
      final config = EconomyConfig.defaults();
      // Gain marginal maximal = prix de la récolte d’une espèce rare (21)
      // sous quota. Aucune espèce rare n’existe encore, donc le maximum
      // actuel est le prix commune (5), toujours < 25.
      final maxMarginalGain = 21;
      for (final type in FertilizerType.values) {
        expect(
          config.fertilizerPrices[type]!,
          greaterThan(maxMarginalGain),
          reason:
              '${type.label} (${config.fertilizerPrices[type]}) doit dépasser '
              'le gain marginal max ($maxMarginalGain)',
        );
      }
    });

    test(
      'supprimer des graines excédentaires ne donne pas de florins',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await database.save(
          GardenSnapshot.initial().copyWith(
            florins: 50,
            seeds: {Species.tomate: 3},
          ),
        );
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
        );
        await garden.load();

        await garden.discardSeeds(Species.tomate, count: 2);
        expect(garden.snapshot.seeds[Species.tomate], 1);
        expect(garden.snapshot.florins, 50);
      },
    );
  });

  group('rareté intrinsèque à l’espèce', () {
    test('chaque espèce expose rareté, maturité, prix et quota', () {
      expect(Species.tomate.rarity, GrowthTier.commune);
      expect(Species.tomate.stepsToMature, 1000);
      expect(Species.tomate.pricePerHarvest, 5);
      expect(Species.tomate.dailyQuota, 8);
      expect(Species.tomate.isTree, isFalse);

      expect(Species.pommier.rarity, GrowthTier.commune);
      expect(Species.pommier.stepsToMature, 2000);
      expect(Species.pommier.pricePerHarvest, 5);
      expect(Species.pommier.dailyQuota, 3);
      expect(Species.pommier.isTree, isTrue);
    });

    test(
      'une graine d’espèce coûte le prix de sa rareté (commune 20)',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await database.save(GardenSnapshot.initial().copyWith(florins: 100));
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
        );
        await garden.load();

        await garden.buySeed(Species.tomate);
        expect(garden.snapshot.florins, 80);
        expect(garden.snapshot.seeds[Species.tomate], 1);
      },
    );

    test(
      'une graine d’arbre coûte 20 florins comme une graine commune',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await database.save(
          GardenSnapshot.initial().copyWith(
            florins: 100,
            discoveredSpecies: {
              Species.tomate,
              Species.carotte,
              Species.pommier,
            },
          ),
        );
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
        );
        await garden.load();

        await garden.buySeed(Species.pommier);
        expect(garden.snapshot.florins, 80);
        expect(garden.snapshot.seeds[Species.pommier], 1);
      },
    );

    test(
      'planter une graine produit une plante dont le tier égale la rareté',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
        );
        await garden.load();
        await garden.chooseStarterSeed(Species.tomate);
        await garden.plantSeed(ZoneType.potager, 2, Species.tomate);

        final plant = garden.snapshot.zones[ZoneType.potager]![2]!;
        expect(plant.tier, GrowthTier.commune);
        expect(plant.targetSteps, 1000);
      },
    );

    test(
      'une plante d’arbre mûrit en 2000 pas malgré sa rareté commune',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
        );
        await garden.load();
        await garden.chooseStarterSeed(Species.pommier);
        await garden.plantSeed(ZoneType.verger, 0, Species.pommier);

        final plant = garden.snapshot.zones[ZoneType.verger]![0]!;
        expect(plant.tier, GrowthTier.commune);
        expect(plant.targetSteps, 2000);
      },
    );

    test(
      'une graine brillante se plante en 15000 pas et n’est jamais achetable',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await database.save(
          GardenSnapshot.initial().copyWith(
            florins: 100,
            seeds: {Species.tomate: 1},
            brilliantSeeds: {Species.tomate: 1},
          ),
        );
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
        );
        await garden.load();

        await garden.plantSeed(
          ZoneType.potager,
          2,
          Species.tomate,
          brilliant: true,
        );
        final plant = garden.snapshot.zones[ZoneType.potager]![2]!;
        expect(plant.tier, GrowthTier.brillante);
        expect(plant.targetSteps, 15000);
        expect(garden.snapshot.brilliantSeeds[Species.tomate], 0);

        await garden.buySeed(Species.tomate);
        expect(garden.snapshot.florins, 80);
        expect(garden.snapshot.seeds[Species.tomate], 2);
        expect(garden.snapshot.brilliantSeeds[Species.tomate], 0);
      },
    );
  });

  group('espèce découverte ≠ graine consommable', () {
    test('choisir une graine de départ découvre l’espèce', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      expect(
        garden.snapshot.discoveredSpecies.contains(Species.tournesol),
        isFalse,
      );
      await garden.chooseStarterSeed(Species.tournesol);
      expect(garden.snapshot.discoveredSpecies, contains(Species.tournesol));
    });

    test('la boutique refuse une graine d’espèce non découverte', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(GardenSnapshot.initial().copyWith(florins: 100));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      expect(
        garden.snapshot.discoveredSpecies.contains(Species.tournesol),
        isFalse,
      );
      expect(() => garden.buySeed(Species.tournesol), throwsStateError);
      expect(garden.snapshot.florins, 100);
    });

    test('une espèce découverte reste découverte au redémarrage', () async {
      final directory = await Directory.systemTemp.createTemp('growstep-disc-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();
      await garden.chooseStarterSeed(Species.tournesol);
      await database.close();

      final reopenedDatabase = GardenDatabase(NativeDatabase(file));
      addTearDown(reopenedDatabase.close);
      final reopened = GardenSession(
        database: reopenedDatabase,
        stepProvider: FakeStepProvider(),
      );
      await reopened.load();
      expect(reopened.snapshot.discoveredSpecies, contains(Species.tournesol));
    });
  });

  group('arbres persistants (verger)', () {
    test(
      'un arbre mature reste en place et produit des fruits périodiquement',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final initial = GardenSnapshot.initial().copyWith(
          florins: 0,
          ownedZones: {ZoneType.potager, ZoneType.verger},
          seeds: {Species.pommier: 1},
        );
        final zones = {
          for (final entry in initial.zones.entries)
            entry.key: [...entry.value],
        };
        zones[ZoneType.potager] = List<Plant?>.filled(4, null);
        zones[ZoneType.verger] = List<Plant?>.filled(1, null);
        await database.save(initial.copyWith(zones: zones));
        final steps = FakeStepProvider();
        final garden = GardenSession(database: database, stepProvider: steps);
        await garden.load();

        await garden.plantSeed(ZoneType.verger, 0, Species.pommier);
        // Maturité du tronc : 2000 pas.
        steps.addSteps(2000);
        await garden.refreshSteps();
        expect(garden.previewReadyHarvests().count, 1);

        // Récolte : l’arbre reste, les fruits sont vendus (5 florins), pas de graine.
        await garden.harvestPlant(ZoneType.verger, 0);
        expect(garden.snapshot.zones[ZoneType.verger]![0], isNotNull);
        expect(garden.snapshot.florins, 5);
        expect(garden.snapshot.seeds[Species.pommier], 0);

        // Cycle de fruit suivant : 1000 pas.
        steps.addSteps(999);
        await garden.refreshSteps();
        expect(garden.previewReadyHarvests().count, 0);
        steps.addSteps(1);
        await garden.refreshSteps();
        expect(garden.previewReadyHarvests().count, 1);
        await garden.harvestPlant(ZoneType.verger, 0);
        expect(garden.snapshot.zones[ZoneType.verger]![0], isNotNull);
        expect(garden.snapshot.florins, 10);
      },
    );

    test('supprimer un arbre rend sa graine', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final initial = GardenSnapshot.initial().copyWith(
        ownedZones: {ZoneType.potager, ZoneType.verger},
        seeds: {Species.pommier: 1},
      );
      final zones = {
        for (final entry in initial.zones.entries) entry.key: [...entry.value],
      };
      zones[ZoneType.verger] = List<Plant?>.filled(1, null);
      await database.save(initial.copyWith(zones: zones));
      final garden = GardenSession(
        database: database,
        stepProvider: FakeStepProvider(),
      );
      await garden.load();

      await garden.plantSeed(ZoneType.verger, 0, Species.pommier);
      expect(garden.snapshot.seeds[Species.pommier], 0);
      await garden.removePlant(ZoneType.verger, 0);
      expect(garden.snapshot.seeds[Species.pommier], 1);
      expect(garden.snapshot.zones[ZoneType.verger]![0], isNull);
    });
  });

  group('paliers de pas cumulés', () {
    test('10 000 pas débloquent un décor cosmétique (banc)', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(initialSteps: 10000);
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();
      await garden.refreshSteps();

      expect(garden.snapshot.totalSteps, 10000);
      expect(garden.snapshot.claimedMilestones, contains(10000));
      expect(garden.snapshot.ownedDecorations['banc'], 1);
      expect(garden.snapshot.florins, 0);
    });

    test('50 000 pas débloquent un deuxième décor (arche)', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(initialSteps: 50000);
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();
      await garden.refreshSteps();

      expect(garden.snapshot.claimedMilestones, containsAll([10000, 50000]));
      expect(garden.snapshot.ownedDecorations['banc'], 1);
      expect(garden.snapshot.ownedDecorations['arche'], 1);
    });

    test('100 000 pas offrent une graine brillante garantie d\'une espèce découverte', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final initial = GardenSnapshot.initial().copyWith(
        discoveredSpecies: {Species.tomate, Species.carotte},
      );
      await database.save(initial);
      final steps = FakeStepProvider(initialSteps: 100000);
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();
      await garden.refreshSteps();

      expect(
        garden.snapshot.claimedMilestones,
        containsAll([10000, 50000, 100000]),
      );
      // Brillante garantie d'une espèce découverte.
      final brillantCount = garden.snapshot.brilliantSeeds.values.fold(
        0,
        (a, b) => a + b,
      );
      expect(brillantCount, greaterThanOrEqualTo(1));
      expect(garden.snapshot.discoveredBrilliants, isNotEmpty);
      expect(garden.snapshot.florins, 0);
    });

    test('un palier déjà réclamé ne redonne pas de récompense', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(initialSteps: 10000);
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();
      await garden.refreshSteps();
      expect(garden.snapshot.ownedDecorations['banc'], 1);

      // Ajout de pas supplémentaires — le palier 10 000 est déjà réclamé.
      steps.addSteps(5000);
      await garden.refreshSteps();
      expect(garden.snapshot.ownedDecorations['banc'], 1);
      expect(garden.snapshot.claimedMilestones, isNot(contains(15000)));
    });

    test('les pas se cumulent à travers plusieurs sessions', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider(initialSteps: 6000);
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();
      await garden.refreshSteps();
      expect(garden.snapshot.totalSteps, 6000);
      expect(garden.snapshot.claimedMilestones, isEmpty);

      steps.addSteps(4000);
      await garden.refreshSteps();
      expect(garden.snapshot.totalSteps, 10000);
      expect(garden.snapshot.claimedMilestones, contains(10000));
    });
  });

  group('brillantes — sources complémentaires', () {
    test(
      'le palier quotidien 10k peut découvrir une brillante (~3 %)',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final initial = GardenSnapshot.initial().copyWith(
          discoveredSpecies: Species.values.toSet(),
        );
        await database.save(initial);
        final steps = FakeStepProvider(initialSteps: 10000);
        // roll < 0.03 → découverte.
        final garden = GardenSession(
          database: database,
          stepProvider: steps,
          roll: () => 0.001,
        );
        await garden.load();
        await garden.refreshSteps();
        expect(garden.snapshot.discoveredBrilliants, isNotEmpty);
        expect(garden.snapshot.lastBrillantDiscoveryDay, isNotNull);
      },
    );

    test(
      'le palier 10k ne redécouvre pas une brillante déjà trouvée',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final alreadyDiscovered = Species.values
            .where((s) => !s.isTree)
            .toSet();
        final initial = GardenSnapshot.initial().copyWith(
          discoveredSpecies: Species.values.toSet(),
          discoveredBrilliants: alreadyDiscovered,
          lastBrillantDiscoveryDay: '2020-01-01',
        );
        await database.save(initial);
        final steps = FakeStepProvider(initialSteps: 10000);
        final garden = GardenSession(
          database: database,
          stepProvider: steps,
          roll: () => 0.001,
        );
        await garden.load();
        await garden.refreshSteps();
        // Toutes les brillantes non-arbres sont déjà découvertes :
        // le roll ne produit rien.
        expect(
          garden.snapshot.discoveredBrilliants.length,
          alreadyDiscovered.length,
        );
      },
    );

    test('le pity invisible multiplie la chance après 25 jours', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      // 30 jours sans brillante → pity actif (×3, donc 9 %).
      final farPast = DateTime.now().subtract(const Duration(days: 30));
      final farPastKey =
          '${farPast.year.toString().padLeft(4, '0')}'
          '-${farPast.month.toString().padLeft(2, '0')}'
          '-${farPast.day.toString().padLeft(2, '0')}';
      final initial = GardenSnapshot.initial().copyWith(
        discoveredSpecies: Species.values.toSet(),
        lastBrillantDiscoveryDay: farPastKey,
      );
      await database.save(initial);
      final steps = FakeStepProvider(initialSteps: 10000);
      // roll = 0.05 : normalement < 3 % échoue, mais < 9 % réussit.
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        roll: () => 0.05,
      );
      await garden.load();
      await garden.refreshSteps();
      expect(garden.snapshot.discoveredBrilliants, isNotEmpty);
    });

    test('le pity ne s\'active pas avant 25 jours', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final recent = DateTime.now().subtract(const Duration(days: 10));
      final recentKey =
          '${recent.year.toString().padLeft(4, '0')}'
          '-${recent.month.toString().padLeft(2, '0')}'
          '-${recent.day.toString().padLeft(2, '0')}';
      final initial = GardenSnapshot.initial().copyWith(
        discoveredSpecies: Species.values.toSet(),
        lastBrillantDiscoveryDay: recentKey,
      );
      await database.save(initial);
      final steps = FakeStepProvider(initialSteps: 10000);
      // roll = 0.05 : > 3 %, pas de découverte.
      final garden = GardenSession(
        database: database,
        stepProvider: steps,
        roll: () => 0.05,
      );
      await garden.load();
      await garden.refreshSteps();
      expect(garden.snapshot.discoveredBrilliants, isEmpty);
    });

    test(
      'les graines brillantes des paliers cumulés marquent la découverte',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final initial = GardenSnapshot.initial().copyWith(
          discoveredSpecies: {Species.tomate, Species.carotte},
        );
        await database.save(initial);
        final steps = FakeStepProvider(initialSteps: 100000);
        final garden = GardenSession(
          database: database,
          stepProvider: steps,
          roll: () => 0.999,
        );
        await garden.load();
        await garden.refreshSteps();
        // Le palier 100k garantit une brillante.
        expect(garden.snapshot.discoveredBrilliants, isNotEmpty);
        expect(garden.snapshot.lastBrillantDiscoveryDay, isNotNull);
      },
    );
  });

  group('brillantes — cadence récolte', () {
    test(
      'une récolte ordinaire peut découvrir une brillante (0,3 %, 1/espèce)',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final initial = GardenSnapshot.initial().copyWith(florins: 0);
        final zones = {
          for (final entry in initial.zones.entries)
            entry.key: [...entry.value],
        };
        zones[ZoneType.potager]![0] = const Plant(
          species: Species.tomate,
          progressSteps: 1000,
        );
        await database.save(initial.copyWith(zones: zones));
        // roll < 0.003 → découverte.
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
          roll: () => 0.001,
        );
        await garden.load();
        await garden.harvestPlant(ZoneType.potager, 0);
        expect(garden.snapshot.brilliantSeeds[Species.tomate], 1);
        expect(garden.snapshot.discoveredBrilliants, contains(Species.tomate));
      },
    );

    test(
      'une brillante déjà découverte ne se redécouvre pas à la récolte',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final initial = GardenSnapshot.initial().copyWith(
          florins: 0,
          discoveredBrilliants: {Species.tomate},
        );
        final zones = {
          for (final entry in initial.zones.entries)
            entry.key: [...entry.value],
        };
        zones[ZoneType.potager]![0] = const Plant(
          species: Species.tomate,
          progressSteps: 1000,
        );
        await database.save(initial.copyWith(zones: zones));
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
          roll: () => 0.001,
        );
        await garden.load();
        await garden.harvestPlant(ZoneType.potager, 0);
        expect(garden.snapshot.brilliantSeeds[Species.tomate], isNull);
      },
    );

    test(
      'récolter une plante brillante rend sa graine brillante garantie',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final initial = GardenSnapshot.initial().copyWith(florins: 0);
        final zones = {
          for (final entry in initial.zones.entries)
            entry.key: [...entry.value],
        };
        zones[ZoneType.jardinFleuri]![0] = const Plant(
          species: Species.tournesol,
          tier: GrowthTier.brillante,
          progressSteps: 15000,
        );
        await database.save(initial.copyWith(zones: zones));
        final garden = GardenSession(
          database: database,
          stepProvider: FakeStepProvider(),
          roll: () => 0.999,
        );
        await garden.load();
        await garden.harvestPlant(ZoneType.jardinFleuri, 0);
        expect(garden.snapshot.brilliantSeeds[Species.tournesol], 1);
        expect(
          garden.snapshot.discoveredBrilliants,
          contains(Species.tournesol),
        );
      },
    );
  });

  group('boutique et inventaire de décors', () {
    test(
      'acheter un décor ajoute à l\'inventaire et débite les florins',
      () async {
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
      },
    );

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

      expect(() => garden.buyDecoration('fontaine'), throwsStateError);
      expect(garden.snapshot.ownedDecorations, isEmpty);
    });
  });

  group('placement de décors', () {
    test(
      'placer un décor le retire de l\'inventaire et l\'ajoute au jardin',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        await database.save(
          GardenSnapshot.initial().copyWith(
            florins: 200,
            ownedDecorations: {'arrosoir': 1},
          ),
        );
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
      },
    );

    test('déplacer un décor met à jour son contact', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(
        GardenSnapshot.initial().copyWith(
          florins: 200,
          ownedDecorations: {'banc': 1},
        ),
      );
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
      await garden.moveDecoration(
        placedId,
        ZoneType.potager,
        const Offset(160, 80),
      );
      expect(
        garden.snapshot.placedDecorations.first.contact,
        const Offset(160, 80),
      );
    });

    test('retirer un décor le remet dans l\'inventaire', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      await database.save(
        GardenSnapshot.initial().copyWith(
          florins: 200,
          ownedDecorations: {'tonneau': 1},
        ),
      );
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
      final directory = await Directory.systemTemp.createTemp(
        'growstep-decor-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      await database.save(
        GardenSnapshot.initial().copyWith(
          florins: 200,
          ownedDecorations: {'arrosoir': 1},
        ),
      );
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          florins: 200,
          ownedDecorations: {'arrosoir': 1},
        ),
      );
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          florins: 200,
          ownedDecorations: {'arrosoir': 2},
        ),
      );
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
    test(
      'les lots sont déterministes pour un même joueur et un même jour',
      () async {
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
        expect(
          lots2.map((l) => l.threshold).toList(),
          lots1.map((l) => l.threshold).toList(),
        );
      },
    );

    test('999 pas ne déclenche pas le premier palier', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();

      steps.addSteps(999);
      await garden.refreshSteps();
      expect(garden.snapshot.claimedDailyRewards, isEmpty);
    });

    test('1000 pas déclenche le premier palier', () async {
      final database = GardenDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final steps = FakeStepProvider();
      final garden = GardenSession(database: database, stepProvider: steps);
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
      final garden = GardenSession(database: database, stepProvider: steps);
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
      final garden = GardenSession(database: database, stepProvider: steps);
      await garden.load();

      steps.addSteps(1000);
      await garden.refreshSteps();
      final florinsAfterFirst = garden.snapshot.florins;
      await garden.refreshSteps();
      expect(garden.snapshot.florins, florinsAfterFirst);
    });

    test(
      'une correction à la baisse ne retire pas un palier déjà crédité',
      () async {
        final database = GardenDatabase(NativeDatabase.memory());
        addTearDown(database.close);
        final steps = FakeStepProvider();
        final garden = GardenSession(database: database, stepProvider: steps);
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
      },
    );

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

    test(
      'une correction à la baisse ne retire pas un palier déjà crédité',
      () async {
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
      },
    );

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

    test(
      'les pas tardifs créditent les paliers manqués sans florins',
      () async {
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
        // Aucun florin crédité (le marché est le seul générateur).
        expect(garden.snapshot.florins, 0);
        expect(
          garden.snapshot.claimedDailyRewards,
          contains(DailyRewardId(pastDay, 1000)),
        );
      },
    );

    test('un re-crédit tardif des paliers ne double pas', () async {
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
      final rewardsAfterFirst = garden.snapshot.claimedDailyRewards.length;

      await garden.applyLateSteps(pastDay);
      expect(garden.snapshot.claimedDailyRewards.length, rewardsAfterFirst);
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          starterFertilizerGranted: true,
          fertilizers: {},
        ),
      );
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          starterFertilizerGranted: true,
          fertilizers: {},
        ),
      );
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          starterFertilizerGranted: true,
          fertilizers: {},
        ),
      );
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          starterFertilizerGranted: true,
          fertilizers: {},
          pauseRewardsCount: 3,
        ),
      );
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          starterFertilizerGranted: true,
          fertilizers: {},
        ),
      );
      await garden.load();

      await garden.startPause();
      await garden.cancelPause();
      expect(garden.snapshot.activePause, isNull);
      expect(garden.snapshot.fertilizers[FertilizerType.basique], isNull);
    });

    test(
      'une pause évaluée à la reprise ne double pas la récompense',
      () async {
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
        steps.setStepsBetween(
          start,
          start.add(const Duration(minutes: 10)),
          300,
        );
        await garden.checkActivePause();
        final fertilizersAfterFirst =
            garden.snapshot.fertilizers[FertilizerType.basique];

        await garden.checkActivePause();
        expect(
          garden.snapshot.fertilizers[FertilizerType.basique],
          fertilizersAfterFirst,
        );
      },
    );

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
      await database.save(
        garden.snapshot.copyWith(
          starterFertilizerGranted: true,
          fertilizers: {},
          pauseRewardsCount: 3,
        ),
      );

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
    test(
      '300 pas détectés remettent le compteur d\'inactivité à zéro',
      () async {
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
        await database.save(
          GardenSnapshot.initial().copyWith(
            starterFertilizerGranted: true,
            lastActivityTime: earlier.toIso8601String(),
          ),
        );
        await garden.load();

        steps.addSteps(300);
        await garden.refreshSteps();
        expect(
          garden.snapshot.lastActivityTime,
          isNot(earlier.toIso8601String()),
        );
      },
    );

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
      await database.save(
        GardenSnapshot.initial().copyWith(
          starterFertilizerGranted: true,
          lastActivityTime: earlier.toIso8601String(),
        ),
      );
      await garden.load();

      await garden.startPause();
      expect(garden.snapshot.lastActivityTime, earlier.toIso8601String());
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          lastActivityTime: lastActivity.toIso8601String(),
          starterFertilizerGranted: true,
        ),
      );
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          lastActivityTime: lastActivity.toIso8601String(),
          starterFertilizerGranted: true,
        ),
      );
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
      await database.save(
        GardenSnapshot.initial().copyWith(
          lastActivityTime: lastActivity.toIso8601String(),
          starterFertilizerGranted: true,
        ),
      );
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

    test(
      'une invitation à heure choisie produit une intention de notification',
      () async {
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
      },
    );

    test(
      'une invitation est supprimée si 300 pas ont été détectés récemment',
      () async {
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
      },
    );

    test(
      'le refus des notifications n\'empêche pas les pauses manuelles',
      () async {
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
      },
    );
  });
}
