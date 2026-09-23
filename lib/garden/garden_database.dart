import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'garden_state.dart';

part 'garden_database.g.dart';

// Keep the v1 exchange rates explicit so reopening an old save is predictable.
const _stepsPerLegacyWaterDose = 300;
const _growthStepsPerAppliedLegacyWaterDose = 100;
const _florinsPerUnusedLegacyWaterDose = 1;

// Kept unchanged so schema v1 saves can be read during the transition.
class GardenRecords extends Table {
  IntColumn get id => integer()();
  TextColumn get plantStage => text().nullable()();
  IntColumn get waterDoses => integer()();
  IntColumn get waterProgress => integer()();
  IntColumn get creditedStepWaterDoses => integer()();
  TextColumn get creditedDay => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [GardenRecords])
class GardenDatabase extends _$GardenDatabase implements GardenStore {
  GardenDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'growstep'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createStateTable();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await _createStateTable();
    },
  );

  Future<void> _createStateTable() => customStatement(
    'CREATE TABLE IF NOT EXISTS garden_state ('
    'id INTEGER PRIMARY KEY, payload TEXT NOT NULL)',
  );

  @override
  Future<GardenSnapshot> load() async {
    final row = await customSelect(
      'SELECT payload FROM garden_state WHERE id = 1',
    ).getSingleOrNull();
    if (row != null) {
      return GardenSnapshot.fromJson(
        jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
      );
    }

    final old = await (select(
      gardenRecords,
    )..where((record) => record.id.equals(1))).getSingleOrNull();
    if (old == null) return GardenSnapshot.initial();

    final initial = GardenSnapshot.initial();
    final zones = {
      for (final entry in initial.zones.entries) entry.key: [...entry.value],
    };
    zones[ZoneType.potager] = List<Plant?>.filled(
      ZoneType.potager.initialSlots,
      null,
    );
    final ownedZones = <ZoneType>{ZoneType.potager};
    final starterChoices = <ZoneType>{};
    if (old.plantStage != null) {
      final progress = old.plantStage == 'jeunePlante'
          ? _stepsPerLegacyWaterDose
          : old.waterProgress * _growthStepsPerAppliedLegacyWaterDose;
      zones[ZoneType.jardinFleuri]![0] = Plant(
        species: Species.tournesol,
        progressSteps: progress,
      );
      starterChoices.add(ZoneType.jardinFleuri);
      ownedZones.add(ZoneType.jardinFleuri);
    }
    final migrated = initial.copyWith(
      zones: zones,
      starterChoices: starterChoices,
      creditedDay: old.creditedDay,
      creditedSteps: old.creditedStepWaterDoses * _stepsPerLegacyWaterDose,
      florins: old.waterDoses * _florinsPerUnusedLegacyWaterDose,
      legacyArchive: {
        'plantStage': old.plantStage,
        'waterDoses': old.waterDoses,
        'waterProgress': old.waterProgress,
        'creditedStepWaterDoses': old.creditedStepWaterDoses,
        'creditedDay': old.creditedDay,
      },
      ownedZones: ownedZones,
    );
    await save(migrated);
    return migrated;
  }

  @override
  Future<void> save(GardenSnapshot snapshot) => customStatement(
    'INSERT OR REPLACE INTO garden_state (id, payload) VALUES (1, ?)',
    [jsonEncode(snapshot.toJson())],
  );
}
