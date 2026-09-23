import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_session.dart';
import 'package:growstep/steps/fake_step_provider.dart';

/// Targeted migration tests for #24: data that a screen interaction cannot
/// directly observe — starter plants on a fresh save, stable slot identifiers
/// after migration, and ownership preservation for old saves with plants in
/// locked islands.
void main() {
  group('nouvelle sauvegarde', () {
    test('la tomate offerte est proche de 70 % à l’arrière gauche', () {
      final snapshot = GardenSnapshot.initial();
      final potager = snapshot.zones[ZoneType.potager]!;
      expect(potager.length, ZoneType.potager.initialSlots);
      expect(potager[0]!.species, Species.tomate);
      expect(potager[0]!.tier, GrowthTier.commune);
      expect(potager[0]!.progressSteps, closeTo(700, 50));
    });

    test('la carotte offerte est proche de 30 % au milieu droit', () {
      final snapshot = GardenSnapshot.initial();
      final potager = snapshot.zones[ZoneType.potager]!;
      expect(potager[1]!.species, Species.carotte);
      expect(potager[1]!.tier, GrowthTier.commune);
      expect(potager[1]!.progressSteps, closeTo(300, 50));
    });

    test('les emplacements avant gauche et avant droit sont vides', () {
      final snapshot = GardenSnapshot.initial();
      final potager = snapshot.zones[ZoneType.potager]!;
      expect(potager[2], isNull);
      expect(potager[3], isNull);
    });

    test('seul le potager est possédé au démarrage', () {
      final snapshot = GardenSnapshot.initial();
      expect(snapshot.ownedZones, {ZoneType.potager});
    });
  });

  group('plantation guidée', () {
    test('plante dans l’emplacement avant gauche sans retirer les offrandes',
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

      final potager = garden.snapshot.zones[ZoneType.potager]!;
      expect(potager[0]!.species, Species.tomate);
      expect(potager[0]!.progressSteps, closeTo(700, 50));
      expect(potager[1]!.species, Species.carotte);
      expect(potager[2]!.species, Species.tomate);
      expect(potager[2]!.progressSteps, 0);
      expect(potager[3], isNull);
    });
  });

  group('migration d’une sauvegarde ancienne', () {
    test('préserve espèces, progression et ressources', () async {
      final directory = await Directory.systemTemp.createTemp('growstep-mig-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final old = GardenDatabase(NativeDatabase(file));
      await old.load();
      await old.customStatement('''
        INSERT INTO garden_records VALUES
        (1, 'jeunePlante', 2, 1, 3, '2026-09-22')
      ''');
      await old.customStatement('DROP TABLE garden_state');
      await old.customStatement('PRAGMA user_version = 1');
      await old.close();

      final database = GardenDatabase(NativeDatabase(file));
      addTearDown(database.close);
      final garden = await database.load();
      expect(garden.zones[ZoneType.jardinFleuri]![0]!.species, Species.tournesol);
      expect(garden.florins, 2);
      expect(garden.ownedZones, contains(ZoneType.potager));
    });

    test('préserve l’accès aux îlots contenant des plantes', () async {
      final directory = await Directory.systemTemp.createTemp('growstep-old-zone-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      await database.load();

      final initial = GardenSnapshot.initial();
      final zones = {
        for (final entry in initial.zones.entries) entry.key: [...entry.value],
      };
      zones[ZoneType.jardinFleuri]![0] = const Plant(
        species: Species.tournesol,
        progressSteps: 500,
      );
      zones[ZoneType.verger]![0] = const Plant(species: Species.pommier);
      await database.save(initial.copyWith(zones: zones));
      await database.close();

      final database2 = GardenDatabase(NativeDatabase(file));
      addTearDown(database2.close);
      final loaded = await database2.load();

      expect(loaded.ownedZones, containsAll([ZoneType.potager, ZoneType.jardinFleuri, ZoneType.verger]));
      expect(loaded.zones[ZoneType.jardinFleuri]![0]!.species, Species.tournesol);
      expect(loaded.zones[ZoneType.jardinFleuri]![0]!.progressSteps, 500);
      expect(loaded.zones[ZoneType.verger]![0]!.species, Species.pommier);
    });

    test('une sauvegarde sans plante dans un îlot fermé ne l’ouvre pas', () async {
      final directory = await Directory.systemTemp.createTemp('growstep-closed-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      await database.load();
      await database.save(GardenSnapshot.initial());
      await database.close();

      final database2 = GardenDatabase(NativeDatabase(file));
      addTearDown(database2.close);
      final loaded = await database2.load();
      expect(loaded.ownedZones, {ZoneType.potager});
    });

    test('les plantes offertes ne sont pas ajoutées lors d’une reprise', () async {
      final directory = await Directory.systemTemp.createTemp('growstep-resume-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/garden.sqlite');
      final database = GardenDatabase(NativeDatabase(file));
      await database.load();
      final initial = GardenSnapshot.initial();
      final zones = {
        for (final entry in initial.zones.entries) entry.key: [...entry.value],
      };
      zones[ZoneType.potager]![0] = const Plant(
        species: Species.courgette,
        progressSteps: 400,
      );
      zones[ZoneType.potager]![1] = null;
      await database.save(initial.copyWith(zones: zones));
      await database.close();

      final database2 = GardenDatabase(NativeDatabase(file));
      addTearDown(database2.close);
      final loaded = await database2.load();
      final potager = loaded.zones[ZoneType.potager]!;
      expect(potager[0]!.species, Species.courgette);
      expect(potager[0]!.progressSteps, 400);
      expect(potager[1], isNull);
    });
  });
}
