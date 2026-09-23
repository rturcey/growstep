import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growstep/garden/garden_database.dart';
import 'package:growstep/garden/garden_session.dart';
import 'package:growstep/steps/fake_step_provider.dart';

/// Session-level tests for #26: buying the jardin fleuri island with florins.
void main() {
  test('le jardin fleuri est fermé au démarrage', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final garden = GardenSession(
      database: database,
      stepProvider: FakeStepProvider(),
    );
    await garden.load();
    expect(garden.snapshot.ownedZones, {ZoneType.potager});
    expect(garden.snapshot.ownedZones, isNot(contains(ZoneType.jardinFleuri)));
  });

  test('un achat confirmé ouvre l’îlot et débite les florins', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final garden = GardenSession(
      database: database,
      stepProvider: FakeStepProvider(),
    );
    await garden.load();
    final price = ZoneType.jardinFleuri.purchasePrice;
    await database.save(garden.snapshot.copyWith(florins: 200));
    await garden.load();
    await garden.buyIsland(ZoneType.jardinFleuri);

    expect(garden.snapshot.ownedZones, contains(ZoneType.jardinFleuri));
    expect(garden.snapshot.florins, 200 - price);
  });

  test('un achat confirmé est permanent après redémarrage', () async {
    final directory = await Directory.systemTemp.createTemp('growstep-buy-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/garden.sqlite');
    final database = GardenDatabase(NativeDatabase(file));
    final garden = GardenSession(
      database: database,
      stepProvider: FakeStepProvider(),
    );
    await garden.load();
    await database.save(garden.snapshot.copyWith(florins: 200));
    await garden.load();
    await garden.buyIsland(ZoneType.jardinFleuri);
    await database.close();

    final database2 = GardenDatabase(NativeDatabase(file));
    addTearDown(database2.close);
    final reopened = GardenSession(
      database: database2,
      stepProvider: FakeStepProvider(),
    );
    await reopened.load();
    expect(reopened.snapshot.ownedZones, contains(ZoneType.jardinFleuri));
  });

  test('un solde insuffisant n’ouvre pas l’îlot', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final garden = GardenSession(
      database: database,
      stepProvider: FakeStepProvider(),
    );
    await garden.load();
    expect(
      () => garden.buyIsland(ZoneType.jardinFleuri),
      throwsA(isA<StateError>()),
    );
    expect(garden.snapshot.ownedZones, isNot(contains(ZoneType.jardinFleuri)));
    expect(garden.snapshot.florins, 0);
  });

  test('acheter deux fois ne débite qu’une fois', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final garden = GardenSession(
      database: database,
      stepProvider: FakeStepProvider(),
    );
    await garden.load();
    await database.save(garden.snapshot.copyWith(florins: 200));
    await garden.load();
    await garden.buyIsland(ZoneType.jardinFleuri);
    final florinsAfterFirst = garden.snapshot.florins;
    await garden.buyIsland(ZoneType.jardinFleuri);
    expect(garden.snapshot.florins, florinsAfterFirst);
  });

  test('les autres îlots restent fermés après un achat', () async {
    final database = GardenDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final garden = GardenSession(
      database: database,
      stepProvider: FakeStepProvider(),
    );
    await garden.load();
    await database.save(garden.snapshot.copyWith(florins: 200));
    await garden.load();
    await garden.buyIsland(ZoneType.jardinFleuri);
    expect(garden.snapshot.ownedZones, isNot(contains(ZoneType.verger)));
  });

  test('une ancienne sauvegarde avec des plantes fleuries conserve l’accès',
      () async {
    final directory = await Directory.systemTemp.createTemp('growstep-old-flower-');
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
    await database.save(initial.copyWith(zones: zones));
    await database.close();

    final database2 = GardenDatabase(NativeDatabase(file));
    addTearDown(database2.close);
    final garden = GardenSession(
      database: database2,
      stepProvider: FakeStepProvider(),
    );
    await garden.load();
    expect(garden.snapshot.ownedZones, contains(ZoneType.jardinFleuri));
    expect(
      garden.snapshot.zones[ZoneType.jardinFleuri]![0]!.species,
      Species.tournesol,
    );
    expect(garden.snapshot.florins, 0);
  });
}
